FactoryBot.define do
  factory :curator_report do
    requestor_name { "Test User" }
    requestor_email { "test@example.com" }
    report_type { "dataset_statistics" }
    storage_root { "MyString" }
    storage_key { "MyString" }
    notes { "MyString" }
  end
end
