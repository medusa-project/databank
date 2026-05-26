# frozen_string_literal: true

namespace :featured_researchers do
  desc "export researcher spotlights as migration bundle artifacts"
  task export_bundle: :environment do
    Rake::Task["migration:legacy:export_featured_researchers_bundle"].invoke
  end
end
