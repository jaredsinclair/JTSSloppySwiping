Pod::Spec.new do |s|
  s.name         = "JTSSloppySwiping"
  s.version      = "0.0.1"
  s.summary      = "Drop-in UINavigationControllerDelegate that enables sloppy swiping."

  s.homepage     = "https://github.com/jaredsinclair/JTSSloppySwiping"
  s.license      = "MIT"
  s.author       = { "Jared Sinclair" => "desk@jaredsinclair.com" }
  s.platform     = :ios, "8.0"

  s.source       = { :git => "https://github.com/jaredsinclair/JTSSloppySwiping.git", :commit => "9aa60dce36a3f957f262f121de2a0b34316109d0" }

  s.source_files  = "JTSSloppySwiping/**/*.swift"
  s.framework  = "UIKit"
  s.requires_arc = true
end
