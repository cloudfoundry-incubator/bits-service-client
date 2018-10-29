# frozen_string_literal: true
module BitsService
  class Blob
    attr_reader :key

    def initialize(key:, private_endpoint:, private_http_client:, vcap_request_id:, username:, password:, resource_type:)
      @key = key
      @private_http_client = private_http_client
      @vcap_request_id = vcap_request_id
      @username = username
      @password =password
      @resource_type = resource_type
      @private_endpoint = private_endpoint
    end

    def attributes(*_)
      {}
    end

    def guid
      key
    end

    def public_download_url
      signed_url(key)
    end

    def public_upload_url
      signed_url(key, verb: 'put')+'&async=true'
    end

    def internal_download_url
      generate_private_url(key)
    end

    private

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

    def generate_private_url(key)
      path = resource_path(key)

      @private_http_client.head(path, @vcap_request_id).tap do |response|
        return response['location'] if response.code.to_i == 302
      end

      File.join(@private_endpoint.to_s, path)
    end

    # TODO: Refactor the following code to avoid duplicate methods with BitsService::Client

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

    def resource_path(key)
      prefix = @resource_type == :buildpack_cache ? 'buildpack_cache/entries/' : @resource_type
      File.join('/', prefix.to_s, key.to_s)
    end

    def logger
      @logger ||= Steno.logger('cc.bits_service_client')
    end
  end
end
