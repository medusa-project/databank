FactoryBot.define do
  factory :nested_item do
    association :datafile
    parent_id { nil }
    item_name { 'nested-file.txt' }
    media_type { 'text/plain' }
    size { 128 }
    item_path { 'folder/nested-file.txt' }
    is_directory { false }
  end
end
