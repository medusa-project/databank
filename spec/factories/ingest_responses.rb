FactoryBot.define do
  factory :ingest_response do
    as_text { '{"status":"ok"}' }
    status { 'ok' }
    response_time { Time.current }
    staging_key { 'draft/object.key' }
    medusa_key { 'medusa/object.key' }
    uuid { SecureRandom.uuid }
  end
end
