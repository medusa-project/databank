# frozen_string_literal: true

module Publishable
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
    return false
  end

  def publish(user)
    completion_check_result = Dataset.completion_check(self, user)

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

    # set publication_state
    self.publication_state = if embargo && Databank::PublicationState::EMBARGO_ARRAY.include?(embargo)
                               embargo
                             else
                               Databank::PublicationState::RELEASED
                             end

    if old_publication_state == Databank::PublicationState::DRAFT &&
        self.publication_state == Databank::PublicationState::RELEASED &&
        !is_import
      self.release_date = Date.current
    end

    save!

    unless Databank::PublicationState::PUB_ARRAY.include?(self.publication_state)
      return {status: "error", error_text: "problem publishing dataset: #{key}"}
    end

    datacite_attempt = if self.metadata_public?
                         publish_doi
                       else
                         register_doi
                       end

    if datacite_attempt[:status] == "ok"
      MedusaIngest.send_dataset_to_medusa(self)

      if IDB_CONFIG[:local_mode] && IDB_CONFIG[:local_mode] == true
        Rails.logger.warn "Dataset #{key} succesfully deposited."
        return {status: :ok, old_publication_state: old_publication_state}
      else
        send_publication_notice
      end
      {status: "ok", old_publication_state: old_publication_state}
    else
      self.publication_state = old_publication_state
      self.save!
      Rails.logger.warn(datacite_attempt.to_yaml)
      notification = DatabankMailer.error("Error in publishing dataset #{self.key}: #{datacite_attempt.to_yaml}")
      notification.deliver_now
      error_hash("Error in publishing dataset has been logged for review by the Research Data Service.")
    end
  end

end
