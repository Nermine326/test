# frozen_string_literal: true

require 'rack/utils'

module Rack

    def initialize(app)
      @app = app
    end

    def call(env)
      case env[REQUEST_METHOD]
      when "GET", "HEAD"
        status, headers, body = @app.call(env)
        headers = Utils::HeaderHash.new(headers)
        if status == 200 && fresh?(env, headers)
          status = 304
          headers.delete(CONTENT_TYPE)
          headers.delete(CONTENT_LENGTH)
          original_body = body
          body = Rack::BodyProxy.new([]) do
            original_body.close if original_body.respond_to?(:close)
          end
        end
        [status, headers, body]
      else
        @app.call(env)
      end
    end

  private

    def fresh?(env, headers)
      modified_since = env['HTTP_IF_MODIFIED_SINCE']
      none_match     = env['HTTP_IF_NONE_MATCH']

      return false unless modified_since || none_match

      success = true
      success &&= modified_since?(to_rfc2822(modified_since), headers) if modified_since
      success &&= etag_matches?(none_match, headers) if none_match
      success
    end

    def etag_matches?(none_match, headers)
      etag = headers['ETag'] and etag == none_match
    end

    def modified_since?(modified_since, headers)
      last_modified = to_rfc2822(headers['Last-Modified']) and
        modified_since and
        modified_since >= last_modified
    end

    def to_rfc2822(since)
      # shortest possible valid date is the obsolete: 1 Nov 97 09:55 A
      # anything shorter is invalid, this avoids exceptions for common cases
      # most common being the empty string
      if since && since.length >= 16
        # NOTE: there is no trivial way to write this in a non exception way
        #   _rfc2822 returns a hash but is not that usable
        Time.rfc2822(since) rescue nil
      else
        nil
      end
    end
  end
end
