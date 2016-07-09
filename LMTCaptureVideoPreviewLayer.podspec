Pod::Spec.new do |s|
  s.name         = 'LMTCaptureVideoPreviewLayer'
  s.version      = '0.1.0'
  s.summary      = 'AVLMTCaptureVideoPreviewLayer replacement for iOS with a GPU-based blur filter.'
# s.description  = <<-DESC
#                   * Markdown format.
#                   * Don't worry about the indent, we strip it!
#                  DESC
  s.homepage     = 'https://github.com/coletiv/LMTCaptureVideoPreviewLayer'
# s.screenshots  = "www.example.com/screenshots_1", "www.example.com/screenshots_2"
  s.license      = 'MIT'
  s.author       = { 'Coletiv Studio' => 'humans@coletiv.co' }
  s.source       = { :git => 'https://github.com/coletiv/LMTCaptureVideoPreviewLayer.git', :tag => s.version.to_s }

  s.platform     = :ios, '7.0'
  s.ios.deployment_target = '7.0'
  s.requires_arc = true

  s.source_files = 'lib/*'

  s.public_header_files = 'lib/*.h'
  s.prefix_header_file = 'support/LMTCaptureVideoPreviewLayer-Prefix.pch'
  s.frameworks = 'AVFoundation', 'UIKit', 'CoreGraphics', 'QuartzCore', 'OpenGLES'
end
