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
#import "LMTCaptureVideoPreviewLayerUtilities.h"
#import "LMTCaptureVideoPreviewLayerGaussianFilterKernel.h"

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
    
    // Shader programs
    GLuint _defaultProgram; // On-screen
    GLuint _blurFilterProgram; // Off-screen
    
    // Shader bindings
    struct UniformHandles _defaultUniforms;
    struct AttributeHandles _defaultAttributes;
    struct UniformHandles _blurFilterUniforms;
    struct AttributeHandles _blurFilterAttributes;
    
    // Offscreen Framebuffer
    OffscreenTextureInstance_t _pixelBufferTextureInstance;
    OffscreenTextureInstance_t _offscreenTextureInstances[2];
    
    // Onscreen Framebuffer
    GLuint _onscreenFramebuffer;
    GLuint _onscreenColorRenderbuffer;
    GLint _onscreenColorRenderbufferWidth;
    GLint _onscreenColorRenderbufferHeight;
    struct TextureInstance _onscreenTextureInstance;
    
    // Filter (Kernel)
    size_t _filterKernelCount; // Number of filter kernels created
    size_t _filterKernelIndex; // Currently loaded filter kernel
    FilterKernel_t * _filterKernelArray; // Kernels used for the interpolation between [0,1]
    
    // Filter (Parameters)
    GLfloat _filterSplitPassDirectionVector[2]; // Separable filter, apply 2x each in a specific direction (x or y)
    GLuint _filterMultiplePassCount; // Number of times filter should be applied before onscreen rendering
    GLfloat _filterDownsamplingFactor; // Downsample offscreen textures by a factor (ie. 2 = resize dimensions by 1/2)
    
    // Filter (Intensity)
    float _filterIntensity; // [0,1], 0 means no filter is applied
    BOOL _filterIntensityNeedsUpdate; // YES if filter intensity changed between draw calls
    dispatch_source_t _filterIntensityTransitionTimer; // Use for animated transition between different indices
    float _filterIntensityTransitionTarget;
    
    // Filter (Bounds)
    GLfloat _filterBounds[4];
    BOOL _filterBoundsNeedsUpdate;
}
@end

@implementation LMTCaptureVideoPreviewLayer

#define FilterBoundsEnabled 0
#define FilterBilinearTextureSamplingEnabled 0

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
        
        // Preemptively load filter in memory
        [self loadFilter];
    }
    return self;
}

- (void)layoutSublayers
{
    [super layoutSublayers];
    
    // Create the onscreen framebuffer
    [self createOnscreenFramebufferForLayer:self];

    // Load glsl programs, uniforms and attributes
    [self loadBlurFilterProgram];
    [self loadDefaultProgram];
    
    // Disable depth testing
    glDisable(GL_DEPTH_TEST);
    
    // Use texture 0
    glActiveTexture(GL_TEXTURE0);
    
    // OpenGL pre-warm
    if (!_internal.sampleBuffer)
    {
        [self drawColor:self.backgroundColor];
    }
    
    // Set filter intensity from blur value
    [self setFilterIntensity:_blur];
#if FilterBoundsEnabled
    [self setFilterBoundsRect:CGRectMake(0, 0, 1, 0.5)];
#endif
    
    // Create and setup displayLink
    _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(drawPixelBuffer:)];
    [_displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    _displayLink.frameInterval = 2;
}

- (void)loadDefaultProgram
{
    if (_defaultProgram)
    {
        return;
    }
    
    // Load default program
    _defaultProgram = loadProgram(VertexShaderSourceDefault, FragmentShaderSourceDefault);
    validateProgram(_defaultProgram);
    
    // Bind default attributes
    _defaultAttributes.VertPosition = glGetAttribLocation(_defaultProgram, "VertPosition");
    _defaultAttributes.VertTextureCoordinate = glGetAttribLocation(_defaultProgram, "VertTextureCoordinate");
    
    // Bind default uniforms
    _defaultUniforms.FragTextureData = glGetUniformLocation(_defaultProgram, "FragTextureData");
    
    // Use the blur filter glsl program
    glUseProgram(_defaultProgram);
}

