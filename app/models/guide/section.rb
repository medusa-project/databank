# frozen_string_literal: true
require 'json'

class Guide::Section < ApplicationRecord
  has_many :guide_items, dependent: nil, class_name: 'Guide::Item'

  def self.anchors_in_use
    section_anchors = Guide::Section.all.pluck(:anchor)
    item_anchors = Guide::Item.all.pluck(:anchor)
    subitem_anchors = Guide::Subitem.all.pluck(:anchor)
    (section_anchors + item_anchors + subitem_anchors).sort
  end

  def has_children?
    Guide::Item.where(section_id: self.id).count.positive?
  end

  def has_public_children?
    Guide::Item.where(section_id: self.id).where(public: true).count.positive?
  end

  def ordered_children
    Guide::Item.where(section_id: self.id).order(:ordinal)
  end

  def parent
    nil
  end

  def self.transfer_path
    "/tmp/guide_transfer.txt"
  end

  def self.export
    File.open(Guide::Section.transfer_path,'w') do |f|
      Guide::Section.all.find_each do |section|
        h = section.serializable_hash
        f << {section.class.name => h}.to_json
        f << "\n"
        section.ordered_children.find_each do |item|
          h = item.serializable_hash
          f << {item.class.name => h}.to_json
          f << "\n"
          item.ordered_children.find_each do |subitem|
            h = subitem.serializable_hash
            f << {subitem.class.name => h}.to_json
            f << "\n"
          end
        end
      end
    end
  end

  def self.import
    File.open(Guide::Section.transfer_path).each_line do |line|

      parsed_line = JSON.parse(line)
      klass = parsed_line.keys[0]
      g = parsed_line[klass]
      case klass
      when "Guide::Section"
        Guide::Section.find_or_create_by(id:      g["id"],
                                         anchor:  g["anchor"],
                                         label:   g["label"],
                                         ordinal: g["ordinal"],
                                         public:  g["public"],
                                         heading: g["heading"],
                                         body:    g["body"])
      when "Guide::Item"
        Guide::Item.find_or_create_by(id:         g["id"],
                                      section_id: g["section_id"],
                                      anchor:     g["anchor"],
                                      label:      g["label"],
                                      ordinal:    g["ordinal"],
                                      public:     g["public"],
                                      heading:    g["heading"],
                                      body:       g["body"])
      when "Guide::Subitem"
        Guide::Subitem.find_or_create_by(id:      g["id"],
                                         item_id: g["item_id"],
                                         anchor:  g["anchor"],
                                         label:   g["label"],
                                         ordinal: g["ordinal"],
                                         public:  g["public"],
                                         heading: g["heading"],
                                         body:    g["body"])
      end
    end
  end

end
