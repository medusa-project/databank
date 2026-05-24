# frozen_string_literal: true

namespace :guides do
  desc "export guides"
  task export: :environment do
    Guide::Section.export
  end

  desc "export guides as migration bundle artifacts"
  task export_bundle: :environment do
    Rake::Task["migration:legacy:export_guides_bundle"].invoke
  end

  task import: :environment do
    Guide::Section.import
  end
end
