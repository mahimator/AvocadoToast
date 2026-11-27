platform :ios, '18.2'

# VLC handles WebM/Opus and other formats AVPlayer cannot decode.
# MobileVLCKit is distributed under LGPL-2.1-or-later. See THIRD_PARTY_NOTICES.md.
target 'AvocadoToast' do
  use_frameworks!
  pod 'MobileVLCKit', '3.7.5'
end

install! 'cocoapods', :disable_input_output_paths => true

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
      config.build_settings['EXPANDED_CODE_SIGN_IDENTITY'] = ''
      config.build_settings['CODE_SIGNING_REQUIRED'] = 'NO'
      config.build_settings['CODE_SIGN_CLASS'] = ''
    end
  end
end
