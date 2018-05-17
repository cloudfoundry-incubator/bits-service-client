# frozen_string_literal: true
require 'spec_helper'
require 'securerandom'

module BitsService
  RSpec.describe ResourcePool do
    let(:endpoint) { 'http://bits-service.service.cf.internal/' }
    let(:request_timeout_in_seconds) { 42 }
    let(:vcap_request_id) { '4711' }

    let(:guid) { SecureRandom.uuid }

    subject { ResourcePool.new(
      endpoint: endpoint,
      request_timeout_in_seconds: request_timeout_in_seconds,
      vcap_request_id: vcap_request_id,
    )
    }

    describe 'forwards vcap-request-id' do
      let(:file_path) { Tempfile.new('buildpack').path }
      let(:file_name) { 'my-buildpack.zip' }

      it 'includes the header with a POST request' do
        request = stub_request(:post, File.join(endpoint, 'app_stash/matches')).
                  with(headers: { 'X-Vcap-Request_Id' => vcap_request_id }).
                  to_return(status: 200)

        subject.matches([].to_json)
        expect(request).to have_been_requested
      end
    end

    context 'Logging' do
      let!(:request) { stub_request(:post, File.join(endpoint, 'app_stash/matches')).to_return(status: 200) }

      it 'logs the request being made' do
        allow_any_instance_of(Steno::Logger).to receive(:info).with('Response', anything)

        expect_any_instance_of(Steno::Logger).to receive(:info).with('Request', {
          method: 'POST',
          path: '/app_stash/matches',
          address: 'bits-service.service.cf.internal',
          port: 80,
          vcap_request_id: vcap_request_id,
        })

        subject.matches([].to_json)
      end

      it 'logs the response being received' do
        allow_any_instance_of(Steno::Logger).to receive(:info).with('Request', anything)

        expect_any_instance_of(Steno::Logger).to receive(:info).with('Response', {
          code: '200',
          vcap_request_id: vcap_request_id,
        })

        subject.matches([].to_json)
      end
    end

    context 'AppStash' do
      describe '#matches' do
        let(:resources) do
          [{ 'sha1' => 'abcde' }, { 'sha1' => '12345' }]
        end

        it 'makes the correct request to the bits endpoint' do
          request = stub_request(:post, File.join(endpoint, 'app_stash/matches')).
                    with() { |request| request.body =~ /#{resources.to_json}/ }.
                    to_return(status: 200, body: [].to_json)

          subject.matches(resources.to_json)
          expect(request).to have_been_requested
        end

        it 'returns the request response' do
          stub_request(:post, File.join(endpoint, 'app_stash/matches')).
            with(body: resources.to_json).
            to_return(status: 200, body: [].to_json)

          response = subject.matches(resources.to_json)
          expect(response).to be_a(Net::HTTPOK)
        end

        it 'raises an error when the response is not 200' do
          stub_request(:post, File.join(endpoint, 'app_stash/matches')).
            to_return(status: 400, body: '{"description":"bits-failure"}')

          expect {
            subject.matches(resources.to_json)
          }.to raise_error(BitsService::Errors::Error, /bits-failure/)
        end
      end

      describe '#bundles' do
        let(:zip) { Tempfile.new('entry.zip') }
        let(:order) {
          [{ 'fn' => 'app.rb', 'sha1' => '12345' }]
        }

        let(:content_bits) { 'tons of bits as ordered' }

        it 'makes the correct request to the bits service' do
          request = stub_request(:post, File.join(endpoint, 'app_stash/bundles')).
            with() { |request|
              request.body =~ /.*application".*/ &&
              request.body =~ /.*resources".*/ &&
              request.body =~ /.*#{order.to_json}.*/
            }.to_return(status: 200)

          response = subject.bundles(order.to_json, zip)
          expect(request).to have_been_requested
          expect(response).to be_a(Net::HTTPOK)
        end

        it 'raises an error when the response is not 200' do
          stub_request(:post, File.join(endpoint, 'app_stash/bundles')).
            with() { |request|
              request.body =~ /.*application".*/ &&
              request.body =~ /.*resources".*/ &&
              request.body =~ /.*#{order.to_json}.*/
            }.to_return(status: 400, body: '{"description":"bits-failure"}')

          expect {
            subject.bundles(order.to_json, zip)
          }.to raise_error(BitsService::Errors::Error, /bits-failure/)
        end
      end
    end
  end
end
