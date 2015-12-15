Pod::Spec.new do |s|
  s.name          = 'TTNCache'
  s.version       = '0.0.2'
  s.source_files  = 'TTNCache/*.{h,m}'
  s.homepage      = 'https://github.com/TouTooNet/TTNCache'
  s.summary       = 'Fast object cache for iOS and OS X.'
  s.authors       = { 'SimMan' => 'liwei0990@gmail.com' }
  s.source        = { :git => 'https://github.com/TouTooNet/TTNCache.git', :tag => "#{s.version}" }
  s.license       = { :type => 'MIT', :file => 'LICENSE' }
  s.requires_arc  = true
  s.frameworks    = 'Foundation'
  s.ios.weak_frameworks   = 'UIKit'
  s.osx.weak_frameworks   = 'AppKit'
  s.ios.deployment_target = '5.0'
  s.osx.deployment_target = '10.7'
end
