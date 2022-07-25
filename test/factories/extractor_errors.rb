FactoryBot.define do
  factory :extractor_error do
    extractor_response_id { 1 }
    error_type { "MyString" }
    report { "MyString" }
  end
end
