/*
 
 LMTCaptureVideoPreviewLayer.m
 LMTCaptureVideoPreviewLayer
 
 Copyright (c) 2016 Coletiv Studio.
 Some rights reserved, all wrongs deserved.
 
 Permission is hereby granted, free of charge, to any person obtaining a copy of
 this software and associated documentation files (the "Software"), to deal in
 the Software without restriction, including without limitation the rights to
 use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
 the Software, and to permit persons to whom the Software is furnished to do so,
 subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
 FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
 COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
 IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 
*/

#import "LMTCaptureVideoPreviewLayer.h"
#import "LMTCaptureVideoPreviewLayerInternal.h"
#import "LMTCaptureVideoPreviewLayerStructures.h"
#import "LMTCaptureVideoPreviewLayerShaders.h"

#import "OGLShader.h"
#import "OGLUtilities.h"

#import <AVFoundation/AVCaptureOutput.h>
#import <QuartzCore/CAEAGLLayer.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>

@interface LMTCaptureVideoPreviewLayer () <AVCaptureVideoDataOutputSampleBufferDelegate>
{
    // OpenGL context
    EAGLContext * _oglContext;
    
    // Display link (works only on IOS 3.1 or greater)
    CADisplayLink * _displayLink;
    
    // OpenGL texture cache (core video)
    CVOpenGLESTextureCacheRef _oglTextureCache;
    
    // Last Pixel buffer set
    // Waiting to be rendered or last one rendered
    CVPixelBufferRef _pixelBuffer;
    
    // Shader program
    GLuint _blurFilterProgram;
    
    // Shader binding
    struct UniformHandles _blurFilterUniforms;
    struct AttributeHandles _blurFilterAttributes;
    
    // Offscreen Framebuffer
    OffscreenTextureInstance_t _pixelBufferTextureInstance;
    OffscreenTextureInstance_t _offscreenTextureInstance1;
    OffscreenTextureInstance_t _offscreenTextureInstance2;
    
    // Onscreen Framebuffer
    GLuint _onscreenFramebuffer;
    GLuint _onscreenColorRenderbuffer;
    GLint _onscreenColorRenderbufferWidth;
    GLint _onscreenColorRenderbufferHeight;
    struct TextureInstance _onscreenTextureInstance;
    
    // Filter (Kernel)
    GLfloat _filterKernelStep[2]; // Direction: X or Y
    size_t _filterKernelCount; // Number of filter kernels created
    size_t _filterKernelIndex; // Currently loaded filter kernel
    TextureFilterKernel_t * _filterKernelArray; // Kernels used for the interpolation between [0,1]
    
    // Filter (Intensity)
    float _filterIntensity;
    dispatch_source_t _filterIntensityTransitionTimer; // Use for animated transition between different indices
    float _filterIntensityTransitionTarget;
}
@end

@implementation LMTCaptureVideoPreviewLayer

#define kTextureDownsampleScale (4.0f)
#define mPixelBufferDownsampledWidth(pixelBuffer) (((GLfloat)CVPixelBufferGetWidth(pixelBuffer))/kTextureDownsampleScale)
#define mPixelBufferDownsampledHeight(pixelBuffer) (((GLfloat)CVPixelBufferGetHeight(pixelBuffer))/kTextureDownsampleScale)

#pragma mark -
#pragma mark Initialization

- (instancetype)initWithSession:(AVCaptureSession *)session
{
    self = [super init];
    if (self)
    {
        // Assign the AVCaptureSession, which is managed by a LMTCaptureVideoPreviewLayerInternal instance
        self.session = session;
        
        // On iOS8 and later we use the native scale of the screen as our content scale factor.
        // This allows us to render to the exact pixel resolution of the screen which avoids additional scaling and GPU rendering work.
        // For example the iPhone 6 Plus appears to UIKit as a 736 x 414 pt screen with a 3x scale factor (2208 x 1242 virtual pixels).
        // But the native pixel dimensions are actually 1920 x 1080.
        // Since we are streaming 1080p buffers from the camera we can render to the iPhone 6 Plus screen at 1:1 with no additional scaling if we set everything up correctly.
        // Using the native scale of the screen also allows us to render at full quality when using the display zoom feature on iPhone 6/6 Plus.
        
        // Only try to compile this code if we are using the 8.0 or later SDK.
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000
        if ([UIScreen instancesRespondToSelector:@selector(nativeScale)])
        {
            self.contentsScale = [UIScreen mainScreen].nativeScale;
        }
        else
#endif
        {
            self.contentsScale = [UIScreen mainScreen].scale;
        }
        
        // Setup the CAEAGLLayer for screen renderbuffer
        self.opaque = YES;
        self.drawableProperties = @{ kEAGLDrawablePropertyRetainedBacking : @(NO),
                                     kEAGLDrawablePropertyColorFormat : kEAGLColorFormatRGBA8 };
        
        // OpenGL ES 2.0 only
        _oglContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        
        if (!_oglContext || ![EAGLContext setCurrentContext:_oglContext])
        {
            Log(@"LMTCaptureVideoPreviewLayer: Could not create a valid EAGLContext");
            return nil;
        }
        
        // Disable depth testing
        glDisable(GL_DEPTH_TEST);
    }
    return self;
}

