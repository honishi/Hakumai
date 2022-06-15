platform :osx, '10.12'
inhibit_all_warnings!

target 'Hakumai' do
  use_frameworks!

  # Project Infrastructure
  pod 'Sparkle', '~> 2.1.0'
  pod 'SwiftLint', '~> 0.47.0'
  pod 'SwiftGen', '~> 6.5.1'
  pod 'XCGLogger', '~> 7.0.1'

  # Infrastructure
  pod 'Alamofire', '~> 5.6.0'
  pod 'FMDB', '~> 2.7.5'
  pod 'Kanna', '~> 5.2.7'
  pod 'SAMKeychain', '~> 1.5.3'
  pod 'Starscream', '~> 4.0.4'

  # User Interface
  pod 'Charts', '~> 4.0.2'
  pod 'Kingfisher', '~> 6.3.1'
  pod 'SnapKit', '~> 5.6.0'

  target 'HakumaiTests' do
    inherit! :search_paths
  end
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '10.12'
    end
  end
end
