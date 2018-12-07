# frozen_string_literal: true

require 'statsd'

module BitsService
  class LoggingHttpClient
    def initialize(http_client)
      @http_client = http_client
      @logger = Steno.logger('cc.bits_service_client')
      @statsd = Statsd.new
    end

    def get(path, vcap_request_id, credentials=nil)
      req = Net::HTTP::Get.new(path)
      if credentials
        req.basic_auth(credentials[:username], credentials[:password])
      end
      do_request(req, vcap_request_id)
    end

    def head(path, vcap_request_id)
      do_request(Net::HTTP::Head.new(path), vcap_request_id)
    end

    def put(path, body, vcap_request_id)
      do_request(Net::HTTP::Put::Multipart.new(path, body), vcap_request_id)
    end

    def delete(path, vcap_request_id)
      do_request(Net::HTTP::Delete.new(path), vcap_request_id)
    end

    def do_request(request, vcap_request_id)
      @logger.info('Request', {
        method: request.method,
        path: request.path,
        address: @http_client.address,
        port: @http_client.port,
        vcap_request_id: vcap_request_id,
      })

      request.add_field('X-VCAP-REQUEST-ID', vcap_request_id)

      begin
        response = @http_client.request(request)
        @logger.info('Response', { code: response.code, vcap_request_id: vcap_request_id })
      rescue Net::ReadTimeout => ex
        @statsd.increment("cc.bits_#{request.method.downcase}.timeout")

        @logger.info('Request timeout', {
          method: request.method,
          path: request.path,
          address: @http_client.address,
          port: @http_client.port,
          vcap_request_id: vcap_request_id,
        })
        raise ex
      end
      response
    end
  end
end
