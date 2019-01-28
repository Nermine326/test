
require 'rack/session/abstract/id'
require 'memcache'

module Rack
  module Session
   n of behaviour, please see memcache's documentation.

    class Memcache < Abstract::ID
      attr_reader :mutex, :pool

      DEFAULT_OPTIONS = Abstract::ID::DEFAULT_OPTIONS.merge \
        namespace: 'rack:session',
        memcache_server: 'localhost:11211'

      def initialize(app, options = {})
        super

        @mutex = Mutex.new
        mserv = @default_options[:memcache_server]
        mopts = @default_options.reject{|k, v| !MemCache::DEFAULT_OPTIONS.include? k }

        @pool = options[:cache] || MemCache.new(mserv, mopts)
        unless @pool.active? and @pool.servers.any?(&:alive?)
          raise 'No memcache servers'
        end
      end

      def generate_sid
        loop do
          sid = super
          break sid unless @pool.get(sid, true)
        end
      end

      def get_session(env, sid)
        with_lock(env) do
          unless sid and session = @pool.get(sid)
            sid, session = generate_sid, {}
            unless /^STORED/ =~ @pool.add(sid, session)
              raise "Session collision on '#{sid.inspect}'"
            end
          end
          [sid, session]
        end
      end

      def set_session(env, session_id, new_session, options)
        expiry = options[:expire_after]
        expiry = expiry.nil? ? 0 : expiry + 1

        with_lock(env) do
          @pool.set session_id, new_session, expiry
          session_id
        end
      end

      def destroy_session(env, session_id, options)
        with_lock(env) do
          @pool.delete(session_id)
          generate_sid unless options[:drop]
        end
      end

      def with_lock(env)
        @mutex.lock if env[RACK_MULTITHREAD]
        yield
      rescue MemCache::MemCacheError, Errno::ECONNREFUSED
        if $VERBOSE
          warn "#{self} is unable to find memcached server."
          warn $!.inspect
        end
        raise
      ensure
        @mutex.unlock if @mutex.locked?
      end

    end
  end
end
