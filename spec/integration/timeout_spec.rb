# frozen_string_literal: true
require_relative 'fake_bits_service'
require "webrick"
require 'net/http'
require 'spec_helper'

describe BitsService::Client, :integration_test do
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

    subject(:client) { BitsService::Client.new(bits_service_options: options, resource_type: resource_type, vcap_request_id: vcap_request_id, request_timeout_in_seconds_fast: 1) }
    before do
        opts = {
            Port: fake_endpoint_port,
            Host: fake_endpoint,
            Logger: WEBrick::Log.new(File.open(File::NULL, 'w')), # disable WEBBrick echo to console
            AccessLog: [] # disable access log
          }
        fakeServer = Thread.new do
            Rack::Handler::WEBrick.run(FakeBitsService, opts) do |server|
            end
        end
        sleep 1
        request = Net::HTTP.new(fake_endpoint,fake_endpoint_port)
        response = request.get "/status"
        expect(response.code).to eq("200")

    end

    after do
    end

    context 'HTTP Blobstore requests with little or no payload' do
        it "returns early when delete times out" do
            startTime=Time.now
            expect{
                subject.delete(:key)
            }.to raise_error(Net::ReadTimeout)
            endTime=Time.now
            puts("Duration for /delete: #{startTime - endTime}")
            (startTime - endTime).should be < 3
        end

        it 'times out fast when exists? is called' do
            startTime=Time.now
            expect{
                subject.exists?(:key)
            }.to raise_error(Net::ReadTimeout)
            endTime=Time.now
            puts("Duration for /exists?: #{startTime - endTime}")
            (startTime - endTime).should be < 3
        end

        context "times out fast" do

            let(:resource_type) { :buildpack_cache }

            it 'when delete_all is called' do
                startTime=Time.now
                expect{
                    subject.delete_all
                }.to raise_error(Net::ReadTimeout)
                endTime=Time.now
                puts("Duration for /delete_all?: #{startTime - endTime}")
                (startTime - endTime).should be < 3
            end

            it 'when delete_all_in_path is called' do
                startTime=Time.now
                expect{
                    subject.delete_all_in_path(key)
                }.to raise_error(Net::ReadTimeout)
                endTime=Time.now
                puts("Duration for /delete_all_in_path?: #{startTime - endTime}")
                (startTime - endTime).should be < 3
            end
        end
    end
end


