FactoryBot.define do
  factory :extractor_response do
    extractor_task_id { 1 }
    web_id { "MyString" }
    status { "MyString" }
    peek_type { "MyString" }
    peek_text { "MyString" }
  end
end
