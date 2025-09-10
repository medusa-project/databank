# frozen_string_literal: true

class Guide::Item < ApplicationRecord
  belongs_to :guide_section, class_name: 'Guide::Section', optional: true
  has_many :guide_subitems, dependent: nil, class_name: 'Guide::Subitem'

  def has_children?
    Guide::Subitem.where(item_id: self.id).count.positive?
  end

  def has_public_children?
    Guide::Subitem.where(item_id: self.id).where(public: true).count.positive?
  end

  def ordered_children
    Guide::Subitem.where(item_id: self.id).order(:ordinal)
  end

  def parent
    Guide::Section.where(id: section_id).first if section_id && Guide::Section.where(id: section_id).count > 0
  end

end
