# frozen_string_literal: true

require 'spec_helper'
require 'ostruct'
require 'securerandom'

RSpec.describe BitsService::Client, unit: true do
  let(:resource_type) { 'buildpacks' }
  let(:vcap_request_id) { '4711' }
  let(:key) { SecureRandom.uuid }
  let(:https_options) do
    {
      enabled: true,
      private_endpoint: 'https://private-host',
      public_endpoint: 'https://public-host',
      username: 'admin',
      password: 'admin',
      ca_cert_path: "#{File.dirname(__FILE__)}/ca_cert.pem",
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

  describe 'Request with https uri schema (Resource Pool)' do
    before do
      # uri = URI.parse("https://private-host/#{resource_type}/#{key}")
      # stub_request(:head, uri).to_return(status: 200)
      stub_request(:post, 'https://private-host/app_stash/matches').with(
        body: '<key>', headers: {
           'Accept' => '*/*',
           'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
           'User-Agent' => 'Ruby',
           'X-Vcap-Request-Id' => ''
 }
           ).to_return(status: 200, body: '', headers: {})
    end

    it 'returns true' do
      resource_pool = BitsService::ResourcePool.new(
        endpoint: https_options[:private_endpoint],
        request_timeout_in_seconds: 100,
        vcap_request_id: '',
        ca_cert_path: https_options[:ca_cert_path],
        username: 'me',
        password: 'mypw',
      )
      expect(resource_pool.matches('<key>')).to be_truthy
    end
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
