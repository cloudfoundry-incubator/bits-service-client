# frozen_string_literal: true
require_relative 'fake_bits_service'
require 'net/http'
require 'spec_helper'

describe BitsService::Client do
    let(:fake_server){}
    let(:fake_endpoint){'localhost'}
    let(:fake_endpoint_port){9292}

    let(:resource_type) { [:buildpacks, :droplets, :packages].sample }
    let(:key) { SecureRandom.uuid }
    let(:vcap_request_id) { '4711' }

    let(:options) do
        {
        enabled: true,
        private_endpoint: "http://#{fake_endpoint}:#{fake_endpoint_port}",
        public_endpoint: "http://#{fake_endpoint}:#{fake_endpoint_port}",
        username: 'admin',
        password: 'admin',
        }
    end

    subject(:client) { BitsService::Client.new(bits_service_options: options, resource_type: resource_type, vcap_request_id: vcap_request_id, request_timeout_in_seconds_fast: 3) }
    before do
        opts = {
            :Port => 9292,
            :Host => fake_endpoint
          }
        fakeServer = Thread.new do
            Rack::Handler::WEBrick.run(FakeBitsService, opts) do |server|
        #   server.log_file = "example.log"
            end
        end
        # WebMock.allow_net_connect!

        # sleep 300
        sleep 1
        request = Net::HTTP.new(fake_endpoint,fake_endpoint_port)
        response = request.get "/status"
        expect(response.code).to eq("200")

    end

    after do
        # puts fakeServer.class.name
    end

    context 'HTTP Blobstore requests with little or no payload' do
        it "returns early when delte times out" do
            request = Net::HTTP.new(fake_endpoint ,fake_endpoint_port)
            request.read_timeout = 2
            request.open_timeout = 2
            startTime = Time.now
            puts "Request Setup: #{request.read_timeout}"
            response = nil
            begin

                response = request.delete "/timeout"
            rescue => exception
                puts "Error: #{exception.inspect}"
            end
            endTime = Time.now
            puts("Duration for /timeout: #{startTime - endTime}")
            puts response.inspect

        end

    end
end


