# frozen_string_literal: true
require 'active_support/inflector'
require 'bits_service_client/logging_http_client'

module BitsService
  class Client
    ResourceTypeNotPresent = Class.new(StandardError)
    ConfigurationError = Class.new(StandardError)

    def initialize(bits_service_options:, resource_type:, vcap_request_id: '', request_timeout_in_seconds: 900)
      @username = validated(bits_service_options, :username)
      @password = validated(bits_service_options, :password)
      @private_endpoint = validated_http_url(bits_service_options, :private_endpoint)
      @public_endpoint = validated_http_url(bits_service_options, :public_endpoint)

      raise ResourceTypeNotPresent.new('Must specify resource type') unless resource_type
      @resource_type = resource_type
      @vcap_request_id = vcap_request_id

      @private_http_client = LoggingHttpClient.new(
        Net::HTTP.new(@private_endpoint.host, @private_endpoint.port).tap { |c| c.read_timeout = request_timeout_in_seconds })
      @public_http_client = LoggingHttpClient.new(
        Net::HTTP.new(@public_endpoint.host, @public_endpoint.port).tap { |c| c.read_timeout = request_timeout_in_seconds })
    end

    def local?
      false
    end

    def exists?(key)
      response = @private_http_client.head(resource_path(key), @vcap_request_id)
      validate_response_code!([200, 302, 404], response)

      response.code.to_i != 404
    end

    def cp_to_blobstore(source_path, destination_key)
      filename = File.basename(source_path)
      with_file_attachment!(source_path, filename) do |file_attachment|
        body = { :"#{@resource_type.to_s.singularize}" => file_attachment }
        response = @private_http_client.do_request(Net::HTTP::Put::Multipart.new(resource_path(destination_key), body), @vcap_request_id)
        validate_response_code!(201, response)
      end
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
      response = @private_http_client.delete(resource_path(key), @vcap_request_id)
      validate_response_code!([204, 404], response)

      if response.code.to_i == 404
        raise FileNotFound.new("Could not find object '#{key}', #{response.code}/#{response.body}")
      end
    end

    def blob(key)
      Blob.new(
        guid: key,
        public_download_url: signed_url(key),
        public_upload_url: signed_url(key, verb: 'put'),
        internal_download_url: generate_private_url(key)
      )
    end

    def signed_url(key, verb: nil)
      query = if verb.nil?
                ''
              else
                "?verb=#{verb}"
              end

      response = @private_http_client.get("/sign#{resource_path(key)}#{query}", @vcap_request_id, { username: @username, password: @password })
      validate_response_code!([200, 302], response)

      response.tap do |result|
        result.body = result['location'] if result.code.to_i == 302
      end

      response.body
    end

    def delete_blob(blob)
      delete(blob.guid)
    end

    def delete_all(_=nil)
      raise NotImplementedError unless :buildpack_cache == resource_type

      @private_http_client.delete(resource_path(''), @vcap_request_id).tap do |response|
        validate_response_code!(204, response)
      end
    end

    def delete_all_in_path(path)
      raise NotImplementedError unless :buildpack_cache == resource_type

      @private_http_client.delete(resource_path(path.to_s), @vcap_request_id).tap do |response|
        validate_response_code!(204, response)
      end
    end

    private

    attr_reader :resource_type

    def generate_private_url(guid)
      path = resource_path(guid)

      @private_http_client.head(path, @vcap_request_id).tap do |response|
        return response['location'] if response.code.to_i == 302
      end

      File.join(@private_endpoint.to_s, path)
    end

    def validate_response_code!(expected_codes, response)
      return if Array(expected_codes).include?(response.code.to_i)

      error = {
        response_code: response.code,
        response_body: response.body,
        response: response
      }.to_json

      logger.error("UnexpectedResponseCode: expected '#{expected_codes}' got #{error}")

      fail BlobstoreError.new(error)
    end

    def resource_path(guid)
      prefix = resource_type == :buildpack_cache ? 'buildpack_cache/entries/' : resource_type
      File.join('/', prefix.to_s, guid.to_s)
    end

    def with_file_attachment!(file_path, filename, &block)
      raise Errors::FileDoesNotExist.new("Could not find file: #{file_path}") unless File.exist?(file_path)

      File.open(file_path) do |file|
        attached_file = UploadIO.new(file, 'application/octet-stream', filename)
        yield attached_file
      end
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
