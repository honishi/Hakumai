platform :osx, '10.10'
inhibit_all_warnings!

target 'Hakumai' do
  use_frameworks!

  pod 'FMDB', '~> 2.5'
  pod 'Ono', '~> 1.2.2'
  pod 'Sparkle', '~> 1.14.0'
  pod 'SSKeychain', '~> 1.2.3'
  pod 'XCGLogger', '~> 3.3'

  # work around #1/2 for FMDB swift integration issue, https://github.com/ccgus/fmdb/issues/309#issuecomment-135291683
  pod 'FMDB/SQLCipher', '~> 2.5'

  target 'HakumaiTests' do
    inherit! :search_paths
  end
end

# work around #2/2, https://github.com/ccgus/fmdb/issues/309#issuecomment-156499145
post_install do |installer|
  Dir['Pods/*/**/*.h'].each { |file|
    search_text = %q["sqlite3.h"]
    replace_text = '<SQLCipher/sqlite3.h>'

    oldFile = File.read(file)
    if oldFile.include? search_text
        puts "#{file} includes #{search_text}"

        File.chmod(0604, file) # rw----r--
        newFile = oldFile.gsub(/#{search_text}/, replace_text)
        File.open(file, "w") { |file|
          file << newFile
        }
    end
  }
end
