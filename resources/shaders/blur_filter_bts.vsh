// (In) Vertex attributes
attribute vec4 VertPosition;
attribute vec2 VertTextureCoordinate;

// (In) Vertex uniforms (shared)
uniform lowp int   FilterKernelSamples;
uniform highp vec2 FilterSplitPassDirectionVector;

// (In) Vertex uniforms
uniform float VertFilterKernelOffsets[14];

// (Out) Fragment variables
varying vec2 FragTextureCoordinate;
varying vec2 FragFilterSplitPassKernelOffsets[14];

void main()
{
  // Sample with the provided weights and offsets in one direction
  for (int s = 0; s < FilterKernelSamples; ++s)
  {
    FragFilterSplitPassKernelOffsets[s] = VertFilterKernelOffsets[s]*FilterSplitPassDirectionVector;
  }

  FragTextureCoordinate = VertTextureCoordinate.xy;
  gl_Position = VertPosition;
}
