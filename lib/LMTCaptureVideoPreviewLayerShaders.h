/*
 
 LMTCaptureVideoPreviewLayerShaders.h
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

#ifndef LMTCaptureVideoPreviewLayerShaders_h
#define LMTCaptureVideoPreviewLayerShaders_h

static const char * VertexShaderSource =
{
    "// (In) Vertex attributes                              \n"
    "attribute vec4 VertPosition;                           \n"
    "attribute vec2 VertTextureCoordinate;                  \n"
    
    "// (Out) Fragment variables                            \n"
    "varying vec2 FragTextureCoordinate;                    \n"
    
    "void main()                                            \n"
    "{                                                      \n"
    "    FragTextureCoordinate = VertTextureCoordinate.xy;  \n"
    "    gl_Position = VertPosition;                        \n"
    "}                                                      \n"

};

static const char * FragmentShaderSourceDiscreteTextureSampling =
{
    "#ifdef GL_ES                                                                                           \n"
    "precision highp float;                                                                                 \n"
    "#endif                                                                                                 \n"
    
    "// (In) Texture coordinate for the fragment                                                            \n"
    "varying vec2 FragTextureCoordinate;                                                                    \n"
    
    "// Uniforms (VideoFrame)                                                                               \n"
    "uniform sampler2D FragTextureData;                                                                     \n"
    
    "// Uniforms (Filter)                                                                                   \n"
    "uniform bool FragFilterEnabled; // Skip filter if enabled is false                                     \n"
    "uniform vec4 FragFilterBounds; // Bounds = { xMin, yMin, xMax, yMax }                                  \n"
    "uniform int FragFilterKernelSize; // Size = N                                                          \n"
    "uniform int FragFilterKernelRadius; // Radius = N - 1                                                  \n"
    "uniform float FragFilterKernelWeights[50]; // 1D convolution kernel                                    \n"
    "uniform vec2 FragFilterSplitPassDirectionVector; // Apply kernel in direction, x or y                  \n"
    
    "void main()                                                                                            \n"
    "{                                                                                                      \n"
    "   // Check if filter is not enabled or texture coordinate is outside the FragTextureFilterBounds      \n"
    "   if (FragFilterEnabled == false ||                                                                   \n"
    "       (FragTextureCoordinate.x < FragFilterBounds.x ||                                                \n"
    "        FragTextureCoordinate.y < FragFilterBounds.y ||                                                \n"
    "        FragTextureCoordinate.x > FragFilterBounds.z ||                                                \n"
    "        FragTextureCoordinate.y > FragFilterBounds.w))                                                 \n"
    "   {                                                                                                   \n"
    "       gl_FragColor = texture2D(FragTextureData, FragTextureCoordinate);                               \n"
    "   }                                                                                                   \n"
    "   else                                                                                                \n"
    "   {                                                                                                   \n"
    "       // Weighted color sum of all the neighbour pixel                                                \n"
    "       vec4 weightedColor = vec4(0.0);                                                                 \n"
            
    "       // Convolve with the provided Kernel in one direction                                                                                       \n"
    "       for (int offset = -FragFilterKernelRadius; offset <= FragFilterKernelRadius; ++offset)                                                      \n"
    "       {                                                                                                                                           \n"
    "           float weight = FragFilterKernelWeights[FragFilterKernelRadius+offset];                                                                  \n"
    "           weightedColor += weight * texture2D(FragTextureData, FragTextureCoordinate.xy + (float(offset)*FragFilterSplitPassDirectionVector));    \n"
    "       }                                                                                                                                           \n"
    "       gl_FragColor = weightedColor;                                                                                                               \n"
    "   }                                                                                                                                               \n"
    "}                                                                                                                                                  \n"
};

static const char * FragmentShaderSourceBilinearTextureSampling =
{
    "#ifdef GL_ES                                                           								\n"
    "precision highp float;                                                 								\n"
    "#endif                                                                 								\n"
    
    "// (In) Texture coordinate for the fragment                            								\n"
    "varying vec2 FragTextureCoordinate;                                    								\n"
    
    "// Uniforms (VideoFrame)                                               								\n"
    "uniform sampler2D FragTextureData;                                     								\n"
    
    "// Uniforms (Filter)                                                   								\n"
    "uniform bool FragFilterEnabled; // Skip filter if enabled is false     								\n"
    "uniform vec4 FragFilterBounds; // Bounds = { xMin, yMin, xMax, yMax }  								\n"
    "uniform int FragFilterKernelSamples; // Samples per pixel              								\n"
    "uniform float FragFilterKernelWeights[25]; // Weights                                                  \n"
    "uniform float FragFilterKernelOffsets[25]; // Offsets      											\n"
    "uniform vec2 FragFilterSplitPassDirectionVector; // Direction           								\n"
    
    "void main()                                                           									\n"
    "{                                                                      								\n"
    "    if (FragFilterEnabled == false ||              													\n"
    "		 (FragTextureCoordinate.x < FragFilterBounds.x ||                                               \n"
    "		  FragTextureCoordinate.y < FragFilterBounds.y ||                                               \n"
    "		  FragTextureCoordinate.x > FragFilterBounds.z ||                                               \n"
    "		  FragTextureCoordinate.y > FragFilterBounds.w))                                                \n"
    "    {                                                                                                  \n"
    "        gl_FragColor = texture2D(FragTextureData, FragTextureCoordinate);                              \n"
    "    }																									\n"
    "    else																							    \n"
    "    {                                                                                                  \n"
    "        // Weighted color sum of all the neighbour pixel												\n"
    "        vec4 weightedColor = vec4(0.0);																\n"
    
    "        // Sample with the provided weights and offsets in one direction                                                                   \n"
    "        for (int s = 0; s < FragFilterKernelSamples; ++s)                                                                                  \n"
    "        {                                                                                                                                  \n"
    "           float weight = FragFilterKernelWeights[s];                                                                                      \n"
    "			float offset = FragFilterKernelOffsets[s];                                                                                      \n"
    "		 	weightedColor += weight * texture2D(FragTextureData, FragTextureCoordinate.xy - offset*FragFilterSplitPassDirectionVector) +	\n"
    "						     weight * texture2D(FragTextureData, FragTextureCoordinate.xy + offset*FragFilterSplitPassDirectionVector);		\n"
    "        }                                                                                                                                  \n"
    "        gl_FragColor = weightedColor;																										\n"
    "    }                                                                                                                                      \n"
    "}                                                                                                                                          \n"
};

#endif /* LMTCaptureVideoPreviewLayerShaders_h */
