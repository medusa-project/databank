# frozen_string_literal: true

module Indexable
  extend ActiveSupport::Concern

  def visibility
    return_string = case hold_state
                    when Databank::PublicationState::TempSuppress::METADATA
                      "Metadata and Files Temporarily Suppressed"
                    when Databank::PublicationState::TempSuppress::FILE
                      case publication_state
                      when Databank::PublicationState::DRAFT
                        "Draft"
                      when Databank::PublicationState::Embargo::FILE
                        "Metadata Published, Files Publication Delayed (Embargoed)"
                      when Databank::PublicationState::Embargo::METADATA
                        "Metadata and Files Publication Delayed (Embargoed)"
                      when Databank::PublicationState::PermSuppress::FILE
                        "Metadata Published, Files Withdrawn"
                      when Databank::PublicationState::PermSuppress::METADATA
                        "Metadata and Files Withdrawn"
                      else
                        "Metadata Published, Files Temporarily Suppressed"
                      end

                    else
                      case publication_state
                      when Databank::PublicationState::DRAFT
                        "Draft"
                      when Databank::PublicationState::RELEASED
                        "Metadata and Files Published"
                      when Databank::PublicationState::Embargo::FILE
                        "Metadata Published, Files Publication Delayed (Embargoed)"
                      when Databank::PublicationState::Embargo::METADATA
                        "Metadata and Files Publication Delayed (Embargoed)"
                      when Databank::PublicationState::PermSuppress::FILE
                        "Metadata Published, Files Withdrawn"
                      when Databank::PublicationState::PermSuppress::METADATA
                        "Metadata and Files Withdrawn"
                      else
                        # should never get here
                        "Unknown, please contact the Research Data Service"
                      end
                    end

    return_string = "Unsaved Draft" if new_record?

    return_string
  end

  def self.visibility_name_from_code(code)
    case code
    when "released"
      "Metadata and Files Published"
    when "draft"
      "Draft"
    when "new"
      "Unsaved Draft"
    when "suppressed_mf"
      "Metadata and Files Temporarily Suppressed"
    when "suppressed_f"
      "Metadata Published, Files Temporarily Suppressed"
    when "embargoed_mf"
      "Metadata and Files Publication Delayed (Embargoed)"
    when "embargoed_f"
      "Metadata Published, Files Publication Delayed (Embargoed)"

    when "withdrawn_mf"
      "Metadata and Files Withdrawn"
    when "withdrawn_f"
      "Metadata Published, Files Withdrawn"
    else
      "Error: publication state not found"
    end
  end

  def visibility_code
    return_string = case hold_state
                    when Databank::PublicationState::TempSuppress::METADATA
                      "suppressed_mf"
                    when Databank::PublicationState::TempSuppress::FILE
                      case publication_state
                      when Databank::PublicationState::DRAFT
                        "draft"
                      when Databank::PublicationState::Embargo::FILE
                        "embargoed_f"
                      when Databank::PublicationState::Embargo::METADATA
                        "embargoed_mf"
                      when Databank::PublicationState::PermSuppress::FILE
                        "withdrawn_f"
                      when Databank::PublicationState::PermSuppress::METADATA
                        "withdrawn_mf"
                      else
                        "suppressed_f"
                      end

                    else
                      case publication_state
                      when Databank::PublicationState::DRAFT
                        "draft"
                      when Databank::PublicationState::RELEASED
                        "released"
                      when Databank::PublicationState::Embargo::FILE
                        "embargoed_f"
                      when Databank::PublicationState::Embargo::METADATA
                        "embargoed_mf"
                      when Databank::PublicationState::PermSuppress::FILE
                        "withdrawn_f"
                      when Databank::PublicationState::PermSuppress::METADATA
                        "withdrawn_mf"
                      else
                        # should never get here
                        "unknown"
                      end
                    end

    return_string = "new" if new_record?

    return_string
  end

  def self.license_name_from_code(code)
    if %w[unselected custom].include?(code)
      code
    else
      licenses = LICENSE_INFO_ARR.select {|license| license.code == code }
      return code if licenses.blank?

      licenses[0].name
    end
  end

  def self.funder_name_from_code(code)
    if code == "other"
      "Other"
    else
      funders = FUNDER_INFO_ARR.select {|funder| funder.code == code }
      return "funder not found" if funders.blank?

      funders[0].name
    end
  end

  def funder_names
    Funder.where(dataset_id: id).pluck(:name)
  end

  def funder_codes
    Funder.where(dataset_id: id).pluck(:code)
  end

  def funder_names_fulltext
    funder_names.join(" ").to_s
  end

  def internal_view_netids
    internal_reviewer_netids + internal_editor_netids
  end

  def internal_reviewer_netids
    uids = UserAbility.where(user_provider: 'shibboleth',
                             resource_type: 'Dataset',
                             ability: 'view_files',
                             'resource_id': self.id).pluck(:user_uid)
    uid_parts = uids.collect {|x| x.split("@") || [x]}

    netids = uid_parts.collect {|x| x[0] }

    netids.uniq - internal_editor_netids

  end

  def internal_editor_netids
    uids = UserAbility.where(user_provider: 'shibboleth',
                             resource_type: 'Dataset',
                             ability: 'update',
                             'resource_id': id).pluck(:user_uid)
    uid_parts = uids.collect {|x| x.split("@") || [x]}

    netids = uid_parts.collect {|x| x[0] }

    netids.uniq
  end

  def grant_numbers
    Funder.where(dataset_id: id).pluck(:grant)
  end

  def grant_numbers_fulltext
    grant_numbers.join(" ")
  end

  def creator_names
    return_arr = []
    creators.each do |creator|
      return_arr << creator.display_name
    end
    return_arr
  end

  def creator_names_fulltext
    creator_names.join(" ")
  end

  def subject_text
    if subject && subject != ""
      subject
    else
      "None"
    end
  end

  def filenames
    return_arr = []
    datafiles.each do |datafile|
      return_arr << datafile.bytestream_name
    end
    return_arr
  end

  def filenames_fulltext
    filenames.join(" ")
  end

  def self.pubstate_name_from_code(code)
    case code
    when Databank
      "draft"
    else
      "not draft"
    end
  end

  def datafile_extensions
    return_arr = []
    datafiles.each do |datafile|
      return_arr << datafile.file_extension
    end
    return_arr
  end

  def datafile_extensions_fulltext
    datafile_extensions.join(" ")
  end

  def self.citation_report(search, request_url, current_user)
    report_text = ""

    15.times do
      report_text += "="
    end

    report_text += "\nIllinois Data Bank\nDatasets Report, generated #{Date.current.iso8601}"
    report_text += " by #{current_user.username}" if current_user&.username
    report_text += "\nQuery URL: #{request_url}\n"

    15.times do
      report_text += "="
    end

    report_text += "\n"

    search.each_hit_with_result do |_hit, dataset|
      report_text += "\n\n#{dataset.plain_text_citation}"
      if dataset.funders.count.positive?
        dataset.funders.each do |funder|
          report_text += "\nFunder: #{funder.name}"
          report_text += ", Grant: #{funder.grant}" if funder.grant && funder.grant != ""
        end
      end
      report_text += "\nDownloads: #{dataset.total_downloads} "
      if dataset.release_datetime
        start_time = dataset.release_datetime.to_date.iso8601
      else
        start_time = Date.current.iso8601
      end

      report_text += "(#{start_time} to #{Date.current.iso8601} )\n"
      5.times do
        report_text += "-"
      end
    end

    report_text
  end
end
