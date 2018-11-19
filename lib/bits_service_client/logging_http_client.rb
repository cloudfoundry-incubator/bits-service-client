# frozen_string_literal: true
module BitsService
  class LoggingHttpClient
    def initialize(http_client)
      @http_client = http_client
      @logger = Steno.logger('cc.bits_service_client')
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

      @http_client.request(request).tap do |response|
        @logger.info('Response', { code: response.code, vcap_request_id: vcap_request_id })
      end
    end
    # TODO: make use of it
    def with_metric(metric, options={})
      try_update_status(options) do
        statsd.count("bits.client_#{metric}-count.sparse-avg") do
          yield
        end
      end
    end
  end
end
