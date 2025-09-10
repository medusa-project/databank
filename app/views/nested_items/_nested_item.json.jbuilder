json.extract! nested_item, :id, :datafile_id, :parent_id, :item_name, :media_type, :size, :created_at, :updated_at
json.url nested_item_url(nested_item, format: :json)
