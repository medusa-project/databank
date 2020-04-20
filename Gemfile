# frozen_string_literal: true

source "https://rubygems.org"
ruby "2.5.2"

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem "rails", "~> 5.2", ">= 5.2.2"

# Use postgresql as the database for Active Record
gem "pg"
# Use SCSS for stylesheets
gem "sass-rails"
# Use Uglifier as compressor for JavaScript assets
gem "uglifier"
# Use CoffeeScript for .coffee assets and views
gem "coffee-rails"
# See https://github.com/rails/execjs#readme for more supported runtimes
# gem 'therubyracer', platforms: :ruby

# Use in-house storage gem to manage flexible storage on filesystems and s3 buckets
gem "medusa_storage", git: "https://github.com/medusa-project/medusa_storage.git", branch: "master"

# Use net-ldap to interact with campus active directory
gem 'net-ldap', '~> 0.16.2'

# Use aws-sdk to manage signed urls for downloads
gem "aws-sdk"

# Use browser to detect request browser
gem "browser"

# Use tus-server to support chunked uploads of large files
gem "tus-server"

# Use reCAPTCHA API to reduce spam in contact form
gem "recaptcha"

# Use jquery as the JavaScript library
gem "jquery-datatables-rails"
gem "jquery-rails"
gem "jquery-ui-rails"

# Use zeroclipboard-rails to copy text to clipboards
gem "zeroclipboard-rails"

# Use filemagic to detect file types
gem "ruby-filemagic"

# Use rubyzip to stream dynamically generated zip files
gem "rubyzip"
gem "zipline"

# Use seven_zip_ruby to handle 7zip archives
gem "seven_zip_ruby"

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
gem "activerecord-session_store", github: "rails/activerecord-session_store"

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

# Use highcharts and daru for interactive graphs
gem "daru", git: "https://github.com/SciRuby/daru.git"
gem "daru-data_tables", git: "https://github.com/Shekharrajak/daru-data_tables.git"
gem "daru-view", git: "https://github.com/sciruby/daru-view.git"
gem "google_visualr", git: "https://github.com/winston/google_visualr.git"
gem "highcharts-rails"
gem "nyaplot", git: "https://github.com/SciRuby/nyaplot.git"

# gem 'httpclient', git: 'git://github.com/medusa-project/httpclient.git'

gem "equivalent-xml"
gem "nokogiri"
gem "nokogiri-diff"

# use solr for searching
gem "progress_bar"
gem "sunspot_rails"
gem "sunspot_solr"

# use will_paginate for pagination of search results
gem "will_paginate"
gem "will_paginate-bootstrap"

# Use ActiveModel has_secure_password
gem "bcrypt"

# Use Passenger standalone
gem "passenger", require: "phusion_passenger/rack_handler"

# Use email validator for model
gem "valid_email"

# Use boostrap-datepicker-rails for selecting release date
# gem 'bootstrap-datepicker-rails'

# Use identity strategy to create local accounts for testing
gem "omniauth-identity"
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
gem 'amqp_helper', '~>0.2.0', git: 'git://github.com/medusa-project/amqp_helper.git'

# Used audited-activerecord for dataset changelog
gem "audited"

# Use google-analytics-rails to support Google Analytics
gem "google-analytics-rails"

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

group :development, :test do
  gem "byebug"
  gem "debase"
  gem "factory_bot_rails"
  gem "puma"
  gem "rb-readline"
  gem "ruby-debug-ide"
  gem "shoulda-matchers"
end

group :test do
  #gem 'cucumber', '~> 2.0'
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
  gem 'sunspot_test'
  gem 'connection_pool'
  #need my version of bunny-mock where the default exchange works as expected. Wait to see if the fix gets merged
  gem 'bunny-mock', git: 'git://github.com/hading/bunny-mock.git'
  gem 'rack_session_access'
end
