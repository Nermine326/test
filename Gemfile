

source 'https://rubygems.org'

gemspec


c_platforms = Bundler::Dsl::VALID_PLATFORMS.dup.delete_if do |platform|
  platform =~ /jruby/
end

gem "rubocop", require: false

group :extra do
  gem 'fcgi', platforms: c_platforms
  gem 'memcache-client'
  gem 'thin', platforms: c_platforms
end

group :doc do
  gem 'rdoc'
end
