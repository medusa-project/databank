# frozen_string_literal: true

source "https://rubygems.org"
ruby '3.3.6'
gem 'rails', '~> 7.2.2'

# Use postgresql as the database for Active Record
gem "pg"
# Use SCSS for stylesheets
gem "sass-rails"
# Use terser as compressor for JavaScript assets
gem "terser"
# Use CoffeeScript for .coffee assets and views
#gem "coffee-rails"
# See https://github.com/rails/execjs#readme for more supported runtimes
# gem 'therubyracer', platforms: :ruby

# Use in-house storage gem to manage flexible storage on filesystems and s3 buckets
gem "medusa_storage", git: "https://github.com/medusa-project/medusa_storage.git", branch: "feature-1"

# Use aws-sdk to manage signed urls for downloads
gem "aws-sdk"

# Use browser to detect request browser
gem "browser"

# Use tus-server to support chunked uploads of large files
gem "tus-server"

# Use jquery as the JavaScript library
gem "jquery-datatables-rails"
gem "jquery-rails"
gem "jquery-ui-rails"

# Use clipboard-rails to access clipboard.js Javascript library
gem 'clipboard-rails', '~> 1.7', '>= 1.7.1'

# Use filemagic to detect file types
gem "ruby-filemagic"

# Use rubyzip to stream dynamically generated zip files
gem "rubyzip"
gem "zipline"

# Use minitar to deal with POSIX tar archive files
gem "minitar"

# Use rchardet to attempt to detect character encoding
gem "rchardet"

# User iconv to convert between encodings
gem "iconv"

# Use roda for routing magic
gem "roda"

# Turbolinks makes following links in your web application faster. Read more: https://github.com/rails/turbolinks
# gem 'turbolinks'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem "jbuilder"

# bundle exec rake doc:rails generates the API under doc/api.
gem "sdoc", group: :doc

# Use figaro to set environment variables
gem "figaro"

# Use bootstrap for layout framework
gem "autoprefixer-rails"
gem "bootstrap-sass"
gem "font-awesome-sass"

gem "haml"
gem "haml-rails"

gem "uuid"

gem "open_uri_redirections"

# Use ActiveRecord session store to support larger session
gem "activerecord-session_store"

# Use RMagick to connect with ImageMagick
# gem 'rmagick'

# Use cocoon to make it easier to handle nested forms
# gem 'cocoon'

# Use ranked-model to support ordering resources
# gem 'ranked-model'

gem "mime-types", require: "mime/types/full"

# Use redcarpet to render markdown
gem "redcarpet"

# Use 'rest-client' to interaction with file processor api
gem "rest-client"

# gem 'httpclient', git: 'git://github.com/medusa-project/httpclient.git'

gem "equivalent-xml"
gem "nokogiri", force_ruby_platform: true
gem "nokogiri-diff", force_ruby_platform: true

# use sunspot for searching
gem "progress_bar"
gem 'sunspot_rails'
gem "sunspot_solr"

# use will_paginate for pagination of search results
gem "will_paginate"
gem "will_paginate-bootstrap"

# Use ActiveModel has_secure_password
gem "bcrypt"

# Use Passenger standalone
gem "passenger"

# Use email validator for model
gem "valid_email"

# Use boostrap-datepicker-rails for selecting release date
# gem 'bootstrap-datepicker-rails'

# Use shibboleth strategy for omniauth -- NetID login
gem "omniauth-shibboleth"

gem "omniauth-rails_csrf_protection"

# Use Boxr to interact with Box API
gem "boxr"

# Use delayed_job during upload and ingest from box to avoid timeout failures
gem "daemons"
gem "delayed_job_active_record"
gem "progress_job"
# gem 'delayed_job_heartbeat_plugin'

# Use canan to restrict what resources a given user is allowed to access
gem "cancancan"

# User bunny to handle RabbitMQ messages
gem 'bunny'
gem 'amq-protocol'
gem 'amqp_helper', git: 'https://github.com/medusa-project/amqp_helper.git', branch: "master"

# Used audited-activerecord for dataset changelog
gem "audited"

# Use builder to support sitemaps generator
gem "builder"

# Use curb to wrap curl
gem "curb"

# Use modernizr-rails to handle different browsers differently
gem "modernizr-rails"

# use rubocop linter to support consisitent style
gem "rubocop", require: false
gem "rubocop-rails"
gem "rubocop-performance"

# Access an IRB console on exception pages or by using <%= console %> in views
# gem 'web-console', '~> 2.0'

gem "bootsnap", require: false

gem "simple_form"

# Use Capistrano for deployment
gem "capistrano-bundler"
gem "capistrano-passenger"
gem "capistrano-rails"
gem "capistrano-rbenv"
gem 'airbrussh'

group :development, :test do
  gem "byebug"
  gem "puma"
  gem "rb-readline"
  gem "shoulda-matchers"
  gem 'rspec-rails'
  gem 'factory_bot_rails'
  gem 'faker'
end

group :test do
  #gem 'cucumber', '~> 2.0'
  gem 'rubocop-rspec'
  gem 'rubocop-rspec_rails'
  gem 'rubocop-factory_bot'
  gem 'rubocop-capybara'
  gem 'rails-controller-testing'
  gem 'cucumber-rails', require: false
  gem 'database_cleaner'
  gem 'simplecov'
  gem 'json_spec'
  gem 'capybara'
  gem 'capybara-email'
  gem 'launchy'
  #testing with javascript - requires phantomjs to be installed on the test machine
  gem 'poltergeist'
  #other js testing options
  gem 'selenium-webdriver'
  gem 'connection_pool'
  gem 'bunny-mock'
  gem 'rack_session_access'
end
