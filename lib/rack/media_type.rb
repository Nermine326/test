# frozen_string_literal: true

module Rack
  # Rack::MediaType parse media type and parameters out of content_type string

  class MediaType
    SPLIT_PATTERN = %r{\s*[;,]\s*}

    class << self
     
      def type(content_type)
        return nil unless content_type
        content_type.split(SPLIT_PATTERN, 2).first.downcase
      end

    
      def params(content_type)
        return {} if content_type.nil?
        Hash[*content_type.split(SPLIT_PATTERN)[1..-1].
          collect { |s| s.split('=', 2) }.
          map { |k, v| [k.downcase, strip_doublequotes(v)] }.flatten]
      end

      private

        def strip_doublequotes(str)
          (str[0] == ?" && str[-1] == ?") ? str[1..-2] : str
        end
    end
  end
end
