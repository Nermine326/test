# frozen_string_literal: true

require 'rack/utils'

module Rack

  #
 
  class ContentType
    include Rack::Utils

    def initialize(app, content_type = "text/html")
      @app, @content_type = app, content_type
    end

    def call(env)
      status, headers, body = @app.call(env)
      headers = Utils::HeaderHash.new(headers)

      unless STATUS_WITH_NO_ENTITY_BODY.key?(status.to_i)
        headers[CONTENT_TYPE] ||= @content_type
      end

      [status, headers, body]
    end
  end
end
