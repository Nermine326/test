# frozen_string_literal: true

require 'rack/response'
require 'rack/body_proxy'

module Rack
 

  class Events
    module Abstract
      def on_start req, res
      end

      def on_commit req, res
      end

      def on_send req, res
      end

      def on_finish req, res
      end

      def on_error req, res, e
      end
    end

    class EventedBodyProxy < Rack::BodyProxy # :nodoc:
      attr_reader :request, :response

      def initialize body, request, response, handlers, &block
        super(body, &block)
        @request  = request
        @response = response
        @handlers = handlers
      end

      def each
        @handlers.reverse_each { |handler| handler.on_send request, response }
        super
      end
    end

    class BufferedResponse < Rack::Response::Raw # :nodoc:
      attr_reader :body

      def initialize status, headers, body
        super(status, headers)
        @body = body
      end

      def to_a; [status, headers, body]; end
    end

    def initialize app, handlers
      @app      = app
      @handlers = handlers
    end

    def call env
      request = make_request env
      on_start request, nil

      begin
        status, headers, body = @app.call request.env
        response = make_response status, headers, body
        on_commit request, response
      rescue StandardError => e
        on_error request, response, e
        on_finish request, response
        raise
      end

      body = EventedBodyProxy.new(body, request, response, @handlers) do
        on_finish request, response
      end
      [response.status, response.headers, body]
    end

    private

    def on_error request, response, e
      @handlers.reverse_each { |handler| handler.on_error request, response, e }
    end

    def on_commit request, response
      @handlers.reverse_each { |handler| handler.on_commit request, response }
    end

    def on_start request, response
      @handlers.each { |handler| handler.on_start request, nil }
    end

    def on_finish request, response
      @handlers.reverse_each { |handler| handler.on_finish request, response }
    end

    def make_request env
      Rack::Request.new env
    end

    def make_response status, headers, body
      BufferedResponse.new status, headers, body
    end
  end
end
