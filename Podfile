platform :osx, '10.15'
inhibit_all_warnings!

target 'Hakumai' do
  use_frameworks!

  # Project Infrastructure
  pod 'Sparkle', '~> 2.1.0'
  pod 'SwiftLint', '~> 0.55.1'
  pod 'SwiftGen', '~> 6.5.1'
  pod 'SwiftProtobuf', '~> 1.0'
  pod 'XCGLogger', '~> 7.0.1'

  # Infrastructure
  pod 'Alamofire', '~> 5.10.2'
  pod 'FMDB', '~> 2.7.5'
  pod 'Kanna', '~> 5.2.7'
  pod 'SAMKeychain', '~> 1.5.3'
  pod 'Starscream', '~> 4.0.6'

  # User Interface
  pod 'DGCharts', '~> 5.0.0'
  pod 'Kingfisher', '~> 6.3.1'
  pod 'SnapKit', '~> 5.6.0'

  target 'HakumaiTests' do
    inherit! :search_paths
  end
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '10.15'
    end
  end
end
