# frozen_string_literal: true

namespace :guides do
  desc "export guides"
  task export: :environment do
    Guide::Section.export
  end
  task import: :environment do
    Guide::Section.import
  end
end
