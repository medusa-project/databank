# frozen_string_literal: true

##
# This module is responsible for the publication of datasets.
# It is included in the Dataset model.

module Dataset::Publishable
  extend ActiveSupport::Concern

  def local_mode?
    IDB_CONFIG[:local_mode] && IDB_CONFIG[:local_mode] == true
  end

  def send_publication_notice
    begin
      notification = DatabankMailer.confirm_deposit(key)
      notification.deliver_now
      return true
    rescue StandardError => e
      notification = DatabankMailer.confirmation_not_sent(key, e)
      notification.deliver_now
      return false
    end
    false
  end

  ##
  # Returns whether the dataset is ok to publish
  # This method checks the publication state and embargo status of the dataset
  # "published" in this context means that the dataset has a searchable DOI registered with DataCite
  # "ok to publish" means that the dataset is in a state where it can be published
  # @return [Boolean] true if the dataset is ok to publish, false otherwise
  def ok_to_publish?

    # non-draft datasets are not ok to publish if they are missing an identifier
    missing_identifier_for_non_draft = (publication_state != Databank::PublicationState::DRAFT) && (!identifier || identifier == "")
    if missing_identifier_for_non_draft
      Rails.logger.warn( "Missing identifier for dataset that is not a draft. Dataset: #{key}" )
      return false
    end

    # if the dataset is in a hold state, it is not ok to publish
    return false unless [Databank::PublicationState::TempSuppress::NONE, nil, ""].include?(hold_state)

    # metadata embargoed datasets are ok to publish, which removes the embargo
    return true if publication_state == Databank::PublicationState::Embargo::METADATA

    # file-embargoed datasets are ok to publish, which removes the embargo
    return true if publication_state == Databank::PublicationState::Embargo::FILE

    # approved version candidates are ok to publish\
    return true if hold_state == Databank::PublicationState::TempSuppress::NONE && publication_state == Databank::PublicationState::TempSuppress::VERSION

    # other draft datasets are ok to publish
    return true if publication_state == Databank::PublicationState::DRAFT

    # if the dataset is not in a state that is ok to publish, return false
    #Rails.logger.warn( "Dataset is not ok to publish. Dataset: #{key} publication_state: #{publication_state} hold_state: #{hold_state}" )
    #Rails.logger.warn( self.to_yaml )
    false
  end

  ##
  # Publishes the dataset if it is ok to publish.
  # This method checks the dataset's state, sets the identifier, updates the publication state,
  # and attempts to publish the DOI. If successful, it sends the dataset to Medusa and sends a publication notice.
  # @param user [User] the user who is publishing the dataset
  # @return [Hash] the status of the publication process
  def publish(user)

    # check if the dataset is ok to publish
    return {status: "error", error_text: "Dataset is not ok to publish"} unless ok_to_publish?

    # destroy any incomplete uploads
    self.destroy_incomplete_uploads if datafiles&.where(web_id: nil)&.exists?

    # check if the dataset is complete
    completion_check_result = Dataset.completion_check(self)

    return error_hash(completion_check_result) unless completion_check_result == "ok"

    # hold on to the old publication state
    old_publication_state = publication_state

    # set the identifer (DOI) if it is missing
    if old_publication_state == Databank::PublicationState::DRAFT && (!identifier || identifier == "")
      self.identifier = default_identifier
    end

    # set the publication state
    # set the publication state to the embargo state if embargo is set and valid
    # otherwise set the publication state to released
    if self.embargo && Databank::PublicationState::EMBARGO_ARRAY.include?(self.embargo)
      self.publication_state = self.embargo
    else
      self.publication_state = Databank::PublicationState::RELEASED
      self.hold_state = Databank::PublicationState::TempSuppress::NONE
    end

    # set the release date if the publication state was draft(y) and this publication action is making it released
    if Databank::PublicationState::DRAFT_ARRAY.include?(old_publication_state) &&
      self.publication_state == Databank::PublicationState::RELEASED && !is_import
      self.release_date = Date.current
    end

    # return an error if something went wrong and the publication state is not valid
    unless Databank::PublicationState::PUB_ARRAY.include?(publication_state)
      return {status: "error", error_text: "problem publishing dataset: #{key}"}
    end

    # save the dataset with the new publication state because the DOI methods need the new publication state
    begin
     save!
    rescue StandardError => e
      Rails.logger.error("Error attepmting to save dataset during publication #{key}: #{e.message}")
      return {status: "error", error_text: "Failed to publish dataset"}
    end
    
    # try to publish the DOI
    datacite_attempt = if metadata_public?
                         publish_doi
                       else
                         register_doi
                       end

    
    # if the DOI was published successfully, do some cleanup and send the dataset to Medusa
    if datacite_attempt[:status] == "ok"

      # destroy the share code if the dataset is released
      self.share_code.destroy if ( self.share_code && (self.publication_state == Databank::PublicationState::RELEASED) )

      # send the dataset to Medusa
      MedusaIngest.send_dataset_to_medusa(self)

      # index the previous dataset version in Solr if this dataset is part of a version set
      Sunspot.index! [self.previous_idb_dataset] if self.previous_idb_dataset

      if local_mode?
        Rails.logger.warn "Dataset #{key} succesfully deposited."
        return {status: :ok, old_publication_state: old_publication_state}
      end  
      return {status: :error, message: "publication notice not sent"} unless send_publication_notice

      {status: "ok", old_publication_state: old_publication_state}
    # if the DOI was not published successfully, revert the publication state and return an error
    else
      self.publication_state = old_publication_state
      begin
        save!
      rescue StandardError => e
        Rails.logger.error("Failed to save dataset after failed publication attempt. Dataset: #{key} may be in invalid state.")
        return {status: "error", error_text: "Failed to save dataset after failed publication attempt. Dataset: #{key} in invalid state."}
      end
      Rails.logger.warn(datacite_attempt.to_yaml)
      notification = DatabankMailer.error("Error in publishing dataset #{key}: #{datacite_attempt.to_yaml}")
      notification.deliver_now
      return {status: "error", error_text: "Failed to publish dataset #{key}: see logs for details"}
    end
  end

  # @return [Boolean] true if the dataset has a review request, false otherwise
  def has_review_request?
    ReviewRequest.exists?(dataset_key: key)
  end

  # @return [ActiveRecord::Relation] the review requests for the dataset
  def review_requests
    ReviewRequest.where(dataset_key: key)
  end

  # destroy all review requests for the dataset
  # @return [Boolean] true if the review requests were destroyed, false otherwise
  def destroy_review_requests
    review_requests.destroy_all
  end

  # destroy all incomplete uploads for the dataset
  # @return [Boolean] true if any incomplete uploads were destroyed, false otherwise
  def destroy_incomplete_uploads
    datafile_web_ids = self.datafiles.pluck(:web_id)
    valid_web_ids = self.datafiles.pluck(:web_id)
    invalid_web_ids = datafile_web_ids - valid_web_ids
    return true if invalid_web_ids.empty?

    self.datafiles.where(web_id: invalid_web_ids).destroy_all
  end

  # @return [Boolean] true if the dataset is in pre-publication review, false otherwise
  def in_pre_publication_review?
    Databank::PublicationState::DRAFT_ARRAY.include?(publication_state) && has_review_request?
  end

  # @return [Boolean] true if the dataset is in pre-publication review and has no review requests, false otherwise
  def show_publish_only?
    return false unless in_pre_publication_review?

    return false unless [Databank::PublicationState::TempSuppress::NONE, nil].include?(hold_state)

    return false unless Dataset.completion_check(self) == "ok"

    true
  end

end
