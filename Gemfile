source 'https://rubygems.org'

# FRAMEWORK
gem 'rails', '4.0.3'
gem 'configoro'
gem 'redis-rails'
gem 'rack-cache', require: 'rack/cache'
gem 'boolean'

# AUTHENTICATION
gem 'devise'

# MODELS
gem 'pg'
gem 'stringex', '2.2.0' # 2.5.2 forces config.enforce_available_locales to true for some stupid reason
gem 'slugalicious'
gem 'validates_timeliness'
gem 'has_metadata_column'
gem 'find_or_create_on_scopes'
gem 'composite_primary_keys', github: 'RISCfuture/composite_primary_keys', branch: 'rebase'
gem 'rails-observers'
gem 'tire'

# VIEWS
gem 'jquery-rails'
gem 'font-awesome-rails'
gem 'twitter-typeahead-rails', '0.9.3' # 0.10.2 breaks locale key filtering
gem 'dropzonejs-rails'
gem 'kaminari'
gem 'slim-rails'

# UTILITIES
gem 'json'
gem 'git', github: 'RISCfuture/ruby-git', ref: '14d05318c3c22352564dfb3acf45ee1a29a09864' # Fixes mirror issue
gem 'coffee-script'
gem 'unicode_scanner'
gem 'httparty'
gem 'similar_text', '~> 0.0.4'
gem 'paperclip'
gem 'aws-sdk'

# IMPORTING
gem 'therubyracer', platform: :mri, require: 'v8'
gem 'nokogiri'
gem 'CFPropertyList', require: 'cfpropertylist'
gem 'parslet'
gem 'mustache'
gem 'html_validation'

# EXPORTING
gem 'libarchive'

# WORD SUBSTITUTION
gem 'uea-stemmer'

# PSEUDO TRANSLATION
gem 'faker'

# BACKGROUND JOBS
gem 'sidekiq', '<3.0.0'
gem 'sidekiq-failures'
gem 'sinatra', require: nil
gem 'whenever', require: nil

# REDIS
gem 'redis-mutex'
gem 'redis-namespace'

# ASSETS
gem 'sprockets-rails'
gem 'sass-rails', '4.0.3' # bugfix for sass 3.3 (in)compatibility
gem 'coffee-rails'
gem 'uglifier'
gem 'less-rails'
gem 'hogan_assets'

group :development do
  gem 'redcarpet', require: nil
  gem 'yard', require: nil, platform: :mri
end

group :test do
  gem 'rspec-rails'
  gem 'factory_girl_rails'
  gem 'timecop'
  gem 'pry'
  gem 'pry-nav'
  gem 'test_after_commit'
end

group :acceptance do
  gem 'capybara'
  gem 'capybara-webkit'
end


gem 'sql_origin', groups: [:development, :test]

# Doesn't work in Rails 4
group :development, :test do
  gem 'spring'
  gem 'spring-commands-rspec'
  gem 'mailcatcher'
  #gem 'jasminerice'
  #gem 'guard-jasmine'
end

# Deploying
gem 'capistrano', '~> 3.2.1'
gem 'capistrano-rails', '~> 1.1'
