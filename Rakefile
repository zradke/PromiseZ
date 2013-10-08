namespace :test do
  desc "Run PromiseZ tests for iOS"
  task :ios do
    $ios_success = system("xctool -workspace Project/PromiseZ.xcworkspace -scheme 'PromiseZ-iOS' -sdk iphonesimulator -configuration Release clean test")
  end

  desc "Run PromiseZ tests for OSX"
  task :osx do
    $osx_success = system("xctool -workspace Project/PromiseZ.xcworkspace -scheme 'PromiseZ-OSX' -sdk macosx -configuration Release clean test")
  end
end

desc "Run PromiseZ tests for iOS and OSX"
task :test => ['test:ios', 'test:osx'] do
  puts "\033[0;31m! iOS unit tests failed" unless $ios_success
  puts "\033[0;31m! OSX unit tests failed" unless $osx_success
  if $ios_success && $osx_success
    puts "\033[0;32m** All tests succeeded!"
  else
    exit(-1)
  end
end
task :default => :test