- (void)resizeWithOldSuperlayerSize:(CGSize)size
{
    // Create the onscreen framebuffer
    [self createOnscreenFramebufferForLayer:self];
    
    // Load blur filter program
    _blurFilterProgram = loadProgram(VertexShaderSource, FragmentShaderSource);
    validateProgram(_blurFilterProgram);
    
    // Bind blur filter attributes
    _blurFilterAttributes.VertPosition = glGetAttribLocation(_blurFilterProgram, "VertPosition");
    _blurFilterAttributes.VertTextureCoordinate = glGetAttribLocation(_blurFilterProgram, "VertTextureCoordinate");
    
    // Bind blur filter uniforms
    _blurFilterUniforms.FragTextureData = glGetUniformLocation(_blurFilterProgram, "FragTextureData");
    _blurFilterUniforms.FragFilterEnabled = glGetUniformLocation(_blurFilterProgram, "FragFilterEnabled");
    _blurFilterUniforms.FragFilterBounds = glGetUniformLocation(_blurFilterProgram, "FragFilterBounds");
    _blurFilterUniforms.FragFilterKernelRadius = glGetUniformLocation(_blurFilterProgram, "FragFilterKernelRadius");
    _blurFilterUniforms.FragFilterKernelSize = glGetUniformLocation(_blurFilterProgram, "FragFilterKernelSize");
    _blurFilterUniforms.FragFilterKernelValue = glGetUniformLocation(_blurFilterProgram, "FragFilterKernelValue");
    _blurFilterUniforms.FragFilterKernelStep = glGetUniformLocation(_blurFilterProgram, "FragFilterKernelStep");
    
    // Use the blur filter glsl program
    glUseProgram(_blurFilterProgram);
    
    // Use texture 0
    glActiveTexture(GL_TEXTURE0);
    
    // OpenGL pre-warm
    [self drawColor:self.backgroundColor];
    
#if TARGET_OS_SIMULATOR
    // TODO
//    dispatch_async(dispatch_get_main_queue(), ^{
//        CVPixelBufferRef pixelBuffer = [self pixelBufferFromImageNamed:@"TestFrame-1.jpg"];
//        [self drawPixelBuffer:nil];
//    });
#endif // TARGET_OS_SIMULATOR
    
    // Create and setup displayLink
    _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(drawPixelBuffer:)];
    [_displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    _displayLink.frameInterval = 2;
}

- (void)teardown
{
    // TODO
}

#pragma mark -
#pragma mark Blur property

- (void)setBlur:(CGFloat)blur
{
    _blur = blur;
    [self setFilterIntensity:_blur animated:YES];
}

#pragma mark - 
#pragma mark AVCaptureSession

- (AVCaptureSession *)session
{
    return self.internal.session;
}

- (void)setSession:(AVCaptureSession *)session
{
    self.internal.session = session;
}

#pragma mark -
#pragma mark LMTCaptureVideoPreviewLayerInternal

- (LMTCaptureVideoPreviewLayerInternal *)internal
{
    if (!_internal)
    {
        _internal = [LMTCaptureVideoPreviewLayerInternal new];
    }
    
    return _internal;
}

#pragma mark -
#pragma mark Texture Instance (CVPixelBufferRef)

- (CVPixelBufferRef)pixelBufferFromImageNamed:(NSString *)imageName
{
    CGImageRef image = [UIImage imageNamed:imageName].CGImage;
    
    if (!image) {
        Log(@"Failed to load image %@", imageName);
        return NULL;
    }
    
    size_t width = CGImageGetWidth(image);
    size_t height = CGImageGetHeight(image);
    
    CVPixelBufferRef pixelBuffer = NULL;
    NSDictionary * pixelBufferAttributes = @{ (NSString *)kCVPixelBufferCGImageCompatibilityKey: @YES,
                                              (NSString *)kCVPixelBufferCGBitmapContextCompatibilityKey: @YES };
    
    CVReturn result = CVPixelBufferCreate(NULL, width, height, kCVPixelFormatType_32BGRA, (__bridge CFDictionaryRef)pixelBufferAttributes, &pixelBuffer);
    
    if (result != kCVReturnSuccess) {
        Log(@"Failed to create pixelBuffer from image %@", imageName);
        return NULL;
    }
    
    CIContext * coreImageContext = [CIContext contextWithCGContext:UIGraphicsGetCurrentContext() options:nil];
    [coreImageContext render:[CIImage imageWithCGImage:image] toCVPixelBuffer:pixelBuffer];
    
    return pixelBuffer;
}

