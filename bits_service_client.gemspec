# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'bits_service_client/version'

Gem::Specification.new do |spec|
  spec.name          = "bits_service_client"
  spec.version       = BitsServiceClient::VERSION
  spec.authors       = ["Rizwan Reza"]
  spec.email         = ["rizwanreza@gmail.com"]

  spec.summary       = %q{Bits Services client for Cloud Foundry}
  spec.homepage      = "http://github.com/cloudfoundry/bits_service_client"

  # Prevent pushing this gem to RubyGems.org by setting 'allowed_push_host', or
  # delete this section to allow pushing this gem to any host.

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.require_paths = ["lib"]

  spec.add_dependency "steno"
  spec.add_dependency "activesupport"

  spec.add_development_dependency "bundler", "~> 1.11"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "webmock", '= 1.20.4'
  spec.add_development_dependency "multipart-post"
  spec.add_development_dependency "rack-test"
end
