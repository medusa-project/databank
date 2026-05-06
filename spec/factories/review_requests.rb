FactoryBot.define do
  factory :review_request do
    transient do
      dataset { create(:dataset) }
    end

    dataset_key { dataset.key }
    requested_at { Time.zone.now }
    modified { false }
  end
end
