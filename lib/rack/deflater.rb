# frozen_string_literal: true

require "zlib"
require "time"  # for Time.httpdate
require 'rack/utils'

module Rack

  class Deflater
 =
    def initialize(app, options = {})
      @app = app

      @condition = options[:if]
      @compressible_types = options[:include]
      @sync = options[:sync] == false ? false : true
    end

    def call(env)
      status, headers, body = @app.call(env)
      headers = Utils::HeaderHash.new(headers)

      unless should_deflate?(env, status, headers, body)
        return [status, headers, body]
      end

      request = Request.new(env)

      encoding = Utils.select_best_encoding(%w(gzip identity),
                                            request.accept_encoding)

      # Set the Vary HTTP header.
      vary = headers["Vary"].to_s.split(",").map(&:strip)
      unless vary.include?("*") || vary.include?("Accept-Encoding")
        headers["Vary"] = vary.push("Accept-Encoding").join(",")
      end

      case encoding
      when "gzip"
        headers['Content-Encoding'] = "gzip"
        headers.delete('Content-Length')
        mtime = headers["Last-Modified"]
        mtime = Time.httpdate(mtime).to_i if mtime
        [status, headers, GzipStream.new(body, mtime, @sync)]
      when "identity"
        [status, headers, body]
      when nil
        message = "An acceptable encoding for the requested resource #{request.fullpath} could not be found."
        bp = Rack::BodyProxy.new([message]) { body.close if body.respond_to?(:close) }
        [406, { 'Content-Type' => "text/plain", 'Content-Length' => message.length.to_s }, bp]
      end
    end

    class GzipStream
      def initialize(body, mtime, sync)
        @sync = sync
        @body = body
        @mtime = mtime
      end

      def each(&block)
        @writer = block
        gzip = ::Zlib::GzipWriter.new(self)
        gzip.mtime = @mtime if @mtime
        @body.each { |part|
          gzip.write(part)
          gzip.flush if @sync
        }
      ensure
        gzip.close
        @writer = nil
      end

      def write(data)
        @writer.call(data)
      end

      def close
        @body.close if @body.respond_to?(:close)
        @body = nil
      end
    end

    private

    def should_deflate?(env, status, headers, body)
      # Skip compressing empty entity body responses and responses with
      # no-transform set.
      if Utils::STATUS_WITH_NO_ENTITY_BODY.key?(status.to_i) ||
          headers['Cache-Control'].to_s =~ /\bno-transform\b/ ||
         (headers['Content-Encoding'] && headers['Content-Encoding'] !~ /\bidentity\b/)
        return false
      end

      # Skip if @compressible_types are given and does not include request's content type
      return false if @compressible_types && !(headers.has_key?('Content-Type') && @compressible_types.include?(headers['Content-Type'][/[^;]*/]))

      # Skip if @condition lambda is given and evaluates to false
      return false if @condition && !@condition.call(env, status, headers, body)

      true
    end
  end
end
