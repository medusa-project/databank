# frozen_string_literal: true

##
# This module provides methods for generating messages to be displayed to users
# in the UI. The methods are used in the Dataset model.

module Dataset::MessageText
  extend ActiveSupport::Concern

  def availability_statement
    if embargoed_with_valid_date?
      "The dataset supporting these findings will be openly available in the Illinois Data Bank at #{persistent_url} on #{release_date}."
    elsif publication_state == Databank::PublicationState::RELEASED
      "The dataset supporting these findings is openly available in the Illinois Data Bank at #{persistent_url}."
    else
      "This dataset is not publicly available."
    end
  end

  class_methods do
    def deposit_confirmation_notice(old_state, dataset)
      new_state = dataset.publication_state

      case old_state
      when Databank::PublicationState::TempSuppress::VERSION
        case new_state
        when Databank::PublicationState::DRAFT
          %(Your dataset record changes have been successfully saved and are awaiting curator review.)

        when Databank::PublicationState::RELEASED
          %(Your dataset record changes have been successfully published.)

        when Databank::PublicationState::Embargo::METADATA
          %(Your dataset record changes have been successfully saved and are awaiting curator review.)

        when Databank::PublicationState::Embargo::FILE
          %(Your dataset record changes have been successfully saved and are awaiting curator review.)
        else
          Rails.logger.warn("UE1 - key: #{dataset.key}, old_state: #{old_state}, new_state: #{new_state}")
          %(Unexpected error, please contact the <a href="/help">Research Data Service Team</help>.)
        end
      when Databank::PublicationState::DRAFT
        case new_state
        when Databank::PublicationState::RELEASED
          %(Dataset was successfully published and the DataCite DOI is #{dataset.identifier}.<br/>The persistent URL to cite this dataset is now <a href = "#{dataset.persistent_url}">#{dataset.persistent_url}</a>.<br/>There may be a delay before the persistent link will be in effect.  If this link does not redirect to the dataset immediately, try again in an hour.)

        when Databank::PublicationState::Embargo::METADATA
          %(DataCite DOI #{dataset.identifier} successfully reserved.<br/>The persistent URL to cite this dataset will be <a href = "#{dataset.persistent_url}">#{dataset.persistent_url}</a> starting #{dataset.release_date}.)

        when Databank::PublicationState::Embargo::FILE
          %(Dataset record was successfully published and the DataCite DOI is #{dataset.identifier}.<br/>Although the record for your dataset will be <strong>publicly</strong> visible, your data files will not be made available until #{dataset.release_date.iso8601}.<br/>The persistent URL to cite this dataset is now <a href = "#{dataset.persistent_url}">#{dataset.persistent_url}</a>.<br/>There may be a delay before the persistent link will be in effect.  If this link does not redirect to the dataset immediately, try again in an hour.)
        else
          Rails.logger.warn("UE1 - key: #{dataset.key}, old_state: #{old_state}, new_state: #{new_state}")
          %(Unexpected error, please contact the <a href="/help">Research Data Service Team</help>.)
        end

      when Databank::PublicationState::RELEASED
        case new_state
        when Databank::PublicationState::RELEASED
          %(Dataset record changes have been successfully published.)

        when Databank::PublicationState::Embargo::METADATA
          %(Placeholder metadata has replaced previously published metadata for this DataCite DOI #{dataset.identifier}.<br/>The persistent link to this dataset will be <a href = "#{dataset.persistent_url}">#{dataset.persistent_url}</a> starting #{dataset.release_date}.)

        when Databank::PublicationState::Embargo::FILE
          %(Dataset record changes have been was successfully published.<br/>Although the record for your dataset will be <strong>publicly</strong> visible, your data files will not be made available until #{dataset.release_date.iso8601}.)
        else
          Rails.logger.warn("UE2 - key: #{dataset.key}, old_state: #{old_state}, new_state: #{new_state}")
          %(Unexpected error, please contact the <a href="/help">Research Data Service Team</help>.)
        end

      when Databank::PublicationState::Embargo::METADATA
        case new_state
        when Databank::PublicationState::RELEASED
          %(Dataset was successfully published and the DataCite DOI is #{dataset.identifier}.<br/>The persistent link to this dataset is <a href = "#{dataset.persistent_url}">#{dataset.persistent_url}</a>.<br/>There may be a delay before the persistent link will be in effect.  If this link does not redirect to the dataset immediately, try again in an hour.)

        when Databank::PublicationState::Embargo::METADATA
          %(No changes have been published.<br/>The persistent link to this dataset will be <a href = "#{dataset.persistent_url}">#{dataset.persistent_url}</a> starting #{dataset.release_date}.)

        when Databank::PublicationState::Embargo::FILE
          %(Dataset record was successfully published and the DataCite DOI is #{dataset.identifier}.<br/>Although the record for your dataset will be <strong>publicly</strong> visible, your data files will not be made available until #{dataset.release_date.iso8601}.<br/>The persistent link to this dataset is now <a href = "#{dataset.persistent_url}">#{dataset.persistent_url}</a>.<br/>There may be a delay before the persistent link will be in effect.  If this link does not redirect to the dataset immediately, try again in an hour.)
        else
          Rails.logger.warn("UE3 - key: #{dataset.key}, old_state: #{old_state}, new_state: #{new_state}")
          %(Unexpected error, please contact the <a href="/help">Research Data Service Team</help>.)
        end

      when Databank::PublicationState::Embargo::FILE

        case new_state
        when Databank::PublicationState::RELEASED
          %(Dataset was successfully published and files are publically available.)

        when Databank::PublicationState::Embargo::METADATA
          %(A placeholder record has replaced the previously published record for this DataCite DOI #{dataset.identifier}.<br/>The persistent link to this dataset is <a href = "#{dataset.persistent_url}">#{dataset.persistent_url}</a> starting #{dataset.release_date}.)

        when Databank::PublicationState::Embargo::FILE
          %(Dataset record changes have been was successfully published.<br/>Although the record for your dataset will be <strong>publicly</strong> visible, your data files will not be made available until #{dataset.release_date.iso8601}.)
        else
          Rails.logger.warn("UE4 - key: #{dataset.key}, old_state: #{old_state}, new_state: #{new_state}")
          %(Unexpected error, please contact the <a href="/help">Research Data Service Team</help>.)
        end

      when Databank::PublicationState::PermSuppress::FILE
        case new_state
        when Databank::PublicationState::RELEASED
          %(Dataset record changes have been successfully published.)

        when Databank::PublicationState::Embargo::METADATA
          %(A placeholder record has replaced the previously published record for this DataCite DOI #{dataset.identifier}.<br/>The descriptive record for your dataset and your files will be <strong>publicly</strong> available #{dataset.release_date.iso8601}.)

        when Databank::PublicationState::Embargo::FILE
          %(Dataset record changes have been successfully published.<br/>Although the record for your dataset is <strong>publicly</strong> visible, your data files will not be made available until #{dataset.release_date.iso8601}.)
        else
          Rails.logger.warn("UE4 - key: #{dataset.key}, old_state: #{old_state}, new_state: #{new_state}")
          %(Unexpected error, please contact the <a href="/help">Research Data Service Team</help>.)
        end

      else
        Rails.logger.warn("UE4 - key: #{dataset.key}, unexpected old_state: #{old_state}, new_state: #{new_state}")
        %(Changes to this dataset's <strong>public</strong> record have been made effective.)
      end
    end

    def embargoed_with_valid_date(dataset:)
      dataset.release_date &&
        dataset.release_date >= Date.current &&
        dataset.embargo &&
        Databank::PublicationState::EMBARGO_ARRAY.include?(dataset.embargo)
    end

    def publish_modal_msg(dataset:)
      raise "no dataset passed to publish_modal_msg" if dataset.nil?

      effective_embargo = nil
      effective_release_date = Date.current.iso8601

      if Dataset.embargoed_with_valid_date(dataset: dataset)
        effective_embargo = dataset.embargo
        effective_release_date = dataset.release_date.iso8601
      end

      msg = "<div class='confirm-modal-text'>"

      case effective_embargo

      when Databank::PublicationState::Embargo::FILE

        msg += if dataset.publication_state == Databank::PublicationState::DRAFT
                 "<h4>This action will make the dataset record <strong>public</strong>"
               else
                 "<h4>This action will make your updates to your dataset record <strong>public</strong>"
               end
        msg += ", but your files will remain unavailable.</h4><hr/>"
        msg += "<ul>"
        msg += "<li>The Illinois Data Bank dataset record will be <strong>publicly</strong> visible through search engines.</li>"
        msg += "<li>Although the record for the dataset will be <strong>publicly</strong> visible, the data files will not be made available until #{effective_release_date}.</li>"

      when Databank::PublicationState::Embargo::METADATA
        if dataset.publication_state == Databank::PublicationState::DRAFT
          msg += "<h4>This action will reserve a DOI</h4><hr/>"
          msg += "<ul>"
          msg += "<li>The DOI link will fail until #{effective_release_date}.</li>"
          msg += "<li>As of #{effective_release_date}, the record and files for the dataset will be publicly visible.</li>"
        elsif dataset.publication_state == Databank::PublicationState::Embargo::METADATA
          msg += "<h4>This action will save the metadata changes.</h4><hr/>"
          msg += "<ul>"
          msg += "<li>The DOI originally reserved for the dataset remains the same (#{dataset.identifier}), and the link will continue to fail until #{effective_release_date}.</li>"
          msg += "<li>As of #{effective_release_date}, the record and files for the dataset will be publicly visible.</li>"

        elsif [Databank::PublicationState::Embargo::FILE, Databank::PublicationState::RELEASED].include?(dataset.publication_state)
          msg += "<h3>This action will remove the dataset from <strong>public</strong> availability.</h3>"
          msg += "<ul>"
          msg += "<li>The DOI link will resolve to an DataCite generic invalid tombstone page until #{effective_release_date}.</li>"
          msg += "<li>The record for the dataset is not visible, nor are the data files available until #{effective_release_date}.</li>"
        else
          msg += "<h4>Unexpected Error: Please contact the <a href='/help'>Research Data Service Team</a>.</h4><hr/>"
          msg += "<ul>"
        end

      else
        msg += if dataset.publication_state == Databank::PublicationState::DRAFT
                 "<h4>This action will make the dataset <strong>public</strong>.</h4><hr/>"
               else
                 "<h4>This action will make your updates to the dataset record <strong>public</strong>.</h4><hr/>"
               end
        msg += "<ul>"
        msg += "<li>The Illinois Data Bank dataset record will be <strong>publicly</strong> visible through search engines.</li>"
        msg += "<li>The data files will be <strong>publicly</strong> available.</li>"
      end

      if dataset.publication_state == Databank::PublicationState::DRAFT
        msg += "<li>All authors will receive a confirmation email with the DOI and other information about the dataset.</li>"
      end

      msg += "<li>The depositor will be able to edit the description for the dataset, but would need to contact the <a href='/help'>Research Data Service</a> to change, update, or add files for any reason.</li> "

      msg + "</ul></div>"
    end
  end
end