- (void)loadBlurFilterProgram
{
    if (_blurFilterProgram)
    {
        return;
    }
    
    // Load blur filter program
#if FilterBilinearTextureSamplingEnabled
#if FilterBoundsEnabled
    _blurFilterProgram = loadProgram(VertexShaderSourceBts, FragmentShaderSourceBtsBounds);
#else
    _blurFilterProgram = loadProgram(VertexShaderSourceBts, FragmentShaderSourceBts);
#endif
#else
    _blurFilterProgram = loadProgram(VertexShaderSourceDefault, FragmentShaderSourceDts);
#endif
    
    validateProgram(_blurFilterProgram);
    
    // Bind blur filter attributes
    _blurFilterAttributes.VertPosition = glGetAttribLocation(_blurFilterProgram, "VertPosition");
    _blurFilterAttributes.VertTextureCoordinate = glGetAttribLocation(_blurFilterProgram, "VertTextureCoordinate");
    
    // Bind blur filter uniforms
    _blurFilterUniforms.FragTextureData = glGetUniformLocation(_blurFilterProgram, "FragTextureData");
    _blurFilterUniforms.FragFilterBounds = glGetUniformLocation(_blurFilterProgram, "FragFilterBounds");
#if FilterBilinearTextureSamplingEnabled
    _blurFilterUniforms.FilterKernelSamples = glGetUniformLocation(_blurFilterProgram, "FilterKernelSamples");
    _blurFilterUniforms.VertFilterKernelOffsets = glGetUniformLocation(_blurFilterProgram, "VertFilterKernelOffsets");
    _blurFilterUniforms.FragFilterKernelWeights = glGetUniformLocation(_blurFilterProgram, "FragFilterKernelWeights");
#else
    _blurFilterUniforms.FragFilterKernelRadius = glGetUniformLocation(_blurFilterProgram, "FragFilterKernelRadius");
    _blurFilterUniforms.FragFilterKernelSize = glGetUniformLocation(_blurFilterProgram, "FragFilterKernelSize");
    _blurFilterUniforms.FragFilterKernelWeights = glGetUniformLocation(_blurFilterProgram, "FragFilterKernelWeights");
#endif
    
    _blurFilterUniforms.FilterSplitPassDirectionVector = glGetUniformLocation(_blurFilterProgram, "FilterSplitPassDirectionVector");
}

- (void)unloadProgram
{
    // TODO
}

+ (Class)layerClass
{
    return [LMTCaptureVideoPreviewLayer class];
}

- (void)renderInContext:(CGContextRef)context
{
    // Assuming kEAGLColorFormatRGBA8 format is used
    NSInteger pixelsDataSize = _onscreenColorRenderbufferWidth * _onscreenColorRenderbufferHeight * 4;
    GLubyte * pixelsData = (GLubyte * )calloc(pixelsDataSize, sizeof(GLubyte));
    
    [self drawPixelBuffer:nil];
    
    // Bind the offscreen framebuffer
    glBindFramebuffer(GL_FRAMEBUFFER, _onscreenFramebuffer);
    
    // Read pixel data from the framebuffer
    glPixelStorei(GL_PACK_ALIGNMENT, 4);
    glReadPixels(0, 0, _onscreenColorRenderbufferWidth, _onscreenColorRenderbufferHeight, GL_RGBA, GL_UNSIGNED_BYTE, pixelsData);
    
    // Create a CGImage instance with the pixels data
    // Use kCGImageAlphaNoneSkipLast for opaque views (ignore the alpha channel) or kCGImageAlphaPremultipliedLast for non-opaque views
    CGDataProviderRef dataProvider = CGDataProviderCreateWithData(NULL, pixelsData, pixelsDataSize, NULL);
    CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
    CGImageRef image = CGImageCreate(_onscreenColorRenderbufferWidth,
                                     _onscreenColorRenderbufferHeight,
                                     8,
                                     32,
                                     _onscreenColorRenderbufferWidth * 4,
                                     colorspace,
                                     kCGBitmapByteOrder32Big | kCGImageAlphaPremultipliedLast,
                                     dataProvider,
                                     NULL,
                                     true,
                                     kCGRenderingIntentDefault);
    
    // Flip the CGImage by rendering it to the flipped bitmap context (UIKit coordinate system is the inverse of the Quartz/OpenGL coordinate system)
    CGContextSetBlendMode(context, kCGBlendModeCopy);
    CGContextDrawImage(context, CGRectMake(0.0, 0.0, _onscreenColorRenderbufferWidth / self.contentsScale, _onscreenColorRenderbufferHeight / self.contentsScale), image);
    
    free(pixelsData);
    CFRelease(dataProvider);
    CFRelease(colorspace);
    CGImageRelease(image);
}

