# frozen_string_literal: true

##
# This module is responsible for the publication of datasets.
# It is included in the Dataset model.

module Dataset::Publishable
  extend ActiveSupport::Concern

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



  def publish(user)

    self.destroy_incomplete_uploads

    completion_check_result = Dataset.completion_check(self)

    return error_hash(completion_check_result) unless completion_check_result == "ok"

    old_publication_state = publication_state

    if (old_publication_state != Databank::PublicationState::DRAFT) &&
        (!identifier || identifier == "")
      return {status:     "error",
              error_text: "Missing identifier for dataset that is not a draft. Dataset: #{key}"}
    end

    if old_publication_state == Databank::PublicationState::DRAFT && (!identifier || identifier == "")
      self.identifier = default_identifier
    end

    self.publication_state = if self.embargo && Databank::PublicationState::EMBARGO_ARRAY.include?(self.embargo)
                               self.embargo
                             else
                               Databank::PublicationState::RELEASED
                             end

    if Databank::PublicationState::DRAFT_ARRAY.include?(old_publication_state) &&
      self.publication_state == Databank::PublicationState::RELEASED && !is_import
      self.release_date = Date.current
    end

    unless Databank::PublicationState::PUB_ARRAY.include?(publication_state)
      return {status: "error", error_text: "problem publishing dataset: #{key}"}
    end

    save!
    datacite_attempt = if metadata_public?
                         publish_doi
                       else
                         register_doi
                       end

    if datacite_attempt[:status] == "ok"
      self.share_code.destroy if ( self.share_code && (self.publication_state == Databank::PublicationState::RELEASED) )
      MedusaIngest.send_dataset_to_medusa(self)

      if IDB_CONFIG[:local_mode] && IDB_CONFIG[:local_mode] == true
        Rails.logger.warn "Dataset #{key} succesfully deposited."
        return {status: :ok, old_publication_state: old_publication_state}
      else
        send_publication_notice
      end
      if self.previous_idb_dataset
        Sunspot.index [self.previous_idb_dataset]
        Sunspot.commit
      end
      {status: "ok", old_publication_state: old_publication_state}
    else
      self.publication_state = old_publication_state
      save!
      Rails.logger.warn(datacite_attempt.to_yaml)
      notification = DatabankMailer.error("Error in publishing dataset #{key}: #{datacite_attempt.to_yaml}")
      notification.deliver_now
      error_hash("Error in publishing dataset has been logged for review by the Research Data Service.")
    end
  end

  def has_review_request?
    ReviewRequest.exists?(dataset_key: key)
  end

  def review_requests
    ReviewRequest.where(dataset_key: key)
  end

  def destroy_review_requests
    review_requests.destroy_all
  end

  def destroy_incomplete_uploads
    datafile_web_ids = self.datafiles.pluck(:web_id)
    valid_web_ids = self.datafiles.pluck(:web_id)
    invalid_web_ids = datafile_web_ids - valid_web_ids
    self.datafiles.where(web_id: invalid_web_ids).destroy_all
  end
end
