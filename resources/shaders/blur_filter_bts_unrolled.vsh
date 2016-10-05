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
varying vec2 FragFilterTextureCoordinates[8];
varying vec2 FragFilterSplitPassKernelOffsets[6];

void main()
{
  // Sample with the provided weights and offsets in one direction
  // Unrolled for loop. Constant FilterKernelSamples = 10.

  // Pre-calculated texture coordinates
  FragFilterTextureCoordinates[0] = VertTextureCoordinate - (VertFilterKernelOffsets[0]*FilterSplitPassDirectionVector);
  FragFilterTextureCoordinates[1] = VertTextureCoordinate + (VertFilterKernelOffsets[0]*FilterSplitPassDirectionVector);
  FragFilterTextureCoordinates[2] = VertTextureCoordinate - (VertFilterKernelOffsets[1]*FilterSplitPassDirectionVector);
  FragFilterTextureCoordinates[3] = VertTextureCoordinate + (VertFilterKernelOffsets[1]*FilterSplitPassDirectionVector);
  FragFilterTextureCoordinates[4] = VertTextureCoordinate - (VertFilterKernelOffsets[2]*FilterSplitPassDirectionVector);
  FragFilterTextureCoordinates[5] = VertTextureCoordinate + (VertFilterKernelOffsets[2]*FilterSplitPassDirectionVector);
  FragFilterTextureCoordinates[6] = VertTextureCoordinate - (VertFilterKernelOffsets[3]*FilterSplitPassDirectionVector);
  FragFilterTextureCoordinates[7] = VertTextureCoordinate + (VertFilterKernelOffsets[3]*FilterSplitPassDirectionVector);

  // Pre-calculated offsets
  // Limit is 32 varying floats, it's no possible to pre-calculate all texture coordinates
  FragFilterSplitPassKernelOffsets[0] = VertFilterKernelOffsets[4]*FilterSplitPassDirectionVector;
  FragFilterSplitPassKernelOffsets[1] = VertFilterKernelOffsets[5]*FilterSplitPassDirectionVector;
  FragFilterSplitPassKernelOffsets[2] = VertFilterKernelOffsets[6]*FilterSplitPassDirectionVector;
  FragFilterSplitPassKernelOffsets[3] = VertFilterKernelOffsets[7]*FilterSplitPassDirectionVector;
  FragFilterSplitPassKernelOffsets[4] = VertFilterKernelOffsets[8]*FilterSplitPassDirectionVector;
  FragFilterSplitPassKernelOffsets[5] = VertFilterKernelOffsets[9]*FilterSplitPassDirectionVector;

  FragTextureCoordinate = VertTextureCoordinate;
  gl_Position = VertPosition;
}
