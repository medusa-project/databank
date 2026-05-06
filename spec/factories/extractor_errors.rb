FactoryBot.define do
  factory :extractor_error do
    transient do
      extractor_response { create(:extractor_response) }
    end
    extractor_response_id { extractor_response.id }
    error_type { "validation_error" }
    report { "Error details" }
  end
end
