#ifdef GL_ES
precision highp float;
#endif

// Texture coordinate for the fragment
varying vec2 FragTextureCoordinate;
varying vec2 FragFilterSplitPassKernelOffsets[14];

// Uniforms (VideoFrame)
uniform sampler2D FragTextureData;

// Uniforms (Filter)
uniform lowp int FilterKernelSamples; // Samples per pixel
uniform vec4 FragFilterBounds; // Bounds = { xMin, yMin, xMax, yMax }
uniform float FragFilterKernelWeights[14]; // Weights

void main()
{
  // Weighted color sum of all the neighbour pixel
  vec4 weightedColor = vec4(0.0);

  // Sample with the provided weights and offsets in one direction
  for (int s = 0; s < FilterKernelSamples; ++s)
  {
    float weight = FragFilterKernelWeights[s];
    vec2 offset = FragFilterSplitPassKernelOffsets[s];
    weightedColor += weight * texture2D(FragTextureData, FragTextureCoordinate - offset) +
                     weight * texture2D(FragTextureData, FragTextureCoordinate + offset);
  }

  gl_FragColor = weightedColor;
}
