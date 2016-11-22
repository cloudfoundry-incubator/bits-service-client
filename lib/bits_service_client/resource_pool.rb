# frozen_string_literal: true
module BitsService
  class ResourcePool
    def initialize(endpoint:, request_timeout_in_seconds:, vcap_request_id: '')
      @endpoint = URI.parse(endpoint)
      @request_timeout_in_seconds = request_timeout_in_seconds
      @vcap_request_id = vcap_request_id
      @logger = Steno.logger('cc.bits_service_client')
    end

    def matches(resources_json)
      post('/app_stash/matches', resources_json, @vcap_request_id).tap do |response|
        validate_response_code!(200, response)
      end
    end

    def upload_entries(entries_path)
      with_file_attachment!(entries_path, 'entries.zip') do |file_attachment|
        body = { application: file_attachment }
        multipart_post('/app_stash/entries', body, @vcap_request_id)
      end
    end

    def bundles(resources_json)
      post('/app_stash/bundles', resources_json, @vcap_request_id).tap do |response|
        validate_response_code!(200, response)
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

      @logger.error("UnexpectedResponseCode: expected #{expected} got #{error}")

      fail Errors::UnexpectedResponseCode.new(error)
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

    def post(path, body, vcap_request_id)
      request = Net::HTTP::Post.new(path)

      request.body = body
      do_request(http_client, request, vcap_request_id)
    end

    def multipart_post(path, body, vcap_request_id)
      request = Net::HTTP::Post::Multipart.new(path, body)
      do_request(http_client, request, vcap_request_id).tap do |response|
        validate_response_code!(201, response)
      end
    end

    def do_request(http_client, request, vcap_request_id)
      @logger.info('Request', {
        method: request.method,
        path: request.path,
        address: http_client.address,
        port: http_client.port,
        vcap_request_id: vcap_request_id,
      })

      request.add_field('X_VCAP_REQUEST_ID', vcap_request_id)

      http_client.request(request).tap do |response|
        @logger.info('Response', {
          code: response.code,
          vcap_request_id: vcap_request_id,
        })
      end
    end

    def http_client
      @http_client ||= Net::HTTP.new(endpoint.host, endpoint.port).tap { |c| c.read_timeout = @request_timeout_in_seconds }
    end
  end
end
