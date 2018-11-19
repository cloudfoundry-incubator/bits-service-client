# frozen_string_literal: true
$LOAD_PATH.unshift(File.expand_path('../../lib', __FILE__))

require 'bundler/setup'
require 'bits_service_client'

require 'rack/test'
require 'steno'

RSpec.configure do |rspec_config|
  rspec_config.before :all, unit: true do
      # Webmock does inject into the net http conncetion and for this reason it is only added to the path if its used.
      require 'webmock/rspec'
      WebMock.disable_net_connect!
  end
end



