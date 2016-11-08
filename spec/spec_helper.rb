$LOAD_PATH.unshift(File.expand_path('../../lib', __FILE__))

require 'bundler/setup'
require 'bits_service_client'

require 'rack/test'
require 'steno'
require 'webmock/rspec'

RSpec.configure do |rspec_config|
  rspec_config.before(:all) { WebMock.disable_net_connect! }
end