- (CVOpenGLESTextureRef)oglTextureFromPixelBuffer:(CVPixelBufferRef)pixelBuffer
{
    // Create a new CVOpenGLESTexture cache
    if (!_oglTextureCache)
    {
        CVReturn result = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, _oglContext, NULL, &_oglTextureCache);
        if (result != kCVReturnSuccess)
        {
            Log(@"CameraOGLPreviewView: Error at CVOpenGLESTextureCacheCreate %d", result);
            return NULL;
        }
    }
    
    // Create a CVOpenGLESTexture from a CVPixelBufferRef
    size_t textureWidth = CVPixelBufferGetWidth(pixelBuffer);
    size_t textureHeight = CVPixelBufferGetHeight(pixelBuffer);
    CVOpenGLESTextureRef oglTexture = NULL;
    CVReturn result = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                                   _oglTextureCache,
                                                                   pixelBuffer,
                                                                   NULL,
                                                                   GL_TEXTURE_2D,
                                                                   GL_RGBA,
                                                                   (GLsizei)textureWidth,
                                                                   (GLsizei)textureHeight,
                                                                   GL_BGRA,
                                                                   GL_UNSIGNED_BYTE,
                                                                   0,
                                                                   &oglTexture);
    
    if (result != kCVReturnSuccess)
    {
        Log(@"CVOpenGLESTextureCacheCreateTextureFromImage failed (error: %d)", result);
        return NULL;
    }
    
    return oglTexture;
}

- (void)flushPixelBufferCache
{
    if ( _oglTextureCache ) {
        CVOpenGLESTextureCacheFlush(_oglTextureCache, 0);
    }
}

#pragma mark -
#pragma mark Offscreen rendering

- (GLuint)createFramebufferForOffscreenTextureInstance:(OffscreenTextureInstance_t *)offscreenTextureInstance
{
    // Delete potential previously created framebuffer
    if(offscreenTextureInstance->framebuffer)
    {
        glDeleteFramebuffers(1, &offscreenTextureInstance->framebuffer);
    }
    
    // Allocating offscreen renderbuffer memory
    glGenFramebuffers(1, &offscreenTextureInstance->framebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, offscreenTextureInstance->framebuffer);
    
    // Create the texture to render
    glGenTextures(1, &offscreenTextureInstance->textureName);
    offscreenTextureInstance->textureTarget = GL_TEXTURE_2D;
    glBindTexture(GL_TEXTURE_2D, offscreenTextureInstance->textureName);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, offscreenTextureInstance->textureWidth, offscreenTextureInstance->textureHeight, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
    
    // Set texture parameters
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    // Attach color component of renderbuffer to texture
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, offscreenTextureInstance->textureName, 0);
    
    if (!checkFramebufferStatusComplete())
    {
        return 0;
    }
    
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glBindTexture(GL_TEXTURE_2D, 0);
    
    return offscreenTextureInstance->framebuffer;
}

- (void)loadOffscreenTextureInstance:(OffscreenTextureInstance_t *)offscreenTextureInstance
{
    // Create a new offscreen framebuffer
    [self createFramebufferForOffscreenTextureInstance:offscreenTextureInstance];
    
    // Use triangle strip
    offscreenTextureInstance->primitiveType = GL_TRIANGLE_STRIP;
    
    static const float texelArray[] = {
        0.0f, 0.0f, // bottom left
        1.0f, 0.0f, // bottom right
        0.0f,  1.0f, // top left
        1.0f,  1.0f, // top right
    };
    
    static const GLfloat vertexArray[] = {
        -1.0f, -1.0f, // bottom left
        1.0f, -1.0f, // bottom right
        -1.0f,  1.0f, // top left
        1.0f,  1.0f, // top right
    };
    
    GLsizei stride = sizeof(GLfloat) * 2;
    offscreenTextureInstance->vertexCount = 4;
    
    // Vertex Array Object
    glGenVertexArraysOES(1, &offscreenTextureInstance->vertexArray);
    glBindVertexArrayOES(offscreenTextureInstance->vertexArray);
    
    // VBOs
    glGenBuffers(2, offscreenTextureInstance->vertexBuffers);
    
    // VBO 1, Position
    glBindBuffer(GL_ARRAY_BUFFER, offscreenTextureInstance->vertexBuffers[0]);
    glBufferData(GL_ARRAY_BUFFER, offscreenTextureInstance->vertexCount * stride, vertexArray, GL_STATIC_DRAW);
    glEnableVertexAttribArray(_blurFilterAttributes.VertPosition);
    glVertexAttribPointer(_blurFilterAttributes.VertPosition, 2, GL_FLOAT, GL_FALSE, stride, 0);
    
    // VBO 2, TextureCoordinate
    glBindBuffer(GL_ARRAY_BUFFER, offscreenTextureInstance->vertexBuffers[1]);
    glBufferData(GL_ARRAY_BUFFER, offscreenTextureInstance->vertexCount * stride, texelArray, GL_STATIC_DRAW);
    glEnableVertexAttribArray(_blurFilterAttributes.VertTextureCoordinate);
    glVertexAttribPointer(_blurFilterAttributes.VertTextureCoordinate, 2, GL_FLOAT, GL_FALSE, stride, 0);
    
    // Unbind VAO
    glBindVertexArrayOES(0);
}

