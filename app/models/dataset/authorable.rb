# frozen_string_literal: true

##
# This module supports managing dataset authors.
# Deals with creators and contributors, although contributors are not currently used.
# It is included in the Dataset model.

module Dataset::Authorable
  extend ActiveSupport::Concern
  ##
  # Add each creator as an editor -- the add_editor method is responsible for ensuring avoiding duplication
  def ensure_creator_editors
    return true unless creators.count.positive?

    creators.each(&:add_editor)
  end

  ##
  # Invalid name
  # This method returns whether the name is invalid, used for creators and contributors
  # @param [Hash] attributes the attributes of the name
  # @return [Boolean] true if the family name, given name, and institution name are blank
  # Otherwise, it returns false
  def invalid_name(attributes)
    attributes["family_name"].blank? &&
      attributes["given_name"].blank? &&
      attributes["institution_name"].blank?
  end


  ##
  # Sets the primary contact for the dataset
  # @note it sets the corresponding_creator_name and corresponding_creator_email
  # based on the creator that is the primary contact
  def set_primary_contact
    self.corresponding_creator_name = nil
    self.corresponding_creator_email = nil

    creators.each do |creator|
      next unless creator.is_contact?

      if creator.type_of == Databank::CreatorType::PERSON
        self.corresponding_creator_name = "#{creator.given_name} #{creator.family_name}"

      elsif creator.type_of == Databank::CreatorType::INSTITUTION
        self.corresponding_creator_name = creator.institution_name
      end
      self.corresponding_creator_email = creator.email
    end
  end


  ##
  # @return [ActiveRecord::Relation] all creators of this dataset that are individuals
  def individual_creators
    creators.where(type_of: Databank::CreatorType::PERSON)
  end

  ##
  # @return [ActiveRecord::Relation] all creators of this dataset that are institutions
  def institutional_creators
    creators.where(type_of: Databank::CreatorType::INSTITUTION)
  end

  def ind_creators_to_contributors
    individual_creators.each do |creator|
      Contributor.create(dataset_id:        creator.dataset_id,
                         given_name:        creator.given_name,
                         family_name:       creator.family_name,
                         email:             creator.email,
                         identifier:        creator.identifier,
                         identifier_scheme: creator.identifier_scheme,
                         row_order:         creator.row_order,
                         row_position:      creator.row_position,
                         type_of:           Databank::CreatorType::PERSON)
      creator.destroy
    end
  end

  def contributors_to_ind_creators
    contributors.each do |contributor|
      Creator.create(dataset_id:        contributor.dataset_id,
                     given_name:        contributor.given_name,
                     family_name:       contributor.family_name,
                     email:             contributor.email,
                     identifier:        contributor.identifier,
                     identifier_scheme: contributor.identifier_scheme,
                     row_order:         contributor.row_order,
                     row_position:      contributor.row_position,
                     type_of:           Databank::CreatorType::PERSON)
      contributor.destroy
    end
  end

  def contact
    contact = nil
    creators.each do |creator|
      contact = creator if creator.is_contact?
    end
    contact
  end

  def depositor
    return "unknown|Unknown Depositor" unless depositor_email

    email = depositor_email
    user = User.find_by(email: email)
    return "unknown|Unknown Depositor" unless user

    "#{depositor_netid}|#{user.name}"
  end

  def depositor_netid
    return nil unless depositor_email

    user = User.find_by(email: depositor_email)
    return nil unless user

    user.email.split("@").first
  end

  ##
  # send email to notify depositor that dataset is incomplete one month after creation
  def send_incomplete_1m
    notification = DatabankMailer.dataset_incomplete_1m(self.key)
    notification.deliver_now
  end

end
