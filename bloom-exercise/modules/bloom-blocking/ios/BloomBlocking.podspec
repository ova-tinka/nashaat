Pod::Spec.new do |s|
  s.name           = 'BloomBlocking'
  s.version        = '1.0.0'
  s.summary        = 'Native app and website blocking for Bloom Exercise'
  s.description    = 'Uses Screen Time controls on Apple mobile devices.'
  s.author         = 'Bloom Exercise'
  s.homepage       = 'https://expo.dev'
  s.platforms      = {
    :ios => '16.4',
    :tvos => '16.4'
  }
  s.source         = { git: '' }
  s.static_framework = true

  s.dependency 'ExpoModulesCore'

  # Swift/Objective-C compatibility
  bloom_xcconfig = {
    'DEFINES_MODULE' => 'YES',
  }

  # The direct usage-data API was introduced in the iOS 26.4 SDK.
  sdk_version = `xcrun --sdk iphoneos --show-sdk-version 2>/dev/null`.strip
  if !sdk_version.empty? && Gem::Version.new(sdk_version) >= Gem::Version.new('26.4')
    bloom_xcconfig['OTHER_SWIFT_FLAGS'] = '$(inherited) -DBLOOM_USAGE_DATA'
  end
  s.pod_target_xcconfig = bloom_xcconfig

  s.source_files = "**/*.{h,m,mm,swift,hpp,cpp}"
end
