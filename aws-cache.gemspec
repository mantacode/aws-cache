lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'aws-cache-version'

Gem::Specification.new do |s|
  s.name = 'aws-cache'
  s.homepage = 'https://github.com/mantacode/aws-cache'
  s.version = AwsCacheVersion::VERSION
  s.summary = 'AWS api access layer that caches via Redis.'
  s.description = 'You know, to avoid api throttling errors.'
  s.licenses = ['MIT']
  s.authors = ["Stephen J. Smith", "Brian J. Schrock"]
  s.email = 'stsmith@manta.com'
  s.files += Dir['lib/**/*.rb']
  s.add_runtime_dependency 'aws-sdk'
  s.add_runtime_dependency 'redis'
end