- (CVOpenGLESTextureRef)drawPixelBuffer:(CVPixelBufferRef)pixelBuffer onOffscreenTextureInstance:(OffscreenTextureInstance_t *)offscreenTextureInstance
{
    // Check dimensions of the pixelBuffer
    GLfloat width = mPixelBufferDownsampledWidth(pixelBuffer);
    GLfloat height = mPixelBufferDownsampledHeight(pixelBuffer);
    
    // Get the OpenGL texture
    CVOpenGLESTextureRef oglTexture = [self oglTextureFromPixelBuffer:pixelBuffer];
    
    // Create a temporary offscreen texture instance wrapping the pixelBuffer
    _pixelBufferTextureInstance.textureWidth = width;
    _pixelBufferTextureInstance.textureHeight = height;
    _pixelBufferTextureInstance.textureTarget = CVOpenGLESTextureGetTarget(oglTexture);
    _pixelBufferTextureInstance.textureName = CVOpenGLESTextureGetName(oglTexture);
    
    [self drawOffscreenTextureInstance:&_pixelBufferTextureInstance onOffscreenTextureInstance:offscreenTextureInstance];
    
    return oglTexture;
}

- (void)drawOffscreenTextureInstance:(OffscreenTextureInstance_t *)srcTextureInstance onOffscreenTextureInstance:(OffscreenTextureInstance_t *)destTextureInstance
{
    // Check dimensions of the source texture instance
    GLfloat width = srcTextureInstance->textureWidth;
    GLfloat height = srcTextureInstance->textureHeight;
    
    // Check if dimensions changed and load again if needed
    if (destTextureInstance->textureWidth != width || destTextureInstance->textureHeight != height)
    {
        destTextureInstance->textureWidth = width;
        destTextureInstance->textureHeight = height;
        
        // Load offscreen texture instance
        [self loadOffscreenTextureInstance:destTextureInstance];
        
        // Set Frame uniform
        glUniform1i(_blurFilterUniforms.FragTextureData, 0);
    }
    
    if (!destTextureInstance->framebuffer)
    {
        Log(@"Invalid offscreen texture instance framebuffer. I am just going to bailout.");
        return;
    }
    
    // Bind the offscreen framebuffer
    glBindFramebuffer(GL_FRAMEBUFFER, destTextureInstance->framebuffer);
    
    // Set the view port to the entire view
    glViewport( 0, 0, destTextureInstance->textureWidth, destTextureInstance->textureHeight);
    
    // Bind the src texture
    glBindTexture(srcTextureInstance->textureTarget, srcTextureInstance->textureName);
    
    // Set texture parameters
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    // Set the filter step
    glUniform2f(_blurFilterUniforms.FragFilterKernelStep, _filterKernelStep[0]/srcTextureInstance->textureWidth, _filterKernelStep[1]/srcTextureInstance->textureHeight);
    
    // Bind VAO
    glBindVertexArrayOES(destTextureInstance->vertexArray);
    
    // Draw the instance
    glDrawArrays(destTextureInstance->primitiveType, 0, destTextureInstance->vertexCount);
}

#pragma mark -
#pragma mark Onscreen rendering (2nd pass)

- (GLuint)createOnscreenFramebufferForLayer:(CAEAGLLayer *)layer
{
    // Delete potential previously created framebuffer
    if(_onscreenFramebuffer)
    {
        glDeleteRenderbuffers(1, &_onscreenColorRenderbuffer);
        glDeleteFramebuffers(1, &_onscreenFramebuffer);
    }
    
    // Allocating on-screen color renderbuffer memory
    glGenRenderbuffers(1, &_onscreenColorRenderbuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _onscreenColorRenderbuffer);
    [_oglContext renderbufferStorage:GL_RENDERBUFFER fromDrawable:layer];
    
    // Create the on-screen framebuffer object (FBO).
    glGenFramebuffers(1, &_onscreenFramebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _onscreenFramebuffer);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _onscreenColorRenderbuffer);
    
    if (!checkFramebufferStatusComplete())
    {
        [self teardown];
        return NO;
    }
    
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_onscreenColorRenderbufferWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_onscreenColorRenderbufferHeight);
    
    return _onscreenFramebuffer;
}

