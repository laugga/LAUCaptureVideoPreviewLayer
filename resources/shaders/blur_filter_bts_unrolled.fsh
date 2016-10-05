#ifdef GL_ES
precision highp float;
#endif

// Texture coordinate for the fragment
varying vec2 FragTextureCoordinate;
varying vec2 FragFilterTextureCoordinates[8];
varying vec2 FragFilterSplitPassKernelOffsets[6];

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

  // Unrolled for loop. Constant FilterKernelSamples = 10.
  // Sample with the provided weights and offsets in one direction

  float weight = FragFilterKernelWeights[0];
  weightedColor += weight * texture2D(FragTextureData, FragFilterTextureCoordinates[0]);
  weightedColor += weight * texture2D(FragTextureData, FragFilterTextureCoordinates[1]);
  weight = FragFilterKernelWeights[1];
  weightedColor += weight * texture2D(FragTextureData, FragFilterTextureCoordinates[2]);
  weightedColor += weight * texture2D(FragTextureData, FragFilterTextureCoordinates[3]);
  weight = FragFilterKernelWeights[2];
  weightedColor += weight * texture2D(FragTextureData, FragFilterTextureCoordinates[4]);
  weightedColor += weight * texture2D(FragTextureData, FragFilterTextureCoordinates[5]);
  weight = FragFilterKernelWeights[3];
  weightedColor += weight * texture2D(FragTextureData, FragFilterTextureCoordinates[6]);
  weightedColor += weight * texture2D(FragTextureData, FragFilterTextureCoordinates[7]);

  weight = FragFilterKernelWeights[4];
  vec2 offset = FragFilterSplitPassKernelOffsets[0];
  weightedColor += weight * texture2D(FragTextureData, FragTextureCoordinate - offset);
  weightedColor += weight * texture2D(FragTextureData, FragTextureCoordinate + offset);
  weight = FragFilterKernelWeights[5];
  offset = FragFilterSplitPassKernelOffsets[1];
  weightedColor += weight * texture2D(FragTextureData, FragTextureCoordinate - offset);
  weightedColor += weight * texture2D(FragTextureData, FragTextureCoordinate + offset);
  weight = FragFilterKernelWeights[6];
  offset = FragFilterSplitPassKernelOffsets[2];
  weightedColor += weight * texture2D(FragTextureData, FragTextureCoordinate - offset);
  weightedColor += weight * texture2D(FragTextureData, FragTextureCoordinate + offset);
  weight = FragFilterKernelWeights[7];
  offset = FragFilterSplitPassKernelOffsets[3];
  weightedColor += weight * texture2D(FragTextureData, FragTextureCoordinate - offset);
  weightedColor += weight * texture2D(FragTextureData, FragTextureCoordinate + offset);
  weight = FragFilterKernelWeights[8];
  offset = FragFilterSplitPassKernelOffsets[4];
  weightedColor += weight * texture2D(FragTextureData, FragTextureCoordinate - offset);
  weightedColor += weight * texture2D(FragTextureData, FragTextureCoordinate + offset);
  weight = FragFilterKernelWeights[9];
  offset = FragFilterSplitPassKernelOffsets[5];
  weightedColor += weight * texture2D(FragTextureData, FragTextureCoordinate - offset);
  weightedColor += weight * texture2D(FragTextureData, FragTextureCoordinate + offset);

  gl_FragColor = weightedColor;
}
