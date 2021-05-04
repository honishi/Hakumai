platform :osx, '10.12'
inhibit_all_warnings!

target 'Hakumai' do
  use_frameworks!

  pod 'SwiftLint', '~> 0.43.1'
  pod 'SwiftGen', '~> 6.4.0'
  pod 'XCGLogger', '~> 7.0.1'

  pod 'Sparkle', '~> 1.26.0'
  pod 'FMDB', '~> 2.6.2'
  pod 'Ono', '~> 1.2.2'
  pod 'SAMKeychain', '~> 1.5.0'
  pod 'Alamofire', '~> 5.4.3'

  target 'HakumaiTests' do
    inherit! :search_paths
  end
end

# post_install do |installer|
#   installer.pods_project.targets.each do |target|
#     target.build_configurations.each do |config|
#       config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '10.9'
#     end
#   end
# end