- (void)setOnscreenTextureInstanceTextureCoordinatesFor:(OffscreenTextureInstance_t *)textureInstance
{
    // We assume the pixelBuffer is landscape, rotated 90 degrees anti-clockwise
    // So:
    // 1. We switch width and height
    // 2. Rotate 90 degrees clockwise by mapping the texture coordinates
    // The pixel bufferr (and texture) remain unchanged.
    // We only flip the viewHeight/viewWidth and map the texture to the appropriate vertices so it is rotated.
    _onscreenTextureInstance.textureWidth = (GLfloat)textureInstance->textureWidth;
    _onscreenTextureInstance.textureHeight = (GLfloat)textureInstance->textureHeight;
    
    // Ratio of view versus. texture
    GLfloat viewRatio = ((GLfloat)_onscreenColorRenderbufferHeight) / ((GLfloat)_onscreenColorRenderbufferWidth);
    GLfloat textureRatio = _onscreenTextureInstance.textureWidth / _onscreenTextureInstance.textureHeight;
    
    // Change S (T=1) if texture ratio <= view ratio
    // Change T (S=1) if texture ration > view ratio
    BOOL changeT = textureRatio > viewRatio; // changeT = !changeS
    
    // Calculate the texture scale factor
    GLfloat textureScale = 1.0;
    
    // Change T, means we need to check view height vs. texture height
    // T is going to map [0,1]
    if (changeT) {
        // texture height >= view height means we don't need to scale (only crop)
        if (_onscreenTextureInstance.textureWidth > ((GLfloat)_onscreenColorRenderbufferHeight)) {
            textureScale = 1.0;
        }
        // texture height < view height means we have to scale (and crop)
        else {
            textureScale = ((GLfloat)_onscreenColorRenderbufferWidth) / _onscreenTextureInstance.textureHeight;
        }
    }
    // Change S, means we need to check view width vs. texture width
    // S is going to map [0,1]
    else {
        // texture width >= view width means we don't need to scale (only crop)
        if (_onscreenTextureInstance.textureHeight > ((GLfloat)_onscreenColorRenderbufferWidth)) {
            textureScale = 1.0;
        }
        // texture width < view width means we have to scale (and crop)
        else {
            textureScale = ((GLfloat)_onscreenColorRenderbufferHeight) / _onscreenTextureInstance.textureWidth;
        }
    }
    
    // Calculate texture scaled dimensions
    GLfloat _scaledTextureHeight = _onscreenTextureInstance.textureHeight * textureScale;
    GLfloat _scaledTextureWidth = _onscreenTextureInstance.textureWidth * textureScale;
    
    // Calculate texture coordinates S and D deltas
    GLfloat _deltaTextureCoordinateS = (_scaledTextureWidth-((GLfloat)_onscreenColorRenderbufferHeight)) / _scaledTextureWidth / 2.0;
    GLfloat _deltaTextureCoordinateT = (_scaledTextureHeight-((GLfloat)_onscreenColorRenderbufferWidth)) / _scaledTextureHeight / 2.0;
    
    // Texture coordiantes + deltas
    const GLfloat textureCoordinates[] = {
        1.0 - _deltaTextureCoordinateS, 1.0 - _deltaTextureCoordinateT,
        1.0 - _deltaTextureCoordinateS, 0.0 + _deltaTextureCoordinateT,
        0.0 + _deltaTextureCoordinateS, 1.0 - _deltaTextureCoordinateT,
        0.0 + _deltaTextureCoordinateS, 0.0 + _deltaTextureCoordinateT
    };
    
    // Update the texture coordinates
    memcpy(_onscreenTextureInstance.textureCoordinates, textureCoordinates, 8*sizeof(GLfloat));
}

- (void)loadOnscreenTextureInstanceFor:(OffscreenTextureInstance_t *)textureInstance
{
    Log(@"loadTextureInstanceForPixelBuffer");
    
    // Use triangle strip
    _onscreenTextureInstance.primitiveType = GL_TRIANGLE_STRIP;
    
    // Set dimensions and calculate the texture coordinates
    [self setOnscreenTextureInstanceTextureCoordinatesFor:textureInstance];
    
    static const GLfloat vertexArray[] = {
        -1.0f, -1.0f, // bottom left
        1.0f, -1.0f, // bottom right
        -1.0f,  1.0f, // top left
        1.0f,  1.0f, // top right
    };
    
    GLsizei stride = sizeof(GLfloat) * 2;
    _onscreenTextureInstance.vertexCount = 4;
    
    // Vertex Array Object
    glGenVertexArraysOES(1, &_onscreenTextureInstance.vertexArray);
    glBindVertexArrayOES(_onscreenTextureInstance.vertexArray);
    
    // VBOs
    glGenBuffers(2, _onscreenTextureInstance.vertexBuffers);
    
    // VBO 1, Position
    glBindBuffer(GL_ARRAY_BUFFER, _onscreenTextureInstance.vertexBuffers[0]);
    glBufferData(GL_ARRAY_BUFFER, _onscreenTextureInstance.vertexCount * stride, vertexArray, GL_STATIC_DRAW);
    glEnableVertexAttribArray(_blurFilterAttributes.VertPosition);
    glVertexAttribPointer(_blurFilterAttributes.VertPosition, 2, GL_FLOAT, GL_FALSE, stride, 0);
    
    // VBO 2, TextureCoordinate
    glBindBuffer(GL_ARRAY_BUFFER, _onscreenTextureInstance.vertexBuffers[1]);
    glBufferData(GL_ARRAY_BUFFER, _onscreenTextureInstance.vertexCount * stride, _onscreenTextureInstance.textureCoordinates, GL_STATIC_DRAW);
    glEnableVertexAttribArray(_blurFilterAttributes.VertTextureCoordinate);
    glVertexAttribPointer(_blurFilterAttributes.VertTextureCoordinate, 2, GL_FLOAT, GL_FALSE, stride, 0);
    
    // Unbind VAO
    glBindVertexArrayOES(0);
}

