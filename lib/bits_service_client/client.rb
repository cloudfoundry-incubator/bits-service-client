require 'active_support/inflector'

module BitsService
  class Client
    ResourceTypeNotPresent = Class.new(StandardError)
    ConfigurationError = Class.new(StandardError)

    def initialize(bits_service_options:, resource_type:, vcap_request_id: '')
      @username = validated(bits_service_options, :username)
      @password = validated(bits_service_options, :password)
      @private_endpoint = validated_http_url(bits_service_options, :private_endpoint)
      @public_endpoint = validated_http_url(bits_service_options, :public_endpoint)

      raise ResourceTypeNotPresent.new('Must specify resource type') unless resource_type
      @resource_type = resource_type
      @resource_type_singular = @resource_type.to_s.singularize
      @vcap_request_id = vcap_request_id
    end

    def local?
      false
    end

    def exists?(key)
      response = do_request(private_http_client, Net::HTTP::Head.new(resource_path(key)))
      validate_response_code!([200, 302, 404], response)

      response.code.to_i != 404
    end

    def cp_to_blobstore(source_path, destination_key)
      filename = File.basename(source_path)
      with_file_attachment!(source_path, filename) do |file_attachment|
        body = { :"#{resource_type_singular}" => file_attachment }
        response = put(resource_path(destination_key), body)
        validate_response_code!(201, response)
      end
    end

    def download_from_blobstore(source_key, destination_path, mode: nil)
      FileUtils.mkdir_p(File.dirname(destination_path))
      File.open(destination_path, 'wb') do |file|
        uri = URI(generate_url(private_http_client, source_key))
        response = Net::HTTP.get_response(uri)
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
      response = delete_request(resource_path(key))
      validate_response_code!([204, 404], response)

      if response.code.to_i == 404
        raise FileNotFound.new("Could not find object '#{key}', #{response.code}/#{response.body}")
      end
    end

    def blob(key)
      req = Net::HTTP::Get.new('/sign' + resource_path(key))
      req.basic_auth(@username, @password)

      response = do_request(private_http_client, req)
      validate_response_code!([200, 302], response)

      response.tap do |response|
        response.body = response['location'] if response.code.to_i == 302
      end

      Blob.new(
        guid: key,
        public_download_url: response.body,
        internal_download_url: generate_url(private_http_client, key)
      )
    end

    def delete_blob(blob)
      delete(blob.guid)
    end

    def delete_all(_=nil)
      raise NotImplementedError unless :buildpack_cache == resource_type

      delete_request(resource_path('')).tap do |response|
        validate_response_code!(204, response)
      end
    end

    def delete_all_in_path(path)
      raise NotImplementedError unless :buildpack_cache == resource_type

      delete_request(resource_path(path.to_s)).tap do |response|
        validate_response_code!(204, response)
      end
    end

    private

    attr_reader :resource_type, :resource_type_singular

    def generate_url(http_client, guid)
      path = resource_path(guid)

      do_request(http_client, Net::HTTP::Head.new(path)).tap do |response|
        return response['location'] if response.code.to_i == 302
      end

      File.join(endpoint(http_client).to_s, path)
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
      validate_file! file_path

      File.open(file_path) do |file|
        attached_file = UploadIO.new(file, 'application/octet-stream', filename)
        yield attached_file
      end
    end

    def validate_file!(file_path)
      return if File.exist?(file_path)

      raise Errors::FileDoesNotExist.new("Could not find file: #{file_path}")
    end

    def get(http_client, path)
      request = Net::HTTP::Get.new(path)
      do_request(http_client, request)
    end

    def post(path, body, header={})
      request = Net::HTTP::Post.new(path, header)

      request.body = body
      do_request(private_http_client, request)
    end

    def put(path, body, header={})
      request = Net::HTTP::Put::Multipart.new(path, body, header)
      do_request(private_http_client, request)
    end

    def delete_request(path)
      request = Net::HTTP::Delete.new(path)
      do_request(private_http_client, request)
    end

    def do_request(http_client, request)
      logger.info('Request', {
        method: request.method,
        path: request.path,
        address: http_client.address,
        port: http_client.port,
        vcap_request_id: @vcap_request_id,
      })

      request.add_field('X_VCAP_REQUEST_ID', @vcap_request_id)

      http_client.request(request).tap do |response|
        logger.info('Response', { code: response.code, vcap_request_id: @vcap_request_id })
      end
    end

    def private_http_client
      @private_http_client ||= Net::HTTP.new(@private_endpoint.host, @private_endpoint.port)
    end

    def public_http_client
      @public_http_client ||= Net::HTTP.new(@public_endpoint.host, @public_endpoint.port)
    end

    def endpoint(http_client)
      http_client == public_http_client ? @public_endpoint : @private_endpoint
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
