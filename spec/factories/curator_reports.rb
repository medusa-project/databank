FactoryBot.define do
  factory :curator_report do
    requestor_name { "MyString" }
    requestor_email { "MyString" }
    report_type { "MyString" }
    storage_root { "MyString" }
    storage_key { "MyString" }
    notes { "MyString" }
  end
end