#pragma mark -
#pragma mark Blur property

- (void)setBlur:(CGFloat)blur
{
    [self setBlur:blur animated:NO];
}

- (void)setBlur:(CGFloat)blur animated:(BOOL)animated
{
    _blur = blur;
    [self setFilterIntensity:_blur animated:animated];
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
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
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

- (CVOpenGLESTextureRef)setPixelBuffer:(CVPixelBufferRef)pixelBuffer toTextureInstance:(OffscreenTextureInstance_t *)textureInstance
{
    // Downsample input pixelBuffer by a specific factor
    GLfloat width = ((GLfloat)CVPixelBufferGetWidth(pixelBuffer))/_filterDownsamplingFactor;
    GLfloat height = ((GLfloat)CVPixelBufferGetHeight(pixelBuffer))/_filterDownsamplingFactor;
    
    // Get the OpenGL texture
    CVOpenGLESTextureRef oglTexture = [self oglTextureFromPixelBuffer:pixelBuffer];
    
    // Create a temporary offscreen texture instance wrapping the pixelBuffer
    textureInstance->textureWidth = width;
    textureInstance->textureHeight = height;
    textureInstance->textureTarget = CVOpenGLESTextureGetTarget(oglTexture);
    textureInstance->textureName = CVOpenGLESTextureGetName(oglTexture);
    
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
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    // Set the filter step
    glUniform2f(_blurFilterUniforms.FilterSplitPassDirectionVector, _filterSplitPassDirectionVector[0]/srcTextureInstance->textureWidth, _filterSplitPassDirectionVector[1]/srcTextureInstance->textureHeight);
    
    // Bind VAO
    glBindVertexArrayOES(destTextureInstance->vertexArray);
    
    // Draw the instance
    glDrawArrays(destTextureInstance->primitiveType, 0, destTextureInstance->vertexCount);
}

#pragma mark -
#pragma mark Onscreen rendering

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
        [self unloadProgram];
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
        textureScale = ((GLfloat)_onscreenColorRenderbufferWidth) / _onscreenTextureInstance.textureHeight;
    }
    // Change S, means we need to check view width vs. texture width
    // S is going to map [0,1]
    else {
        textureScale = ((GLfloat)_onscreenColorRenderbufferHeight) / _onscreenTextureInstance.textureWidth;
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
    glEnableVertexAttribArray(_defaultAttributes.VertPosition);
    glVertexAttribPointer(_defaultAttributes.VertPosition, 2, GL_FLOAT, GL_FALSE, stride, 0);
    
    // VBO 2, TextureCoordinate
    glBindBuffer(GL_ARRAY_BUFFER, _onscreenTextureInstance.vertexBuffers[1]);
    glBufferData(GL_ARRAY_BUFFER, _onscreenTextureInstance.vertexCount * stride, _onscreenTextureInstance.textureCoordinates, GL_STATIC_DRAW);
    glEnableVertexAttribArray(_defaultAttributes.VertTextureCoordinate);
    glVertexAttribPointer(_defaultAttributes.VertTextureCoordinate, 2, GL_FLOAT, GL_FALSE, stride, 0);
    
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
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
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
        glUniform1i(_defaultUniforms.FragTextureData, 0);
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
    CMSampleBufferRef sampleBuffer = self.internal.sampleBuffer;
    
    if (!sampleBuffer)
    {
        Log(@"CameraOGLPreviewView: sampleBuffer is NULL");
        return;
    }
    
    CVPixelBufferRef pixelBuffer = (CVPixelBufferRef)CFRetain(CMSampleBufferGetImageBuffer(sampleBuffer));
    
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
        // Use the blur filter program
        glUseProgram(_blurFilterProgram);
        
        // Update any uniform value that changed since last frame
        [self updateBlurFilterProgramUniforms];
        
        // Set the filter split-pass direction vector
        [self switchFilterSplitPassDirectionVector];
        
        // Set the pixelBuffer to a texture instance
        // We'll use two texture instances and ping-pong between them
        pixelBufferTexture = [self setPixelBuffer:pixelBuffer toTextureInstance:&_pixelBufferTextureInstance];
        
        // First Draw the pixel buffer in an offscreen texture instance (this is a special step)
        [self drawOffscreenTextureInstance:&_pixelBufferTextureInstance onOffscreenTextureInstance:&_offscreenTextureInstances[0]];
        
        // Draw the offscreen texture instances and keep applying the filter (ping, pong, ping, pong)
        // Because we did already drew once, the number of draw calls left = 2 * multiple-pass-count - 1
        for (int p=1; p<(2*_filterMultiplePassCount); ++p)
        {
            // Separable filtering, switch split-direction (vertical or horizontal)
            [self switchFilterSplitPassDirectionVector];
            
            // Draw split-pass (offscreen)
            [self drawOffscreenTextureInstance:&_offscreenTextureInstances[(p+1)%2] onOffscreenTextureInstance:&_offscreenTextureInstances[p%2]];
        }
        
        // Disabled filtering for final onscreen rendering
        glUseProgram(_defaultProgram);
        
        // Draw (onscreen)
        [self drawOnscreenOffscreenTextureInstance:&_offscreenTextureInstances[1]];
    }
    else
    {
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

- (void)updateBlurFilterProgramUniforms
{
    if (_filterIntensityNeedsUpdate)
    {
        FilterKernel_t filterKernel = _filterKernelArray[_filterKernelIndex];
        
#if FilterBilinearTextureSamplingEnabled
        glUniform1i(_blurFilterUniforms.FilterKernelSamples, filterKernel.samples);
        glUniform1fv(_blurFilterUniforms.VertFilterKernelOffsets, filterKernel.samples, filterKernel.offsets);
        glUniform1fv(_blurFilterUniforms.FragFilterKernelWeights, filterKernel.samples, filterKernel.weights);
#else
        glUniform1i(_blurFilterUniforms.FragFilterKernelRadius, filterKernel.radius);
        glUniform1i(_blurFilterUniforms.FragFilterKernelSize, filterKernel.size);
        glUniform1fv(_blurFilterUniforms.FragFilterKernelWeights, filterKernel.size, filterKernel.weights);
#endif
        
        _filterIntensityNeedsUpdate = NO;
    }
    
#if FilterBoundsEnabled
    if (_filterBoundsNeedsUpdate)
    {
        glUniform4fv(_blurFilterUniforms.FragFilterBounds, 1, _filterBounds);
        _filterBoundsNeedsUpdate = NO;
    }
    
#endif
}

#pragma mark -
#pragma mark Filtering (Intensity)

- (void)setFilterIntensity:(float)intensity
{
    // Bail out if the program hasn't been loaded yet
    if (!_blurFilterProgram)
    {
        return;
    }
    
    // Load filter kernel (will do nothing if it's already loaded)
    [self loadFilter];
    
    // Clamp intensity between [0,1] range
    float clampedIntensity =  MAX(0, MIN(1, intensity));
    
    // Assign the intensity value
    _filterIntensity = clampedIntensity;
    
    // Map intensity to a integer kernel index
    size_t mappedIndex = (size_t)roundf(clampedIntensity * ((float)(_filterKernelCount-1)));
    
    // Assign the mapped index
    _filterKernelIndex =  MAX(0, MIN(_filterKernelCount-1, mappedIndex));
    
    _filterIntensityNeedsUpdate = YES;
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
    dispatch_source_set_timer(_filterIntensityTransitionTimer, DISPATCH_TIME_NOW, (1.0f/60.0f) * NSEC_PER_SEC, 0.0 * NSEC_PER_SEC);
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
#pragma mark Filtering (Bounds)

#if FilterBoundsEnabled
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
    memcpy(_filterBounds, filterBounds, 4*sizeof(GLfloat));
    _filterBoundsNeedsUpdate = YES;
}
#endif

#pragma mark -
#pragma mark Filtering (Kernel)

void createFilterKernel(int kernelIndex, FilterKernel_t * filterKernel)
{
#if FilterBilinearTextureSamplingEnabled
    GLuint filterSamples = btsGaussianFilterSamplesForKernelIndex(kernelIndex);
    GLuint filterRadius = btsGaussianFilterRadiusForKernelIndex(kernelIndex);
    GLfloat filterSigma = btsGaussianFilterSigmaForKernelIndex(kernelIndex);
    GLfloat filterStep = btsGaussianFilterStepForKernelIndex(kernelIndex);
    
    // Create 1D kernel
    GLfloat * filterWeights = calloc(filterSamples, sizeof(GLfloat)); // float
    GLfloat * filterOffsets = calloc(filterSamples, sizeof(GLfloat)); // float
    for (int sampleIndex=0; sampleIndex<filterSamples; ++sampleIndex)
    {
        filterWeights[sampleIndex] = btsGaussianFilterWeightForIndexes(kernelIndex, sampleIndex);
        filterOffsets[sampleIndex] = btsGaussianFilterOffsetForIndexes(kernelIndex, sampleIndex);
    }
    
    // Log kernel
    printf("kernel (step = %f, radius = %u, sigma = %f, samples = %u) [", filterStep, filterRadius, filterSigma, filterSamples);
    for (int i = 0; i<filterSamples; ++i)
    {
        printf(" (%f, %f) ", filterWeights[i], filterOffsets[i]);
    }
    printf("]\n");
    
    filterKernel->radius = filterRadius;
    filterKernel->samples = filterSamples;
    filterKernel->weights = filterWeights;
    filterKernel->offsets = filterOffsets;
    
#else
    
    GLuint filterSize = dtsGaussianFilterSizeForKernelIndex(kernelIndex);
    GLuint filterRadius = dtsGaussianFilterRadiusForKernelIndex(kernelIndex);
    GLfloat filterSigma = dtsGaussianFilterSigmaForKernelIndex(kernelIndex);
    GLfloat filterStep = dtsGaussianFilterStepForKernelIndex(kernelIndex);
    
    // Create 1D kernel
    GLfloat * filterWeights = calloc(filterSize, sizeof(GLfloat)); // float
    for (int weightIndex=0; weightIndex<filterSize; ++weightIndex)
    {
        filterWeights[weightIndex] = dtsGaussianFilterWeightForIndexes(kernelIndex, weightIndex);
    }

    // Log kernel
    printf("kernel (step = %f, size = %u, radius = %u, sigma = %f) [", filterStep, filterSize, filterRadius, filterSigma);
    for (int i = 0; i<filterSize; ++i)
    {
        printf(" %f ", filterWeights[i]);
    }
    printf("]\n");
    
    filterKernel->radius = filterRadius;
    filterKernel->size = filterSize;
    filterKernel->weights = filterWeights;
#endif
}

void releaseFilterKernel(FilterKernel_t * filterKernel)
{
    filterKernel->size = 0;
    filterKernel->radius = 0;
    free(filterKernel->weights);

#if FilterBilinearTextureSamplingEnabled
    free(filterKernel->offsets);
#endif
}

- (void)loadFilter
{
    // Skip if it's already loaded
    if (_filterKernelCount)
    {
        return;
    }
    
    // Define how many filter kernels should be generated
    size_t filterKernelCount = gaussianFilterKernelCount();
    FilterKernel_t * filterKernelArray = (FilterKernel_t *)calloc(filterKernelCount, sizeof(FilterKernel_t));
    
    // Create all filter kernels
    for (int i=0; i<filterKernelCount; ++i)
    {
        createFilterKernel(i, &filterKernelArray[i]);
    }
    
    // Store in the TextureInstance
    _filterKernelCount = filterKernelCount;
    _filterKernelArray = filterKernelArray;
    
    // Filter parameters
    _filterDownsamplingFactor = 4.0f;
    _filterMultiplePassCount = 2;
}

- (void)switchFilterSplitPassDirectionVector
{
    if (_filterSplitPassDirectionVector[0] == 0)
    {
        _filterSplitPassDirectionVector[0] = 1;
        _filterSplitPassDirectionVector[1] = 0;
    }
    else
    {
        _filterSplitPassDirectionVector[0] = 0;
        _filterSplitPassDirectionVector[1] = 1;
    }
}

@end
