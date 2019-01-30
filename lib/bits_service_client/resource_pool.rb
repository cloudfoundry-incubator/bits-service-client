# frozen_string_literal: true

require 'util/signature_util'

module BitsService
  class ResourcePool
    include BitsService::SignatureUtil

    def initialize(bits_service_options:, request_timeout_in_seconds:, vcap_request_id: '')
      @private_endpoint = URI.parse(bits_service_options[:private_endpoint])
      @public_endpoint = URI.parse(bits_service_options[:public_endpoint])
      @request_timeout_in_seconds = request_timeout_in_seconds
      @signed_key_secret = validated(bits_service_options, :signing_key_secret)
      @signed_key_id = validated(bits_service_options, :signing_key_id)
      @vcap_request_id = vcap_request_id
      @logger = Steno.logger('cc.bits_service_client')
      @ca_cert_path = bits_service_options[:ca_cert_path]
    end

    def matches(resources_json)
      post('/app_stash/matches', resources_json, @vcap_request_id).tap do |response|
        validate_response_code!(200, response)
      end
    end

    def signed_matches_url
      "#{@public_endpoint}#{self.sign_signature('POST','/app_stash/matches', @signed_key_secret, @signed_key_id)}"
    end

    def bundles(resources_json, entries_path)
      if entries_path.to_s == ''
        post('/app_stash/bundles', resources_json, @vcap_request_id).tap do |response|
          validate_response_code!(200, response)
        end
      else
        validate_file! entries_path
        body = {
          resources: UploadIO.new(StringIO.new(resources_json), 'application/json', 'resources.json'),
          application: UploadIO.new(entries_path, 'application/octet-stream', 'entries.zip')
        }
        multipart_post('/app_stash/bundles', body, @vcap_request_id).tap do |response|
          validate_response_code!(200, response)
        end
      end
    end

    private

    attr_reader :private_endpoint

    def validate_response_code!(expected, response)
      return if expected.to_i == response.code.to_i

      error = {
        response_code: response.code,
        response_body: response.body,
        response: response
      }.to_json

      @logger.error("UnexpectedResponseCode: expected #{expected} got #{response.code}")

      fail Errors::UnexpectedResponseCode.new(error)
    end

    def validate_file!(file_path)
      return if File.exist?(file_path)

      raise Errors::FileDoesNotExist.new("Could not find file: #{file_path}")
    end

    def post(path, body, vcap_request_id)
      request = Net::HTTP::Post.new(path)

      request.body = body
      do_request(http_client, request, vcap_request_id)
    end

    def multipart_post(path, body, vcap_request_id)
      do_request(http_client, Net::HTTP::Post::Multipart.new(path, body), vcap_request_id)
    end

    def do_request(http_client, request, vcap_request_id)
      @logger.info('Request', {
        method: request.method,
        path: request.path,
        address: http_client.address,
        port: http_client.port,
        vcap_request_id: vcap_request_id
      })

      request.add_field('X-VCAP-REQUEST-ID', vcap_request_id)

      http_client.request(request).tap do |response|
        @logger.info('Response', {
          code: response.code,
          vcap_request_id: vcap_request_id
        })
      end
    end

    def http_client
      @http_client ||= Net::HTTP.new(private_endpoint.host, private_endpoint.port).tap do |c|
        c.read_timeout = @request_timeout_in_seconds
        enable_ssl(c, @ca_cert_path) if private_endpoint.scheme == 'https'
      end
    end

    def enable_ssl(http_client, ca_cert_path)
      cert_store = OpenSSL::X509::Store.new
      cert_store.set_default_paths
      cert_store.add_file ca_cert_path if ca_cert_path

      http_client.use_ssl = true
      http_client.verify_mode = OpenSSL::SSL::VERIFY_PEER
      http_client.cert_store = cert_store
    end

    def validated(bits_service_options, attribute)
      raise ConfigurationError.new("Please provide #{attribute}") unless bits_service_options[attribute]
      bits_service_options[attribute]
    end
  end
end
