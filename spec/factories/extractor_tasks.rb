FactoryBot.define do
  factory :extractor_task do
    web_id { "test-file-#{rand(10000)}" }
    response_at { Time.current }
    raw_response { '{"status": "success"}' }
  end
end
