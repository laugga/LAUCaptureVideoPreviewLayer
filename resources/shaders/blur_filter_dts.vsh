// (In) Vertex attributes
attribute vec4 VertPosition;
attribute vec2 VertTextureCoordinate;

// (Out) Fragment variables
varying vec2 FragTextureCoordinate;

void main()
{
  FragTextureCoordinate = VertTextureCoordinate.xy;
  gl_Position = VertPosition;
}
