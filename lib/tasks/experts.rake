require 'nokogiri'

namespace :experts do
  desc 'generate export doc'
  task :generate_doc => :environment do
    File.open(File.join(Rails.root, "public", "illinois_experts.xml"), 'w') do |f|
      f << Dataset.to_illinois_experts
    end
  end
end