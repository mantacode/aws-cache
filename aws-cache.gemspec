Gem::Specification.new do |s|
  s.name = 'aws-cache'
  s.homepage = 'https://github.com/mantacode/aws-cache'
  s.version = '0.0.04'
  s.date = '2015-04-13'
  s.summary = 'AWS api access layer that caches via Redis.'
  s.description = 'You know, to avoid api throttling errors.'
  s.licenses = ['MIT']
  s.authors = ["Stephen J. Smith"]
  s.email = 'stsmith@manta.com'
  s.files += Dir['lib/**/*.rb']
  s.add_runtime_dependency 'aws-sdk'
  s.add_runtime_dependency 'redis'
end