- (void)drawOnscreenOffscreenTextureInstance:(OffscreenTextureInstance_t *)offscreenTextureInstance
{
    if (!_onscreenFramebuffer)
    {
        Log(@"Invalid onscreen framebuffer. I am just going to bailout.");
        return;
    }
    
    // Bind the offscreen framebuffer
    glBindFramebuffer(GL_FRAMEBUFFER, _onscreenFramebuffer);
    
    // Set the view port to the entire view
    glViewport( 0, 0, _onscreenColorRenderbufferWidth, _onscreenColorRenderbufferHeight);
    
    // Bind the texture
    glBindTexture(offscreenTextureInstance->textureTarget, offscreenTextureInstance->textureName);
    
    // Set texture parameters
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    // Check dimensions of the pixelBuffer
    GLfloat width = offscreenTextureInstance->textureWidth;
    GLfloat height = offscreenTextureInstance->textureHeight;
    
    // Check if dimensions changed and load again if needed
    if (_onscreenTextureInstance.textureWidth != width || _onscreenTextureInstance.textureHeight != height)
    {
        // Load texture instance
        [self loadOnscreenTextureInstanceFor:offscreenTextureInstance];
        
        // Set Frame uniform
        glUniform1i(_blurFilterUniforms.FragTextureData, 0);
    }
    
    // Bind VAO
    glBindVertexArrayOES(_onscreenTextureInstance.vertexArray);
    
    // Draw the instance
    glDrawArrays(_onscreenTextureInstance.primitiveType, 0, _onscreenTextureInstance.vertexCount);
}

- (CVOpenGLESTextureRef)drawOnscreenPixelBuffer:(CVPixelBufferRef)pixelBuffer
{
    // Check dimensions of the pixelBuffer
    GLfloat width = (GLfloat)CVPixelBufferGetWidth(pixelBuffer);
    GLfloat height = (GLfloat)CVPixelBufferGetHeight(pixelBuffer);
    
    // Get the OpenGL texture
    CVOpenGLESTextureRef oglTexture = [self oglTextureFromPixelBuffer:pixelBuffer];
    
    // Create a temporary offscreen texture instance wrapping the pixelBuffer
    _pixelBufferTextureInstance.textureWidth = width;
    _pixelBufferTextureInstance.textureHeight = height;
    _pixelBufferTextureInstance.textureTarget = CVOpenGLESTextureGetTarget(oglTexture);
    _pixelBufferTextureInstance.textureName = CVOpenGLESTextureGetName(oglTexture);
    
    [self drawOnscreenOffscreenTextureInstance:&_pixelBufferTextureInstance];
    
    return oglTexture;
}

#pragma mark -
#pragma mark Drawing

- (void)getCGColor:(CGColorRef)color componentsRed:(CGFloat *)red green:(CGFloat *)green blue:(CGFloat *)blue alpha:(CGFloat *)alpha
{
    *red = *green = *blue = 0.0;
    *alpha = 1.0;
    
    if (CGColorGetNumberOfComponents(color) == 4)
    {
        const CGFloat * colorComponents = CGColorGetComponents(color);
        *red = colorComponents[0];
        *green = colorComponents[1];
        *blue = colorComponents[2];
        *alpha = colorComponents[3];
    }
}

- (void)drawColor:(CGColorRef)color
{
    if (_onscreenFramebuffer == 0)
    {
        Log(@"CameraOGLPreviewView: OpenGL framebuffer not initialized.");
        return;
    }
    
    EAGLContext * oglContext = [EAGLContext currentContext];
    if (oglContext != _oglContext)
    {
        if (![EAGLContext setCurrentContext:_oglContext])
        {
            @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"CameraOGLPreviewView: Problem with OpenGL context" userInfo:nil];
            return;
        }
    }
    
    // Use clear color with the argument color
    CGFloat red, green, blue, alpha;
    [self getCGColor:color componentsRed:&red green:&green blue:&blue alpha:&alpha];
    
    glClearColor(red, green, blue, alpha);
    glClear(GL_COLOR_BUFFER_BIT);
    
    [_oglContext presentRenderbuffer:GL_RENDERBUFFER];
    
    if (oglContext != _oglContext)
    {
        [EAGLContext setCurrentContext:oglContext];
    }
}

