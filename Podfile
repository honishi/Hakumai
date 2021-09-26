platform :osx, '10.12'
inhibit_all_warnings!

target 'Hakumai' do
  use_frameworks!

  pod 'SwiftLint', '~> 0.43.1'
  pod 'SwiftGen', '~> 6.4.0'
  pod 'XCGLogger', '~> 7.0.1'

  pod 'Sparkle', '~> 1.26.0'
  pod 'FMDB', '~> 2.7.5'
  pod 'SAMKeychain', '~> 1.5.3'
  pod 'Alamofire', '~> 5.4.3'
  pod 'Starscream', '~> 4.0.4'
  pod 'Kingfisher', '~> 6.3.0'
  pod 'SnapKit', '~> 5.0.1'
  pod 'Charts',
    :git => 'https://github.com/danielgindi/Charts.git',
    # Use commit instead of tag.
    # https://github.com/danielgindi/Charts/issues/4572
    # :tag => 'v4.0.1'
    :commit => '857db248f8eab9293e7845a53900ad109dc5cade'

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
