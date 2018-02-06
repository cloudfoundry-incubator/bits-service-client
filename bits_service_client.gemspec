# coding: utf-8
# frozen_string_literal: true
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'bits_service_client/version'

Gem::Specification.new do |spec|
  spec.name          = 'bits_service_client'
  spec.version       = BitsServiceClient::VERSION
  spec.authors       = ['Rizwan Reza', 'Steffen Uhlig', 'Peter Goetz', 'Norman Sutorius']
  spec.email         = ['rizwanreza@gmail.com', 'steffen.uhlig@de.ibm.com', 'peter.gtz@gmail.com', 'norman.sutorius@de.ibm.com']

  spec.summary       = 'Bits Services client for Cloud Foundry'
  spec.homepage      = 'https://github.com/cloudfoundry-incubator/bits-service-client'

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.require_paths = ['lib']

  spec.add_dependency 'activesupport'
  spec.add_dependency 'steno'

  spec.add_development_dependency 'bundler', '~> 1.11'
  spec.add_development_dependency 'multipart-post'
  spec.add_development_dependency 'rack-test'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rb-readline'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'webmock', '= 1.20.4'
end
