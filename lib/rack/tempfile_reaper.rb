# frozen_string_literal: true

require 'rack/body_proxy'

module Rack

  class TempfileReaper
    def initialize(app)
      @app = app
    end

    def call(env)
      env[RACK_TEMPFILES] ||= []
      status, headers, body = @app.call(env)
      body_proxy = BodyProxy.new(body) do
        env[RACK_TEMPFILES].each(&:close!) unless env[RACK_TEMPFILES].nil?
      end
      [status, headers, body_proxy]
    end
  end
end
