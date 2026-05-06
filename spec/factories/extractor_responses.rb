FactoryBot.define do
  factory :extractor_response do
    association :extractor_task
    web_id { "test-file-#{rand(10000)}" }
    status { "success" }
    peek_type { "text/plain" }
    peek_text { "Sample peek content" }
  end
end
