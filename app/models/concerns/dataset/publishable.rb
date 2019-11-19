# frozen_string_literal: true

module Publishable
  extend ActiveSupport::Concern

  def publish(user)

    return_json = {status: :error_occurred,
                   error_text: "Incomplete workflow in publish attempt."}
    completion_check_result = Dataset.completion_check(self, user)

    return {status: :error_occurred, error_text: completion_check_result} unless completion_check_result == "ok"

    release_date ||= Date.current

    old_publication_state = publication_state

    if (old_publication_state != Databank::PublicationState::DRAFT) &&
        (!identifier || identifier == "")
      return {status: :error_occurred,
              error_text: "Missing identifier for dataset that is not a draft. Dataset: #{key}"}
    end

    if old_publication_state == Databank::PublicationState::DRAFT && (!self.identifier || self.identifier == "")
      self.identifier = default_identifier
    end

    # set publication_state
    embargo_list = [Databank::PublicationState::Embargo::FILE, Databank::PublicationState::Embargo::METADATA]
    publication_state = if embargo && embargo_list.include?(embargo)
                          embargo
                        else
                          Databank::PublicationState::RELEASED
                        end

    if old_publication_state == Databank::PublicationState::DRAFT &&
        publication_state != Databank::PublicationState::DRAFT

      # set release date to current if not embargo
      self.release_date = Date.current if publication_state == Databank::PublicationState::RELEASED
    end

    save!

    metadata_should_be_public = [Databank::PublicationState::RELEASED,
                                 Databank::PublicationState::Embargo::FILE,
                                 Databank::PublicationState::TempSuppress::FILE,
                                 Databank::PublicationState::PermSuppress::FILE].include?(publication_state) &&
        (hold_state.nil? || (hold_state == Databank::PublicationState::TempSuppress::NONE))

    if metadata_should_be_public
      datacite_ok = publish_doi
    else
      datacite_ok = register_doi
    end

    if datacite_ok
      MedusaIngest.send_dataset_to_medusa(self)

      if IDB_CONFIG[:local_mode] && IDB_CONFIG[:local_mode] == true
        Rails.logger.warn "Dataset #{key} succesfully deposited."
        return {status: :ok, old_publication_state: old_publication_state}
      else
        begin
          notification = DatabankMailer.confirm_deposit(key)
          notification.deliver_now
        rescue StandardError => e
          notification = DatabankMailer.confirmation_not_sent(key, e)
          notification.deliver_now
        end
      end
      return {status: :ok, old_publication_state: old_publication_state}
    else
      return {status: :error_occurred,
              error_text: "Error in publishing dataset has been logged for review by the Research Data Service."}
    end

    return_json
  end
end
