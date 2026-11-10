Pod::Spec.new do |s|
  s.name             = 'BoringSSL-GRPC'
  s.version          = '0.0.37'
  s.summary          = 'BoringSSL is a fork of OpenSSL that is designed to meet Google needs.'
  s.description      = 'BoringSSL is a fork of OpenSSL that is designed to meet Google needs. Locally pre-downloaded to avoid git clone timeout issues.'
  s.homepage         = 'https://github.com/google/boringssl'
  s.license          = { :type => 'Mixed', :file => 'LICENSE' }
  s.authors          = ['Adam Langley', 'David Benjamin', 'Matt Braithwaite']
  s.source           = { :path => '.' }

  s.platforms = {
    :ios => '10.0',
    :osx => '10.12',
    :tvos => '12.0',
    :watchos => '6.0',
    :visionos => '1.0'
  }

  s.module_name        = 'openssl_grpc'
  s.header_mappings_dir = 'src/include/openssl'
  s.header_dir         = 'openssl_grpc'
  s.compiler_flags     = ['-DOPENSSL_NO_ASM', '-w', '-DBORINGSSL_PREFIX=GRPC']
  s.requires_arc       = false
  s.pod_target_xcconfig = { 'USE_HEADERMAP' => 'NO' }

  s.subspec 'Interface' do |ss|
    ss.header_mappings_dir = 'src/include/openssl'
    ss.private_header_files = 'src/include/openssl/time.h'
    ss.source_files = ['src/include/openssl/*.h', 'src/include/openssl/**/*.h']
  end

  s.subspec 'Implementation' do |ss|
    ss.header_mappings_dir = 'src'
    ss.resource_bundles = { 'openssl_grpc' => 'src/PrivacyInfo.xcprivacy' }
    ss.source_files = [
      'src/ssl/*.{h,c,cc}',
      'src/ssl/**/*.{h,c,cc}',
      'src/crypto/*.{h,c,cc}',
      'src/crypto/**/*.{h,c,cc,inc}',
      'src/third_party/fiat/*.{h,c,cc}',
      'src/gen/crypto/err_data.c'
    ]
    ss.private_header_files = [
      'src/ssl/*.h',
      'src/ssl/**/*.h',
      'src/crypto/*.h',
      'src/crypto/**/*.h',
      'src/third_party/fiat/*.h'
    ]
    ss.exclude_files = [
      'src/**/*_test.*',
      'src/**/test_*.*',
      'src/**/test/*.*'
    ]
    ss.dependency 'BoringSSL-GRPC/Interface'
  end
end
