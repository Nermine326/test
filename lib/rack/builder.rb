# frozen_string_literal: true

module Rack
 
    UTF_8_BOM = '\xef\xbb\xbf'

    def self.parse_file(config, opts = Server::Options.new)
      if config =~ /\.ru$/
        return self.load_file(config, opts)
      else
        require config
        app = Object.const_get(::File.basename(config, '.rb').split('_').map(&:capitalize).join(''))
        return app, {}
      end
    end

    def self.load_file(path, opts = Server::Options.new)
      options = {}

      cfgfile = ::File.read(path)
      cfgfile.slice!(/\A#{UTF_8_BOM}/) if cfgfile.encoding == Encoding::UTF_8

      if cfgfile[/^#\\(.*)/] && opts
        options = opts.parse! $1.split(/\s+/)
      end

      cfgfile.sub!(/^__END__\n.*\Z/m, '')
      app = new_from_string cfgfile, path

      return app, options
    end

    def self.new_from_string(builder_script, file = "(rackup)")
      eval "Rack::Builder.new {\n" + builder_script + "\n}.to_app",
        TOPLEVEL_BINDING, file, 0
    end

    def initialize(default_app = nil, &block)
      @use, @map, @run, @warmup, @freeze_app = [], nil, default_app, nil, false
      instance_eval(&block) if block_given?
    end

    def self.app(default_app = nil, &block)
      self.new(default_app, &block).to_app
    end

    
    # referenced in the application if required.
    def use(middleware, *args, &block)
      if @map
        mapping, @map = @map, nil
        @use << proc { |app| generate_map app, mapping }
      end
      @use << proc { |app| middleware.new(app, *args, &block) }
    end

    def run(app)
      @run = app
    end

   
    def warmup(prc = nil, &block)
      @warmup = prc || block
    end

    
    #
    def map(path, &block)
      @map ||= {}
      @map[path] = block
    end

    # Freeze the app (set using run) and all middleware instances when building the application
    # in to_app.
    def freeze_app
      @freeze_app = true
    end

    def to_app
      app = @map ? generate_map(@run, @map) : @run
      fail "missing run or map statement" unless app
      app.freeze if @freeze_app
      app = @use.reverse.inject(app) { |a, e| e[a].tap { |x| x.freeze if @freeze_app } }
      @warmup.call(app) if @warmup
      app
    end

    def call(env)
      to_app.call(env)
    end

    private

    def generate_map(default_app, mapping)
      mapped = default_app ? { '/' => default_app } : {}
      mapping.each { |r, b| mapped[r] = self.class.new(default_app, &b).to_app }
      URLMap.new(mapped)
    end
  end
end
