
Pod::Spec.new do |s|
  s.name             = "JTSSloppySwiping"
  s.version          = "1.2.3"
  s.summary          = "A drop-in UINavigationControllerDelegate that enables sloppy swiping."
  s.description      = "A drop-in UINavigationControllerDelegate that enables sloppy swiping. I'm adding additional words here to satisy CocoaPods' pedantry."
  s.homepage         = "https://github.com/jaredsinclair/JTSSloppySwiping"
  s.license          = 'MIT'
  s.author           = { "Jared Sinclair" => "desk@jaredsinclair.com" }
  s.source           = { :git => "https://github.com/jaredsinclair/JTSSloppySwiping.git", :tag => s.version.to_s }

  s.platform     = :ios, '8.0'
  s.requires_arc = true

  s.frameworks = 'Foundation'
  s.source_files = 'JTSSloppySwiping/*.swift'
end
