/*
 
 LMTCaptureVideoPreviewLayerStructures.h
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

#ifndef LMTCaptureVideoPreviewLayerStructures_h
#define LMTCaptureVideoPreviewLayerStructures_h

#pragma mark -
#pragma Shader handles

struct UniformHandles {
    
    GLuint FragTextureData;
    
    GLuint FragFilterEnabled; // bool
    GLuint FragFilterBounds; // vec4
    
    GLuint FragFilterSplitPassDirectionVector; // vec2 (x or y step direction)
    
    GLuint FragFilterKernelWeights; // float[]
    GLuint FragFilterKernelRadius; // float
    GLuint FragFilterKernelSize; // float
    
    GLuint FragFilterKernelOffsets; // float[]
    GLuint FragFilterKernelSamples; // float
};

struct AttributeHandles {
    GLuint VertPosition;
    GLuint VertTextureCoordinate;
};

struct FilterKernel {
    GLuint radius;
    GLfloat * weights;
    GLuint samples; // s
    GLfloat * offsets;
    GLuint size; // m
};

typedef struct FilterKernel FilterKernel_t;

struct OffscreenTextureInstance {
    
    // Texture dimensions
    GLfloat textureWidth;
    GLfloat textureHeight;
    
    // Texture binding
    GLuint textureName;
    GLuint textureTarget; // ie. GL_TEXTURE_2D
    
    // Geometry, VAO for drawing quad (optional)
    GLuint vertexArray;
    GLuint vertexBuffers[2];
    GLuint vertexCount;
    
    // Geometry, primitive type such as GL_TRIANGLE_STRIP (optional)
    GLuint primitiveType;
    
    // Drawing framebuffer
    GLuint framebuffer;
    
    // Filter parameters
    GLfloat filterKernelStep[2]; // The direction of the filter FragFilterKernelStep
};

typedef struct OffscreenTextureInstance OffscreenTextureInstance_t;

struct TextureInstance {

    // Texture dimensions
    GLfloat textureWidth;
    GLfloat textureHeight;
    
    // Texture binding
    GLuint textureName;
    GLuint textureTarget; // ie. GL_TEXTURE_2D
    
    // Texture coordinates (aspect-fit) (optional)
    GLfloat textureCoordinates[8];
    
    // Geometry, VAO for drawing quad (optional)
    GLuint vertexArray;
    GLuint vertexBuffers[2];
    GLuint vertexCount;
    
    // Geometry, primitive type such as GL_TRIANGLE_STRIP (optional)
    GLuint primitiveType;
    
    // Drawing framebuffer
    GLuint framebuffer;
};

typedef struct TextureInstance TextureInstance_t;

#endif /* LMTCaptureVideoPreviewLayerStructures_h */
