# frozen_string_literal: true

namespace :metrics do
  desc "generate metric.rb docs"
  task generate_docs: :environment do
    Metric.refresh_all
  end
end
