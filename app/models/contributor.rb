# frozen_string_literal: true

# represents a contributor as defined in DataCite metadata schema
class Contributor < ApplicationRecord
  include ActiveModel::Serialization
  belongs_to :dataset
  audited except:          %i[row_order
                              type_of
                              identifier_scheme
                              dataset_id
                              institution_name],
          associated_with: :dataset

  default_scope { order(:row_position) }

  def as_json(*)
    super(only: %i[family_name
                   given_name
                   identifier
                   row_position
                   created_at
                   updated_at])
  end

  def display_name
    if type_of == Databank::CreatorType::INSTITUTION
      institution_name.to_s
    else
      "#{given_name || ''} #{family_name || ''}"
    end
  end

  # text for the name when used in a list
  def list_name
    if type_of == Databank::CreatorType::INSTITUTION
      institution_name.to_s
    else
      "#{family_name || ''}, #{given_name || ''}"
    end
  end
end
