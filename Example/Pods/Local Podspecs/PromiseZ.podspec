Pod::Spec.new do |s|
  s.name                  = "PromiseZ"
  s.version               = "0.2.0"
  s.summary               = "Promises/A+ done right and done small."
  s.homepage              = "https://github.com/zradke/PromiseZ"
  s.license               = 'MIT'
  s.author                = { "Zach Radke" => "zach.radke@gmail.com" }
  s.source                = { :git => "https://github.com/zradke/PromiseZ.git", :tag => s.version.to_s }
  s.ios.deployment_target = '6.0'
  s.osx.deployment_target = '10.8'
  s.requires_arc          = true
  s.source_files          = 'Pod/Classes/**/*'
end
