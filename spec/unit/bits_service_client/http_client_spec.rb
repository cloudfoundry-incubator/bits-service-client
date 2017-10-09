# frozen_string_literal: true
require 'spec_helper'
require 'ostruct'
require 'securerandom'

RSpec.describe BitsService::Client do
  let(:resource_type) { 'buildpacks'}
  let(:vcap_request_id) { '4711' }
  let(:key) { SecureRandom.uuid }
  let(:https_options) do
    {
      enabled: true,
      private_endpoint: 'https://private-host',
      public_endpoint: 'https://public-host',
      username: 'admin',
      password: 'admin',
    }
  end
  let(:http_options) do
    {
      enabled: true,
      private_endpoint: 'http://private-host',
      public_endpoint: 'http://public-host',
      username: 'admin',
      password: 'admin',
    }
  end

  describe 'Request with https uri schema' do
    before do
      uri = URI.parse("https://private-host/#{resource_type}/#{key}")
      stub_request(:head, uri).to_return(status: 200)
    end

    it 'returns true' do
      bits_client = BitsService::Client.new(bits_service_options: https_options, resource_type: resource_type, vcap_request_id: vcap_request_id)
      expect(bits_client.exists?(key)).to be_truthy
    end
  end

  describe 'Request with http uri schema' do
    before do
      uri = URI.parse("http://private-host/#{resource_type}/#{key}")
      stub_request(:head, uri).to_return(status: 200)
    end

    it 'returns true' do
      bits_client = BitsService::Client.new(bits_service_options: http_options, resource_type: resource_type, vcap_request_id: vcap_request_id)
      expect(bits_client.exists?(key)).to be_truthy
    end
  end
end