- (void)drawPixelBuffer:(CADisplayLink*)aDisplayLink
{
    CMSampleBufferRef sampleBuffer = (CMSampleBufferRef)CFRetain(self.internal.sampleBuffer);
    
    if (!sampleBuffer)
    {
        Log(@"CameraOGLPreviewView: sampleBuffer is NULL");
        return;
    }
    
    CVPixelBufferRef pixelBuffer = (CVPixelBufferRef)CFRetain(CMSampleBufferGetImageBuffer(sampleBuffer));
    
    CFRelease(sampleBuffer);
    
    if (!pixelBuffer)
    {
        Log(@"CameraOGLPreviewView: pixelBuffer is nil");
        return;
    }
    
    EAGLContext * oglContext = [EAGLContext currentContext];
    if (oglContext != _oglContext)
    {
        if (![EAGLContext setCurrentContext:_oglContext])
        {
            @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"CameraOGLPreviewView: Problem with OpenGL context" userInfo:nil];
            return;
        }
    }
    
    // Avoid loading previous buffer contents
    glClear(GL_COLOR_BUFFER_BIT);
    
    CVOpenGLESTextureRef pixelBufferTexture = NULL;
    
    // Only filter if filter intensity is greater than 0
    if (_filterIntensity > 0)
    {
        // Update filter parameters
        [self setFilterEnabled:YES];
        [self setFilterBoundsRect:CGRectMake(0, 0, 1, 1)];
        
        // X
        _filterKernelStep[0] = 1.0f;
        _filterKernelStep[1] = 0.0f;
        
        // Draw 1st pass (offscreen)
        pixelBufferTexture = [self drawPixelBuffer:pixelBuffer onOffscreenTextureInstance:&_offscreenTextureInstance1];
        
        // Y
        _filterKernelStep[0] = 0.0f;
        _filterKernelStep[1] = 1.0f;
        
        // Draw 2nd pass (offscreen)
        [self drawOffscreenTextureInstance:&_offscreenTextureInstance1 onOffscreenTextureInstance:&_offscreenTextureInstance2];
        
        // Disabled filtering for final onscreen rendering
        [self setFilterEnabled:NO];
        
        // Draw (onscreen)
        [self drawOnscreenOffscreenTextureInstance:&_offscreenTextureInstance2];
    }
    else
    {
        // Disable filtering for final onscreen rendering
        [self setFilterEnabled:NO];
        
        // Draw (onscreen)
        pixelBufferTexture = [self drawOnscreenPixelBuffer:pixelBuffer];
    }
    
    [_oglContext presentRenderbuffer:GL_RENDERBUFFER];
    
    glBindTexture(_pixelBufferTextureInstance.textureTarget, _pixelBufferTextureInstance.textureName);
    glBindTexture(GL_TEXTURE_2D, 0);
    CFRelease(pixelBufferTexture);
    
    CFRelease(pixelBuffer);
    
    if (oglContext != _oglContext)
    {
        [EAGLContext setCurrentContext:oglContext];
    }
}

#pragma mark -
#pragma mark Filtering (Parameters)

- (void)setFilterEnabled:(BOOL)filterEnabled
{
    glUniform1i(_blurFilterUniforms.FragFilterEnabled, (filterEnabled ? 1 : 0));
}

- (void)setFilterBoundsRect:(CGRect)filterBoundsRect
{
    GLfloat xMin = filterBoundsRect.origin.x;
    GLfloat xMax = xMin + filterBoundsRect.size.width;
    GLfloat yMin = filterBoundsRect.origin.y;
    GLfloat yMax = yMin + filterBoundsRect.size.height;
    
    // Bounds within the texture that are filtered [xMin, yMin, xMax, yMax]
    // The textureCoordinates mapping rotate the texture 90 degrees clockwise
    // We need to flip x/y in textureFilterBounds to work with the rotation
    GLfloat filterBounds[4] = { yMin, 1.0 - xMax, yMax, 1.0 - xMin };
    
    glUniform4fv(_blurFilterUniforms.FragFilterBounds, 1, filterBounds);
}

- (void)setFilterIntensity:(float)intensity
{
    if (!_filterKernelCount)
    {
        [self loadFilterKernel];
    }
    
    // Clamp intensity between [0,1] range
    float clampedIntensity =  MAX(0, MIN(1, intensity));
    
    // Assign the intensity value
    _filterIntensity = clampedIntensity;
    
    // Map intensity to a integer kernel index
    size_t mappedIndex = (size_t)roundf(clampedIntensity * ((float)(_filterKernelCount-1)));
    
    // Assign the mapped index
    _filterKernelIndex =  MAX(0, MIN(_filterKernelCount-1, mappedIndex));
    
    TextureFilterKernel_t filterKernel = _filterKernelArray[_filterKernelIndex];
    
    glUniform1i(_blurFilterUniforms.FragFilterKernelRadius, filterKernel.kernelRadius);
    glUniform1i(_blurFilterUniforms.FragFilterKernelSize, filterKernel.kernelSize);
    glUniform1fv(_blurFilterUniforms.FragFilterKernelValue, filterKernel.kernelSize, filterKernel.kernelValue);
}

