# frozen_string_literal: true

# represents a creator as defined in DataCite metadata schema
class Creator < ApplicationRecord
  include ActiveModel::Serialization
  belongs_to :dataset
  validate :name?
  after_create :add_internal_editor
  after_update :add_internal_editor
  before_destroy :remove_internal_editor

  audited except: %i[row_order
                     type_of
                     identifier_scheme
                     dataset_id
                     institution_name], associated_with: :dataset

  default_scope { order(:row_position) }

  def add_internal_editor
    return false unless at_illinois?

    netid = email.split("@").first
    editor_netids = dataset.internal_editor_netids || []
    return true if editor_netids.include?(netid)

    UserAbility.add_to_internal_editors(dataset: dataset, netid: netid)
  end

  def remove_internal_editor
    return false unless at_illinois?

    netid = email.split("@").first
    editor_netids = dataset.internal_editor_netids || []
    return true unless editor_netids.include?(netid)

    UserAbility.remove_from_internal_editors(dataset: dataset, netid: netid)
  end

  def as_json(*)
    if institution_name && institution_name != ""
      super(only: %i[institution_name
                     identifier
                     is_contact
                     row_position
                     created_at
                     updated_at])
    else
      super(only: %i[family_name
                     given_name
                     identifier
                     is_contact
                     row_position
                     created_at
                     updated_at])
    end
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

  def at_illinois?
    if type_of && type_of == Databank::CreatorType::PERSON && email && !email.empty?
      email_parts = email.split("@")
      email_parts.length > 1 && email_parts[1] == "illinois.edu"
    else
      false
    end
  end

  private

  # validation
  def name?
    has_institution_name = institution_name && institution_name != ""
    has_individual_name = given_name && given_name != "" && family_name && family_name != ""
    has_institution_name || has_individual_name
  end
end
