FactoryBot.define do
  factory :datafile do
    storage_root { StorageManager.instance.draft_root.name }
    sequence(:binary_name) {|n| "key#{n}.txt" }
    sequence(:storage_key) {|n| "key#{n}.txt" }
    sequence(:web_id) {|n| "web_id#{n}" }
  end
end