- (void)setFilterIntensity:(float)intensity animated:(BOOL)animated
{
    if (!animated)
    {
        [self setFilterIntensity:intensity];
        return;
    }
    
    // Assign target filter intensity
    _filterIntensityTransitionTarget = intensity;
    
    // Define timer step based on the number of kernels available
    float const filterIntensityTransitionStep = 1.0f / _filterKernelCount;
    
    _filterIntensityTransitionTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(_filterIntensityTransitionTimer, DISPATCH_TIME_NOW, (1.0f/30.0f) * NSEC_PER_SEC, 0.0 * NSEC_PER_SEC);
    dispatch_source_set_event_handler(_filterIntensityTransitionTimer, ^{
        
        if (_filterIntensity != _filterIntensityTransitionTarget)
        {
            if (_filterIntensity < _filterIntensityTransitionTarget)
            {
                if ((_filterIntensity + filterIntensityTransitionStep) < _filterIntensityTransitionTarget)
                {
                    [self setFilterIntensity:(_filterIntensity + filterIntensityTransitionStep)];
                }
                else
                {
                    [self setFilterIntensity:_filterIntensityTransitionTarget];
                }
            }
            else if (_filterIntensity > _filterIntensityTransitionTarget)
            {
                if ((_filterIntensity - filterIntensityTransitionStep) > _filterIntensityTransitionTarget)
                {
                    [self setFilterIntensity:(_filterIntensity - filterIntensityTransitionStep)];
                }
                else
                {
                    [self setFilterIntensity:_filterIntensityTransitionTarget];
                }
            }
        }
        else
        {
            dispatch_source_cancel(_filterIntensityTransitionTimer);
        }
        
    });
    
    dispatch_resume(_filterIntensityTransitionTimer);
}

#pragma mark -
#pragma mark Filtering (Kernel)

double normalProbabilityDensityFunction(double x, double sigma)
{
    return 0.39894f * exp(-0.5f*x*x / (sigma*sigma)) / sigma;
}

float lerp(float t, float min, float max)
{
    return (1-t)*min + t*max;
}

float smoothStep(float t, float min, float max)
{
    return lerp(t*t*t * (t * (6.0f*t - 15.0f) + 10.0f), min, max);
}

float coserp(float t, float min, float max)
{
    return lerp(1.0f - cosf(t * M_PI * 0.5f), min, max);
}

float expLerp(float t, float min, float max)
{
    return lerp(t*t, min, max);
}

void createTextureFilterKernel(float t, unsigned int kernelRadius, TextureFilterKernel_t * textureFilterKernel)
{
    GLint kernelSize = 2 * kernelRadius + 1;
    
    // "rule of thumb" sigma = kernelSize / 3
    float const maxSigmaForKernelSize = ((float)kernelSize) / 3.0f;
    float const minSigmaForKernelSize = 0.1f;
    
    // Lerp sigma value between 0.1 and the best sigma for the kernelRadius
    float sigma = expLerp(t, minSigmaForKernelSize, maxSigmaForKernelSize);
    
    // Create 1D kernel
    GLfloat * kernelValue = calloc(kernelSize, sizeof(GLfloat)); // float
    for (int i=0; i<=kernelRadius; ++i)
    {
        kernelValue[kernelRadius-i] = kernelValue[kernelRadius+i] = normalProbabilityDensityFunction(i, sigma);
    }
    
    // Calculate the kernel sum
    GLfloat kernelSum = 0.0;
    for (int i=0; i<kernelSize; ++i)
    {
        kernelSum += kernelValue[i];
    }
    
    // Normalize so kernelSum is 1.0
    GLfloat kernelSumInv = 1.0f/kernelSum;
    kernelSum = 0.0;
    for (int i=0; i<kernelSize; ++i)
    {
        kernelValue[i] *= kernelSumInv;
        kernelSum += kernelValue[i];
    }
    
    // Log kernel
    printf("kernel (step = %f, r = %u, s = %f, sum = %f) [", t, kernelRadius, sigma, kernelSum);
    for (int i = 0; i<kernelSize; ++i)
    {
        printf(" %f ", kernelValue[i]);
    }
    printf("]\n");
    
    textureFilterKernel->kernelRadius = kernelRadius;
    textureFilterKernel->kernelSize = kernelSize;
    textureFilterKernel->kernelValue = kernelValue;
}

void releaseTextureFilterKernel(TextureFilterKernel_t * textureFilterKernel)
{
    textureFilterKernel->kernelSize = 0;
    textureFilterKernel->kernelRadius = 0;
    free(textureFilterKernel->kernelValue);
}

- (void)loadFilterKernel
{
    unsigned int const kernelRadius = 16.0;
    
    // Define how many kernels should be generated
    size_t textureFilterKernelCount = 10;
    TextureFilterKernel_t * textureFilterKernelArray = (TextureFilterKernel_t *)calloc(textureFilterKernelCount, sizeof(TextureFilterKernel_t));
    
    // t, used for linear interpolation
    float t = 0.0f;
    float tDelta = 1.0f/(float)(textureFilterKernelCount-1);
    
    // Create all filter kernels
    for (int i=0; i<textureFilterKernelCount; ++i)
    {
        createTextureFilterKernel(t, kernelRadius, &textureFilterKernelArray[i]);
        t += tDelta;
    }
    
    // Store in the TextureInstance
    _filterKernelCount = textureFilterKernelCount;
    _filterKernelArray = textureFilterKernelArray;
}

@end