# frozen_string_literal: true

##
# This module supports the embargoing of datasets.
# It is included in the Dataset model.

module Dataset::Embargoable
  extend ActiveSupport::Concern

  ##
  # Checks if an dataset is embargoed with a valid date.
  # @return [Boolean] true if the dataset is embargoed and the release date is in the future, false otherwise
  def embargoed_with_valid_date?
    Databank::PublicationState::EMBARGO_ARRAY.include?(embargo) && release_date && release_date > Time.current
  end

  ##
  # Checks if an dataset is embargoed with a valid date.
  # @return [Boolean] true if the dataset is embargoed and the release date is in the future, false otherwise
  def embargoed?
    Databank::PublicationState::EMBARGO_ARRAY.include?(embargo)
  end

  # to work around persistent system bug that shows embargoed content
  # set the publication state to the embargo state if the release date is in the future
  # @return [Boolean] true once the publication state has been checked and either was already fine or is fixed
  def ensure_embargo
    return true if publication_state == Databank::PublicationState::DRAFT

    return true if publication_state == embargo

    return true if embargo.nil?

    return true if embargo == Databank::PublicationState::Embargo::NONE

    return true if release_date <= Time.current

    self.publication_state = embargo
    self.save!
  end

  ##
  # send email to notify depositor that dataset embargo is approaching in one month
  def send_embargo_approaching_1m
    notification = DatabankMailer.embargo_approaching_1m(self.key)
    notification.deliver_now
  end

  ##
  # send email to notify depositor that dataset embargo is approaching in one week
  def send_embargo_approaching_1w
    notification = DatabankMailer.embargo_approaching_1w(self.key)
    notification.deliver_now
  end

end
