# frozen_string_literal: true

require 'util/signature_util'

module BitsService
  class Blob
    include BitsService::SignatureUtil

    attr_reader :key

    def initialize(key:, private_endpoint:, private_http_client:, vcap_request_id:, resource_type:, public_endpoint:, signing_key_secret:, signing_key_id:)
      @key = key
      @private_http_client = private_http_client
      @vcap_request_id = vcap_request_id
      @resource_type = resource_type
      @private_endpoint = private_endpoint
      @public_endpoint = public_endpoint
      @signing_key_secret = signing_key_secret
      @signing_key_id = signing_key_id
    end

    def attributes(*_)
      {}
    end

    def guid
      key
    end

    # TODO delete commented code when pipeline is green
    # def public_download_url
    #   signed_url = "#{@public_endpoint}#{self.sign_signature('GET', resource_path(key), @signing_key_secret, @signing_key_id)}"

    #   response = @private_http_client.get(signed_url, @vcap_request_id)
    #   validate_response_code!([200, 302, 404], response)

    #   if response.code.to_i == 302
    #     response['location']
    #   else
    #     signed_url
    #   end
    # end

    def public_download_url
      "#{@public_endpoint}#{self.sign_signature('GET', resource_path(key), @signing_key_secret, @signing_key_id)}"
    end

    def public_upload_url
      "#{@public_endpoint}#{self.sign_signature('PUT', resource_path(key), @signing_key_secret, @signing_key_id)}&async=true&verb=put"
    end

    def internal_download_url
      path = resource_path(key)

      @private_http_client.head(path, @vcap_request_id).tap do |response|
        return response['location'] if response.code.to_i == 302
      end

      File.join(@private_endpoint.to_s, path)
    end

    private

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
