# frozen_string_literal: true

require 'rack/body_proxy'

module Rack

  class CommonLogger
   
   
    FORMAT = %{%s - %s [%s] "%s %s%s %s" %d %s %0.4f\n}

    def initialize(app, logger = nil)
      @app = app
      @logger = logger
    end

    def call(env)
      began_at = Utils.clock_time
      status, header, body = @app.call(env)
      header = Utils::HeaderHash.new(header)
      body = BodyProxy.new(body) { log(env, status, header, began_at) }
      [status, header, body]
    end

    private

    def log(env, status, header, began_at)
      length = extract_content_length(header)

      msg = FORMAT % [
        env['HTTP_X_FORWARDED_FOR'] || env["REMOTE_ADDR"] || "-",
        env["REMOTE_USER"] || "-",
        Time.now.strftime("%d/%b/%Y:%H:%M:%S %z"),
        env[REQUEST_METHOD],
        env[PATH_INFO],
        env[QUERY_STRING].empty? ? "" : "?#{env[QUERY_STRING]}",
        env[HTTP_VERSION],
        status.to_s[0..3],
        length,
        Utils.clock_time - began_at ]

      logger = @logger || env[RACK_ERRORS]
      # Standard library logger doesn't support write but it supports << which actually
      # calls to write on the log device without formatting
      if logger.respond_to?(:write)
        logger.write(msg)
      else
        logger << msg
      end
    end

    def extract_content_length(headers)
      value = headers[CONTENT_LENGTH] or return '-'
      value.to_s == '0' ? '-' : value
    end
  end
end
