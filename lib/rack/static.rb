# frozen_string_literal: true

require "rack/file"
require "rack/utils"

module Rack

  #
  class Static

    def initialize(app, options = {})
      @app = app
      @urls = options[:urls] || ["/favicon.ico"]
      @index = options[:index]
      @gzip = options[:gzip]
      root = options[:root] || Dir.pwd

      # HTTP Headers
      @header_rules = options[:header_rules] || []
      # Allow for legacy :cache_control option while prioritizing global header_rules setting
      @header_rules.unshift([:all, { CACHE_CONTROL => options[:cache_control] }]) if options[:cache_control]

      @file_server = Rack::File.new(root)
    end

    def add_index_root?(path)
      @index && route_file(path) && path =~ /\/$/
    end

    def overwrite_file_path(path)
      @urls.kind_of?(Hash) && @urls.key?(path) || add_index_root?(path)
    end

    def route_file(path)
      @urls.kind_of?(Array) && @urls.any? { |url| path.index(url) == 0 }
    end

    def can_serve(path)
      route_file(path) || overwrite_file_path(path)
    end

    def call(env)
      path = env[PATH_INFO]

      if can_serve(path)
        if overwrite_file_path(path)
          env[PATH_INFO] = (add_index_root?(path) ? path + @index : @urls[path])
        elsif @gzip && env['HTTP_ACCEPT_ENCODING'] =~ /\bgzip\b/
          path = env[PATH_INFO]
          env[PATH_INFO] += '.gz'
          response = @file_server.call(env)
          env[PATH_INFO] = path

          if response[0] == 404
            response = nil
          else
            if mime_type = Mime.mime_type(::File.extname(path), 'text/plain')
              response[1][CONTENT_TYPE] = mime_type
            end
            response[1]['Content-Encoding'] = 'gzip'
          end
        end

        path = env[PATH_INFO]
        response ||= @file_server.call(env)

        headers = response[1]
        applicable_rules(path).each do |rule, new_headers|
          new_headers.each { |field, content| headers[field] = content }
        end

        response
      else
        @app.call(env)
      end
    end

    # Convert HTTP header rules to HTTP headers
    def applicable_rules(path)
      @header_rules.find_all do |rule, new_headers|
        case rule
        when :all
          true
        when :fonts
          path =~ /\.(?:ttf|otf|eot|woff2|woff|svg)\z/
        when String
          path = ::Rack::Utils.unescape(path)
          path.start_with?(rule) || path.start_with?('/' + rule)
        when Array
          path =~ /\.(#{rule.join('|')})\z/
        when Regexp
          path =~ rule
        else
          false
        end
      end
    end

  end
end
