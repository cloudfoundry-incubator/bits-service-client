# frozen_string_literal: true

require 'spec_helper'
require 'ostruct'
require 'securerandom'

RSpec.describe BitsService::Client, unit: true do
  let(:resource_type) { %i[buildpacks droplets packages].sample }
  let(:resource_type_singular) { resource_type.to_s.singularize }
  let(:key) { SecureRandom.uuid }
  let(:private_resource_endpoint) { File.join(options[:private_endpoint], resource_type.to_s, key) }
  let(:public_resource_endpoint) { File.join(options[:public_endpoint], resource_type.to_s, key) }
  let(:vcap_request_id) { '4711' }

  let(:file_path) do
    Tempfile.new('blob').tap do |file|
      file.write(SecureRandom.uuid)
      file.close
    end.path
  end

  let(:options) do
    {
      enabled: true,
      private_endpoint: 'http://private-host',
      public_endpoint: 'http://public-host',
      username: 'admin',
      password: 'admin',
    }
  end

  subject(:client) { BitsService::Client.new(bits_service_options: options, resource_type: resource_type, vcap_request_id: vcap_request_id, request_timeout_in_seconds_fast: 1) }

  describe 'username missing' do
    before { options.delete(:username) }

    it 'raises an error' do
      expect { subject }.to raise_error BitsService::Client::ConfigurationError
    end
  end

  describe 'password missing' do
    before { options.delete(:password) }

    it 'raises an error' do
      expect { subject }.to raise_error BitsService::Client::ConfigurationError
    end
  end

  shared_examples_for 'empty endpoint' do
    it 'raises an error' do
      expect { subject }.to raise_error BitsService::Client::ConfigurationError
    end
  end

  shared_examples_for 'invalid endpoint' do
    it 'raises an error' do
      expect { subject }.to raise_error BitsService::Client::ConfigurationError
    end
  end

  describe 'private endpoint is missing' do
    before { options.delete(:private_endpoint) }
    it_behaves_like 'empty endpoint'
  end

  describe 'private endpoint is not a valid http URL' do
    before { options[:private_endpoint] = 'somescheme:invalid_url' }
    it_behaves_like 'invalid endpoint'
  end

  describe 'public endpoint is missing' do
    before { options.delete(:public_endpoint) }
    it_behaves_like 'empty endpoint'
  end

  describe 'public endpoint is not a valid http URL' do
    before { options[:public_endpoint] = 'somescheme:invalid_url' }
    it_behaves_like 'invalid endpoint'
  end

  describe '#local?' do
    it 'is not local' do
      expect(client.local?).to be_falsey
    end
  end

  describe '#exists?' do
    context 'when the resource exists' do
      before do
        stub_request(:head, "http://private-host/#{resource_type}/#{key}").to_return(status: 200)
      end

      it 'returns true' do
        expect(subject.exists?(key)).to be_truthy
      end
    end

    context 'when the resource does not exist' do
      before do
        stub_request(:head, "http://private-host/#{resource_type}/#{key}").to_return(status: 404)
      end

      it 'returns false' do
        expect(subject.exists?(key)).to be_falsey
      end
    end

    context 'when the response code is invalid' do
      before do
        stub_request(:head, "http://private-host/#{resource_type}/#{key}").to_return(status: 500)
      end

      it 'raises a BlobstoreError' do
        expect { subject.exists?(key) }.to raise_error(BitsService::BlobstoreError)
      end
    end
  end

  describe '#cp_to_blobstore' do
    it 'makes the correct request to the bits-service' do
      upload_request = stub_request(:put, private_resource_endpoint).
                       with { |request| request.body =~ /name="#{resource_type.to_s.singularize}"/ }.
                       to_return(status: 201, body: '{"sha1":"abc", "sha256":"def"}')

      subject.cp_to_blobstore(file_path, key)
      expect(upload_request).to have_been_requested
    end

    context 'when the response code is not 201' do
      it 'raises a BlobstoreError' do
        stub_request(:put, private_resource_endpoint).to_return(status: 500)

        expect { subject.cp_to_blobstore(file_path, key) }.to raise_error(BitsService::BlobstoreError)
      end
    end

    context 'response body is empty' do
      it 'raises a BlobstoreError' do
        stub_request(:put, private_resource_endpoint).to_return(status: 201)

        expect { subject.cp_to_blobstore(file_path, key) }.to raise_error(BitsService::BlobstoreError)
      end
    end

    context 'shas are not present in json response body' do
      it 'raises a BlobstoreError' do
        stub_request(:put, private_resource_endpoint).to_return(status: 201, body: '{}')

        expect { subject.cp_to_blobstore(file_path, key) }.to raise_error(BitsService::BlobstoreError)
      end
    end

    context 'resources are passed' do
      it 'adds them to the multi part upload request' do
        stub_request(:put, private_resource_endpoint).
          with { |request|
          request.body =~ /name="#{resource_type.to_s.singularize}"/ &&
          request.body =~ /name="resources"/ &&
          request.body =~ /{"fn":"filename","sha":"abc","size":123}/
        }.
          to_return(status: 201, body: '{"sha1":"abc", "sha256":"def"}')

        shas = subject.cp_to_blobstore(file_path, key, resources: { fn: 'filename', sha: 'abc', size: 123 })

        expect(shas).to eq({ sha1: 'abc', sha256: 'def' })
      end
    end

    context 'source_path is nil' do
      it 'uses an empty zip' do
        stub_request(:put, private_resource_endpoint).
          with { |request|
          request.body =~ /name="#{resource_type.to_s.singularize}"/ &&
          request.body =~ /name="resources"/ &&
          request.body =~ /\r\n\r\nPK/ && # PK is the magic number a zip file begins with
          request.body =~ /{"fn":"filename","sha":"abc","size":123}/
        }.
          to_return(status: 201, body: '{"sha1":"abc", "sha256":"def"}')

        subject.cp_to_blobstore(nil, key, resources: { fn: 'filename', sha: 'abc', size: 123 })
      end
    end

    context 'source_path is empty' do
      it 'uses an empty zip' do
        stub_request(:put, private_resource_endpoint).
          with { |request|
          request.body =~ /name="#{resource_type.to_s.singularize}"/ &&
          request.body =~ /name="resources"/ &&
          request.body =~ /\r\n\r\nPK/ && # PK is the magic number a zip file begins with
          request.body =~ /{"fn":"filename","sha":"abc","size":123}/
        }.
          to_return(status: 201, body: '{"sha1":"abc", "sha256":"def"}')

        subject.cp_to_blobstore('', key, resources: { fn: 'filename', sha: 'abc', size: 123 })
      end
    end
  end

  describe '#download_from_blobstore' do
    let(:destination_path) { "#{Dir.mktmpdir}/destination" }

    before do
      stub_request(:head, private_resource_endpoint).
        to_return(status: 200)
      stub_request(:get, private_resource_endpoint).
        to_return(status: 200, body: File.new(file_path))
    end

    it 'downloads the blob to the destination path' do
      expect {
        subject.download_from_blobstore(key, destination_path)
      }.to change { File.exist?(destination_path) }.from(false).to(true)
    end

    context 'when mode is defined' do
      it 'sets the file to the given mode' do
        subject.download_from_blobstore(key, destination_path, mode: 0o753)
        expect(sprintf('%o', File.stat(destination_path).mode)).to eq('100753')
      end
    end

    context 'when the response code is not 200' do
      it 'raises a BlobstoreError' do
        stub_request(:get, private_resource_endpoint).
          to_return(status: 500, body: File.new(file_path))

        expect {
          subject.download_from_blobstore(key, destination_path)
        }.to raise_error(BitsService::BlobstoreError)
      end
    end
  end

  context 'copying blobs between keys' do
    let(:destination_key) { SecureRandom.uuid }

    it 'downloads the blob before uploading it again with the new key' do
      download_request = stub_request(:get, private_resource_endpoint).
                         to_return(status: 200, body: File.new(file_path))
      upload_request = stub_request(:put, File.join(options[:private_endpoint], resource_type.to_s, destination_key)).
                       with { |request| request.body =~ /name="#{resource_type.to_s.singularize}";.*\r\n.*\r\n.*\r\n.*\r\n\r\n#{File.new(file_path).read}/ }.
                       to_return(status: 201, body: '{"sha1":"abc", "sha256":"def"}')

      subject.cp_file_between_keys(key, destination_key)
      expect(download_request).to have_been_requested
      expect(upload_request).to have_been_requested
    end

    it 'follows a redirect before attempting to download the blob' do
      stub_request(:get, private_resource_endpoint).
        to_return(status: 302, headers: { location: 'http://somewhere.example.com' })
      stub_request(:get, 'http://somewhere.example.com').
        to_return(status: 200, body: File.new(file_path))
      stub_request(:put, File.join(options[:private_endpoint], resource_type.to_s, destination_key)).
        with { |request| request.body =~ /name="#{resource_type.to_s.singularize}";.*\r\n.*\r\n.*\r\n.*\r\n\r\n#{File.new(file_path).read}/ }.
        to_return(status: 201, body: '{"sha1":"abc", "sha256":"def"}')

      subject.cp_file_between_keys(key, destination_key)
    end
  end

  describe '#delete' do
    it 'makes the correct request to the bits-service' do
      request = stub_request(:delete, private_resource_endpoint).
                to_return(status: 204)

      subject.delete(key)
      expect(request).to have_been_requested
    end

    context 'when the response code is 404' do
      it 'raises a NotFound error' do
        stub_request(:delete, private_resource_endpoint).to_return(status: 404)

        expect {
          subject.delete(key)
        }.to raise_error(BitsService::FileNotFound)
      end
    end

    context 'when the response code is not 204' do
      it 'raises a BlobstoreError' do
        stub_request(:delete, private_resource_endpoint).to_return(status: 500)

        expect {
          subject.delete(key)
        }.to raise_error(BitsService::BlobstoreError)
      end
    end
  end

  describe '#blob' do
    before do
      stub_request(:head, "http://private-host/#{resource_type}/#{key}").to_return(status: 200)
      stub_request(:get, "http://private-host/sign/#{resource_type}/#{key}").
        with(basic_auth: ['admin', 'admin']).
        to_return(status: 200, body: "http://public-host/#{resource_type}/#{key}?signature=x")
      stub_request(:get, "http://private-host/sign/#{resource_type}/#{key}?verb=put").
        with(basic_auth: ['admin', 'admin']).
        to_return(status: 200, body: "http://public-host/#{resource_type}/#{key}?verb=put&signature=y")
    end

    it 'returns a blob object with the given guid' do
      expect(subject.blob(key).guid).to eq(key)
    end

    it 'returns a blob object with public download_url' do
      expect(subject.blob(key).public_download_url).to eq("http://public-host/#{resource_type}/#{key}?signature=x")
    end

    it 'returns a blob object with public upload_url' do
      expect(subject.blob(key).public_upload_url).to eq("http://public-host/#{resource_type}/#{key}?verb=put&signature=y&async=true")
    end

    it 'returns a blob object with internal download_url' do
      expect(subject.blob(key).internal_download_url).to eq("http://private-host/#{resource_type}/#{key}")
    end

    context "when the download url's result is a redirect" do
      it 'uses redirected url as the internal_download_url' do
        stub_request(:head, "http://private-host/#{resource_type}/#{key}").to_return(status: 302, headers: { location: 'some-redirect-1' })
        expect(subject.blob(key).internal_download_url).to eq('some-redirect-1')
      end

      it 'used the redirected url as public_download_url' do
        stub_request(:get, "http://private-host/sign/#{resource_type}/#{key}").
          with(basic_auth: ['admin', 'admin']).
          to_return(status: 302, headers: { location: 'some-redirect-2' })
        expect(subject.blob(key).public_download_url).to eq('some-redirect-2')
      end
    end
  end

  describe '#delete_blob' do
    before do
      stub_request(:head, private_resource_endpoint).to_return(status: 200)
      stub_request(:head, public_resource_endpoint).to_return(status: 200)
      stub_request(:get, "http://admin:admin@private-host/sign/#{resource_type}/#{key}").
        to_return(status: 200)
    end

    it 'sends the right request to the bits-service' do
      request = stub_request(:delete, private_resource_endpoint).to_return(status: 204)
      subject.delete_blob(OpenStruct.new(guid: key))
      expect(request).to have_been_requested
    end

    context 'when the response is not 204' do
      it 'raises a BlobstoreError' do
        stub_request(:delete, private_resource_endpoint).to_return(status: 500)

        expect {
          subject.delete_blob(OpenStruct.new(guid: key))
        }.to raise_error(BitsService::BlobstoreError)
      end
    end
  end

  describe '#delete_all' do
    it 'raises NotImplementedError' do
      expect {
        subject.delete_all
      }.to raise_error(NotImplementedError)
    end

    context 'when it is a buildpack_cache resource' do
      let(:resource_type) { :buildpack_cache }

      it 'sends the correct request to the bits-service' do
        request = stub_request(:delete, File.join(options[:private_endpoint], 'buildpack_cache/entries/')).to_return(status: 204)

        subject.delete_all
        expect(request).to have_been_requested
      end

      context 'when the response is not 204' do
        it 'raises a BlobstoreError' do
          stub_request(:delete, File.join(options[:private_endpoint], 'buildpack_cache/entries/')).to_return(status: 500)

          expect {
            subject.delete_all
          }.to raise_error(BitsService::BlobstoreError)
        end
      end
    end
  end

  describe '#delete_all_in_path' do
    it 'raises NotImplementedError' do
      expect {
        subject.delete_all_in_path('some-path')
      }.to raise_error(NotImplementedError)
    end

    context 'when it is a buildpack_cache resource' do
      let(:resource_type) { :buildpack_cache }

      it 'sends the correct request to the bits-service' do
        request = stub_request(:delete, File.join(options[:private_endpoint], 'buildpack_cache/entries', key)).to_return(status: 204)

        subject.delete_all_in_path(key)
        expect(request).to have_been_requested
      end

      context 'when the response is not 204' do
        it 'raises a BlobstoreError' do
          stub_request(:delete, File.join(options[:private_endpoint], 'buildpack_cache/entries', key)).to_return(status: 500)

          expect {
            subject.delete_all_in_path(key)
          }.to raise_error(BitsService::BlobstoreError)
        end
      end
    end
  end

  describe 'forwards vcap-request-id' do
    it 'includes the header with a PUT request' do
      upload_request = stub_request(:put, private_resource_endpoint).
                       with { |request| request.boyd =~ /name="#{resource_type.to_s.singularize}"/ }.
                       with(headers: { 'X-VCAP-REQUEST-ID' => vcap_request_id }).
                       to_return(status: 201, body: '{"sha1":"abc", "sha256":"def"}')

      subject.cp_to_blobstore(file_path, key)
      expect(upload_request).to have_been_requested
    end
  end

  context 'Logging' do
    # TODO: (pego): we should re-evaluate if we really want to test for logging statements. It's considered an anti-test pattern.
    it 'logs the request being made' do
      allow_any_instance_of(Steno::Logger).to receive(:info).with('Using bits-service client with root ca certs only (no configured ca_cert_path).')
      allow_any_instance_of(Steno::Logger).to receive(:info).with('Response', anything)

      expect_any_instance_of(Steno::Logger).to receive(:info).with('Request', {
        method: 'PUT',
        path: ['/' + resource_type.to_s, key].join('/'),
        address: 'private-host',
        port: 80,
        vcap_request_id: vcap_request_id,
      })

      request = stub_request(:put, private_resource_endpoint).to_return(status: 201, body: '{"sha1":"abc", "sha256":"def"}')

      subject.cp_to_blobstore(file_path, key)
      expect(request).to have_been_requested
    end

    it 'logs the response being received' do
      allow_any_instance_of(Steno::Logger).to receive(:info).with('Using bits-service client with root ca certs only (no configured ca_cert_path).')
      allow_any_instance_of(Steno::Logger).to receive(:info).with('Request', anything)
      expect_any_instance_of(Steno::Logger).to receive(:info).with('Response', {
        code: '201',
        vcap_request_id: vcap_request_id,
      })

      request = stub_request(:put, private_resource_endpoint).to_return(status: 201, body: '{"sha1":"abc", "sha256":"def"}')

      subject.cp_to_blobstore(file_path, key)
      expect(request).to have_been_requested
    end
  end
  context 'Logging' do
    # TODO: (pego): we should re-evaluate if we really want to test for logging statements. It's considered an anti-test pattern.
    it 'logs the request being made' do
      allow_any_instance_of(Steno::Logger).to receive(:info).with('Using bits-service client with root ca certs only (no configured ca_cert_path).')
      allow_any_instance_of(Steno::Logger).to receive(:info).with('Response', anything)

      expect_any_instance_of(Steno::Logger).to receive(:info).with('Request', {
        method: 'PUT',
        path: ['/' + resource_type.to_s, key].join('/'),
        address: 'private-host',
        port: 80,
        vcap_request_id: vcap_request_id,
      })

      request = stub_request(:put, private_resource_endpoint).to_return(status: 201, body: '{"sha1":"abc", "sha256":"def"}')

      subject.cp_to_blobstore(file_path, key)
      expect(request).to have_been_requested
    end
  end
end
