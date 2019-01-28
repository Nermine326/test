# frozen_string_literal: true

require 'rack/file'
require 'rack/body_proxy'

module Rack

  

  class Sendfile
    def initialize(app, variation = nil, mappings = [])
      @app = app
      @variation = variation
      @mappings = mappings.map do |internal, external|
        [/^#{internal}/i, external]
      end
    end

    def call(env)
      status, headers, body = @app.call(env)
      if body.respond_to?(:to_path)
        case type = variation(env)
        when 'X-Accel-Redirect'
          path = ::File.expand_path(body.to_path)
          if url = map_accel_path(env, path)
            headers[CONTENT_LENGTH] = '0'
            headers[type] = url
            obody = body
            body = Rack::BodyProxy.new([]) do
              obody.close if obody.respond_to?(:close)
            end
          else
            env[RACK_ERRORS].puts "X-Accel-Mapping header missing"
          end
        when 'X-Sendfile', 'X-Lighttpd-Send-File'
          path = ::File.expand_path(body.to_path)
          headers[CONTENT_LENGTH] = '0'
          headers[type] = path
          obody = body
          body = Rack::BodyProxy.new([]) do
            obody.close if obody.respond_to?(:close)
          end
        when '', nil
        else
          env[RACK_ERRORS].puts "Unknown x-sendfile variation: '#{type}'.\n"
        end
      end
      [status, headers, body]
    end

    private
    def variation(env)
      @variation ||
        env['sendfile.type'] ||
        env['HTTP_X_SENDFILE_TYPE']
    end

    def map_accel_path(env, path)
      if mapping = @mappings.find { |internal, _| internal =~ path }
        path.sub(*mapping)
      elsif mapping = env['HTTP_X_ACCEL_MAPPING']
        mapping.split(',').map(&:strip).each do |m|
          internal, external = m.split('=', 2).map(&:strip)
          new_path = path.sub(/^#{internal}/i, external)
          return new_path unless path == new_path
        end
        path
      end
    end
  end
end
