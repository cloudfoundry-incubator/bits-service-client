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

    def public_download_url
      signed_url(key)
    end

    def public_upload_url
      signed_url(key, verb: 'put') + '&async=true'
    end

    def internal_download_url
      generate_private_url(key)
    end

    private

    def signed_url(key, verb: nil)
      query = if verb.nil?
        ''
      else
        "&verb=#{verb}"
      end

      signed_url = "#{@public_endpoint}#{self.sign_signature(resource_path(key), @signing_key_secret, @signing_key_id)}#{query}"
      logger.debug( "Created signed URL: #{signed_url}")
      return signed_url
    end

    def generate_private_url(key)
      path = resource_path(key)

      @private_http_client.head(path, @vcap_request_id).tap do |response|
        return response['location'] if response.code.to_i == 302
      end

      File.join(@private_endpoint.to_s, path)
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
