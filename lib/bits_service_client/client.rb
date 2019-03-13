# frozen_string_literal: true

require 'active_support/inflector'
require 'bits_service_client/logging_http_client'
require 'tmpdir'
require 'open3'

module BitsService
  class Client
    ResourceTypeNotPresent = Class.new(StandardError)
    ConfigurationError = Class.new(StandardError)

    def initialize(bits_service_options:, resource_type:, vcap_request_id: '', request_timeout_in_seconds: 900, request_timeout_in_seconds_fast: 10)
      @username = validated(bits_service_options, :username)
      @password = validated(bits_service_options, :password)
      @private_endpoint = validated_http_url(bits_service_options, :private_endpoint)
      @public_endpoint = validated_http_url(bits_service_options, :public_endpoint)
      @signing_key_secret = validated(bits_service_options, :signing_key_secret)
      @signing_key_id = validated(bits_service_options, :signing_key_id)

      raise ResourceTypeNotPresent.new('Must specify resource type') unless resource_type
      @resource_type = resource_type
      @vcap_request_id = vcap_request_id

      @private_http_client = create_logging_http_client(@private_endpoint, bits_service_options, request_timeout_in_seconds)
      @private_http_client_fast_timeout = create_logging_http_client(@private_endpoint, bits_service_options, request_timeout_in_seconds_fast)
      @public_http_client = create_logging_http_client(@public_endpoint, bits_service_options, request_timeout_in_seconds)
    end

    def local?
      false
    end

    def exists?(key)
      response = @private_http_client_fast_timeout.head(resource_path(key), @vcap_request_id)
      validate_response_code!([200, 302, 404], response)

      response.code.to_i != 404
    end

    def cp_to_blobstore(source_path, destination_key, resources: nil)
      if source_path.to_s.empty?
        file = Tempfile.new(['empty', '.zip'])
        source_path = file.path
        file.close!
        Dir.mktmpdir do |dir|
          output, error, status = Open3.capture3(%(/usr/bin/zip #{source_path} #{dir}))
          unless status.success?
            logger.error("Could not create a zip with no contents.\n STDOUT: \"#{output}\"\n STDERR: \"#{error}\"")
            raise Errors::Error.new('Could not create a zip with no contents')
          end
        end
      end

      body = { :"#{@resource_type.to_s.singularize}" => UploadIO.new(source_path, 'application/octet-stream') }

      if !resources.nil?
        body[:resources] = resources.to_json
      end

      response = @private_http_client.do_request(Net::HTTP::Put::Multipart.new(resource_path(destination_key), body), @vcap_request_id)
      validate_response_code!(201, response)
      if response.body.nil?
        logger.error('UnexpectedMissingBody: expected body with json payload. Got empty body.')

        fail BlobstoreError.new({
          response_code: response.code,
          response_body: response.body,
          response: response
        }.to_json)
      end
      shas = JSON.parse(response.body, symbolize_names: true)
      validate_keys_present!(%i[sha1 sha256], shas, response)
      shas
    end

    def download_from_blobstore(source_key, destination_path, mode: nil)
      FileUtils.mkdir_p(File.dirname(destination_path))
      File.open(destination_path, 'wb') do |file|
        response = @private_http_client.get(resource_path(source_key), @vcap_request_id)

        if response.code == '302'
          response = Net::HTTP.get_response(URI(response['location']))
        end

        validate_response_code!(200, response)
        file.write(response.body)
        file.chmod(mode) if mode
      end
    end

    def cp_file_between_keys(source_key, destination_key)
      temp_downloaded_file = Tempfile.new('foo')
      download_from_blobstore(source_key, temp_downloaded_file.path)
      cp_to_blobstore(temp_downloaded_file.path, destination_key)
    end

    def delete(key)
      response = @private_http_client_fast_timeout.delete(resource_path(key), @vcap_request_id)
      validate_response_code!([204, 404], response)
      if response.code.to_i == 404
        raise FileNotFound.new("Could not find object '#{key}', #{response.code}/#{response.body}")
      end
    end

    def blob(key)
      Blob.new(
        key: key,
        private_http_client: @private_http_client,
        private_endpoint: @private_endpoint,
        vcap_request_id: @vcap_request_id,
        resource_type: @resource_type,
        public_endpoint: @public_endpoint,
        signing_key_secret: @signing_key_secret,
        signing_key_id: @signing_key_id,
      )
    end

    def get_buildpack_metadata(source_key)
      response = @private_http_client.get(File.join(resource_path(source_key), 'metadata'), @vcap_request_id)
      validate_response_code!(200, response)
      JSON.parse(response.body, symbolize_names: true)
    end

    def delete_blob(blob)
      delete(blob.guid)
    end

    def delete_all(_=nil)
      raise NotImplementedError unless resource_type == :buildpack_cache

      @private_http_client.delete(resource_path(''), @vcap_request_id).tap do |response|
        validate_response_code!(204, response)
      end
    end

    def delete_all_in_path(path)
      raise NotImplementedError unless resource_type == :buildpack_cache

      @private_http_client.delete(resource_path(path.to_s), @vcap_request_id).tap do |response|
        validate_response_code!(204, response)
      end
    end

    def public_upload_url(resource_type, http_method)
      "#{@public_endpoint}#{self.sign_signature(http_method.upcase, "/#{resource_type}", @signing_key_secret, @signing_key_id)}&async=true&verb=#{http_method.downcase}"
    end

    private

    attr_reader :resource_type

    def create_logging_http_client(endpoint, bits_service_options, request_timeout_in_seconds)
      LoggingHttpClient.new(
        Net::HTTP.new(endpoint.host, endpoint.port).tap do |c|
          c.read_timeout = request_timeout_in_seconds
          if bits_service_options.key?(:ca_cert_path)
            ca_cert_path = bits_service_options[:ca_cert_path]
          else
            logger.info('Using bits-service client with root ca certs only (no configured ca_cert_path).')
            ca_cert_path = nil
          end
          enable_ssl(c, ca_cert_path) if endpoint.scheme == 'https'
        end
      )
    end

    def enable_ssl(http_client, ca_cert_path)
      cert_store = OpenSSL::X509::Store.new
      cert_store.set_default_paths
      cert_store.add_file ca_cert_path if ca_cert_path

      http_client.use_ssl = true
      http_client.verify_mode = OpenSSL::SSL::VERIFY_PEER
      http_client.cert_store = cert_store
    end

    def validate_response_code!(expected_codes, response)
      return if Array(expected_codes).include?(response.code.to_i)

      error = {
        response_code: response.code,
        response_body: response.body,
        response: response
      }.to_json

      logger.error("UnexpectedResponseCode: expected '#{expected_codes}' got #{response.code}")

      fail BlobstoreError.new(error)
    end

    def validate_keys_present!(expected_keys, map, response)
      return if expected_keys.all? { |expected_key| map.keys.include?(expected_key) }

      logger.error("UnexpectedResponseBody: expected json with keys '#{expected_keys}'. Got #{map}")

      fail BlobstoreError.new({
        response_code: response.code,
        response_body: response.body,
        response: response
      }.to_json)
    end

    def resource_path(guid)
      prefix = resource_type == :buildpack_cache ? 'buildpack_cache/entries/' : resource_type
      File.join('/', prefix.to_s, guid.to_s)
    end

    def endpoint(http_client)
      http_client == @public_http_client ? @public_endpoint : @private_endpoint
    end

    def logger
      @logger ||= Steno.logger('cc.bits_service_client')
    end

    def validated_http_url(bits_service_options, attribute)
      URI.parse(validated(bits_service_options, attribute)).tap do |uri|
        raise ConfigurationError.new("Please provide valid http(s) #{attribute}") unless uri.scheme&.match /https?/
      end
    end

    def validated(bits_service_options, attribute)
      raise ConfigurationError.new("Please provide #{attribute}") unless bits_service_options[attribute]
      bits_service_options[attribute]
    end
  end
end
