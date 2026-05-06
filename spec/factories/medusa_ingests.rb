# spec/factories/medusa_ingests.rb
FactoryBot.define do
  factory :medusa_ingest do
    idb_class { "datafile" }
    idb_identifier { "some_identifier" }
    staging_path { "staging/path" }
    staging_key { "draft/object.key" }
    target_key { "medusa/object.key" }
    medusa_dataset_dir { "dataset-dir" }
    medusa_path { "some/path" }
    medusa_uuid { SecureRandom.uuid }
    request_status { "pending" }
    error_text { nil }
    response_time { Time.current }
  end
end