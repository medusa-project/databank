# config valid only for current version of Capistrano
lock '3.19.2'

set :application, 'databank'
set :repo_url, 'https://github.com/medusa-project/databank.git'

set :passenger_restart_with_touch, true

# Default branch is :master
# ask :branch, `git rev-parse --abbrev-ref HEAD`.chomp

# Default value for :scm is :git
# set :scm, :git

# Default value for :format is :pretty
# set :format, :pretty

# Default value for :log_level is :debug
# set :log_level, :debug

# Default value for :pty is false
# set :pty, true

# Default value for linked_dirs is []
set :linked_dirs, fetch(:linked_dirs, []).push('log', 'scripts', 'config/serializations', 'tmp/pids', 'tmp/cache', 'tmp/sockets', 'tmp/uploads', 'tmp/sessions')

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for keep_releases is 5
# set :keep_releases, 5


# Defaults to false
# Skip migration if files in db/migrate were not modified
set :conditionally_migrate, true

# Defaults to [:web]
set :assets_roles, [:web, :app]

# Defaults to 'assets'
# This should match config.assets.prefix in your rails config/application.rb

# Defaults to nil (no asset cleanup is performed)
# If you use Rails 4+ and you'd like to clean up old assets after each deploy,
# set this to the number of versions to keep
set :keep_assets, 2

namespace :sunspot do

  desc "Reindex sunspot indexes"
  task :reindex do
    execute_rake 'sunspot:reindex'
  end

end

namespace :databank do

  desc "Clear rails cache"
  task :clear_rails_cache do
    execute_rake "databank:rails_cache:clear"
  end

  def execute_rake(task)
    on roles(:app) do
      within release_path do
        with rails_env: fetch(:rails_env) do
          execute :rake, task
        end
      end
    end
  end
end