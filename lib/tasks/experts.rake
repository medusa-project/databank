require 'nokogiri'

namespace :experts do
  desc 'generate export doc'
  task :generate_doc => :environment do
    File.open(File.join(Rails.root, "public", "illinois_experts.xml"), 'w') do |f|
      f << Dataset.to_illinois_experts
    end
  end

  desc 'fetch demo export doc'
  task :fetch_demo_doc => :environment do
    demo_doc = Nokogiri::XML(open("https://demo.databank.illinois.edu/illinois_experts.xml"))
    File.open(File.join(Rails.root, "public", "illinois_experts_demo.xml"), 'w') do |f|
      f << demo_doc.to_xml
    end
  end

  desc 'explore persons'
  task :explore_persons => :environment do
    doc = IllinoisExpertsClient.person_xml_doc("netid@illinois.edu")

    start_date = doc.xpath("//period/startDate")
    puts "start_date: #{start_date}"

    org_uuids = doc.xpath("//organisationalUnit/@uuid")
    if org_uuids.empty?
      puts "org_uuids was empty"
    else
      org_uuids.each do |org_uuid|
        puts "org_uuid_class: #{org_uuid.class.name}"
        puts "org_uuid:"
        puts org_uuid.content
      end
    end
  end
end