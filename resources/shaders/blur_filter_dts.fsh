#ifdef GL_ES
precision highp float;
#endif

// (In) Texture coordinate for the fragment
varying vec2 FragTextureCoordinate;

// Uniforms (VideoFrame)
uniform sampler2D FragTextureData;

// Uniforms (Filter)
uniform int FragFilterKernelSize; // Size = N
uniform int FragFilterKernelRadius; // Radius = N - 1
uniform float FragFilterKernelWeights[50]; // 1D convolution kernel
uniform vec2 FilterSplitPassDirectionVector; // Apply kernel in direction, x or y

void main()
{
  // Weighted color sum of all the neighbour pixel
  vec4 weightedColor = vec4(0.0);

  // Convolve with the provided Kernel in one direction
  for (int offset = -FragFilterKernelRadius; offset <= FragFilterKernelRadius; ++offset)
  {
    float weight = FragFilterKernelWeights[FragFilterKernelRadius+offset];
    weightedColor += weight * texture2D(FragTextureData, FragTextureCoordinate.xy + (float(offset)*FilterSplitPassDirectionVector));
  }

  gl_FragColor = weightedColor;
}
