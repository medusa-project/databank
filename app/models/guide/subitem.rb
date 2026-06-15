# frozen_string_literal: true

class Guide::Subitem < ApplicationRecord
  belongs_to :guide_item, class_name: 'Guide::Item', foreign_key: :item_id, optional: true

  def parent
    Guide::Item.where(id: item_id).first if item_id && Guide::Item.where(id: item_id).count > 0
  end
end
