#ifdef GL_ES
precision highp float;
#endif

// (In) Texture coordinate for the fragment
varying vec2 FragTextureCoordinate;

// Uniforms (VideoFrame)
uniform sampler2D FragTextureData;

void main()
{
  gl_FragColor = texture2D(FragTextureData, FragTextureCoordinate);
}
