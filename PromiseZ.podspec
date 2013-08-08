#
# Be sure to run `pod spec lint PromiseZ.podspec' to ensure this is a
# valid spec and remove all comments before submitting the spec.
#
# To learn more about the attributes see http://docs.cocoapods.org/specification.html
#
Pod::Spec.new do |s|
  s.name         = "PromiseZ"
  s.version      = "0.1.0"
  s.summary      = "PromiseZ done right and done small."
  s.description  = <<-DESC
                     PromiseZ is a small framework implementing the Promises/A+ spec
                     defined [at the Github page](https://github.com/promises-aplus/promises-spec).
                     
                     Using and returning promises from methods allows them to be asyncronous,
                     chainable, and error catching!
                   DESC
  s.homepage     = "https://git.dev.rakuten.com/scm/~zachary.radke/promisez.git"
  s.license      = 'MIT (example)'
  s.author       = { "Zach Radke" => "zachary.radke@mail.rakuten.com" }
  s.source       = { :git => "https://git.dev.rakuten.com/scm/~zachary.radke/promisez.git", :tag => s.version.to_s }

  # If this Pod runs only on iOS or OS X, then specify the platform and
  # the deployment target.
  #
  # s.platform     = :ios, '5.0'

  # ――― MULTI-PLATFORM VALUES ――――――――――――――――――――――――――――――――――――――――――――――――― #

  # If this Pod runs on both platforms, then specify the deployment
  # targets.
  #
  # s.ios.deployment_target = '5.0'
  # s.osx.deployment_target = '10.7'

  s.source_files = 'Classes', 'Classes/**/*.{h,m}'

  # A list of file patterns which select the header files that should be
  # made available to the application. If the pattern is a directory then the
  # path will automatically have '*.h' appended.
  #
  # If you do not explicitly set the list of public header files,
  # all headers of source_files will be made public.
  #
  # s.public_header_files = 'Classes/**/*.h'

  s.requires_arc = true
end
