# frozen_string_literal: true

module BitsService
  class ResourcePool
    def initialize(endpoint:, request_timeout_in_seconds:, vcap_request_id: '', ca_cert_path: nil)
      @endpoint = URI.parse(endpoint)
      @request_timeout_in_seconds = request_timeout_in_seconds
      @vcap_request_id = vcap_request_id
      @logger = Steno.logger('cc.bits_service_client')
      @ca_cert_path = ca_cert_path
    end

    def matches(resources_json)
      post('/app_stash/matches', resources_json, @vcap_request_id).tap do |response|
        validate_response_code!(200, response)
      end
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

    attr_reader :endpoint

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
      @http_client ||= Net::HTTP.new(endpoint.host, endpoint.port).tap do |c|
        c.read_timeout = @request_timeout_in_seconds
        enable_ssl(c, @ca_cert_path) if endpoint.scheme == 'https'
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
  end
end
