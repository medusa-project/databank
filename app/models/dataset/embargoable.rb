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
  # Notify the depositor that the dataset embargo is approaching in one month.
  def send_embargo_approaching_1m
    send_embargo_approaching_notice(period: "one month")
  end

  ##
  # Notify the depositor that the dataset embargo is approaching in one week.
  def send_embargo_approaching_1w
    send_embargo_approaching_notice(period: "one week")
  end

  private

  def send_embargo_approaching_notice(period:)
    edit_url = "#{IDB_CONFIG[:root_url_text]}/datasets/#{key}/edit"
    comment = [
      "Hello,",
      "Thank you for depositing your dataset in the Illinois Data Bank on #{ingest_datetime.to_date.iso8601}.",
      "We are writing to let you know that your release date, #{release_date.to_date.iso8601}, " \
        "is coming up in #{period}.",
      "If you need to change your release date, you may be able to do so here: #{edit_url}.",
      "The maximum amount of time a dataset may be embargoed is one year from the date of initial deposit, " \
        "so the system will not allow you to extend the date longer than that.",
      "If you have any questions, please email us at databank@library.illinois.edu.",
      "Thank you,",
      "Research Data Service Curators",
      "Research Data Service",
      "University of Illinois Urbana-Champaign",
      "databank@library.illinois.edu",
      "(217) 300-3513"
    ].join("\n\n")

    add_comment(change: comment, notify: [depositor_email])
  end
end
