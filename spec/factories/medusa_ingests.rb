# spec/factories/medusa_ingests.rb
FactoryBot.define do
  factory :medusa_ingest do
    idb_class { "datafile" }
    idb_identifier { "some_identifier" }
    medusa_path { "some/path" }
    medusa_uuid { SecureRandom.uuid }
    request_status { "pending" }
    error_text { nil }
    response_time { Time.now }
  end
end