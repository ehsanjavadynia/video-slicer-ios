platform :ios, '16.0'
use_frameworks!

target 'VideoSlicer' do
  pod 'Kingfisher', '~> 7.0'
end

target 'VideoSlicerTests' do
  inherit! :search_paths
  pod 'Quick', '~> 7.0'
  pod 'Nimble', '~> 13.0'
end

target 'VideoSlicerUITests' do
  inherit! :search_paths
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.0'
      config.build_settings['SWIFT_VERSION'] = '5.9'
    end
  end
end
