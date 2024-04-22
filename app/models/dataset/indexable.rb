# frozen_string_literal: true

##
# This module provides methods for indexing datasets in Solr.
# It is included in the Dataset model.

module Dataset::Indexable
  extend ActiveSupport::Concern

  class_methods do
    def visibility_name_from_code(code)
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
      when "suppressed_v"
        "Version Candidate Draft Pending Approval"
      when "approved_v"
        "Version Candidate Draft Approved"
      when "unknown"
        "Unknown"
      else
        Rails.logger.warn "Error: visibility state not found for code: #{code}"
        "Unknown"
      end
    end

    def license_name_from_code(code)
      if %w[unselected custom].include?(code)
        code
      else
        licenses = LICENSE_INFO_ARR.select { |license| license.code == code }
        return code if licenses.blank?

        licenses[0].name
      end
    end

    def funder_name_from_code(code)
      if code == "other"
        "Other"
      else
        funders = FUNDER_INFO_ARR.select { |funder| funder.code == code }
        return "funder not found" if funders.blank?

        funders[0].name
      end
    end

    def pubstate_name_from_code(code)
      case code
      when Databank
        "draft"
      else
        "not draft"
      end
    end

    def citation_report(search, request_url, current_user)
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
        start_time = if dataset.release_datetime
                       dataset.release_datetime.to_date.iso8601
                     else
                       Date.current.iso8601
                     end

        report_text += "(#{start_time} to #{Date.current.iso8601} )\n"
        5.times do
          report_text += "-"
        end
      end

      report_text
    end
  end

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
                      when Databank::PublicationState::TempSuppress::FILE
                        "Metadata Published, Files Suppressed"
                      when Databank::PublicationState::TempSuppress::METADATA
                        "Metadata and Files Suppressed"
                      when Databank::PublicationState::PermSuppress::FILE
                        "Metadata Published, Files Withdrawn"
                      when Databank::PublicationState::PermSuppress::METADATA
                        "Metadata and Files Withdrawn"
                      when Databank::PublicationState::TempSuppress::VERSION
                        "Metadata and Files Suppressed"
                      else
                        # should never get here
                        "Unknown, please contact the Research Data Service"
                      end
                    end

    return_string = "Unsaved Draft" if new_record?

    return_string
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
                    when Databank::PublicationState::TempSuppress::VERSION
                      "suppressed_v"
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
                      when Databank::PublicationState::TempSuppress::FILE
                        "suppressed_f"
                      when Databank::PublicationState::TempSuppress::METADATA
                        "suppressed_mf"
                      when Databank::PublicationState::PermSuppress::FILE
                        "withdrawn_f"
                      when Databank::PublicationState::PermSuppress::METADATA
                        "withdrawn_mf"
                      when Databank::PublicationState::TempSuppress::VERSION
                        "approved_v"
                      else
                        # should never get here
                        Rails.logger.warn "Error: visibility code not found for: #{key}"
                        "unknown"
                      end
                    end

    return_string = "new" if new_record?

    return_string
  end

  def funder_names
    Funder.where(dataset_id: id).pluck(:name)
  end

  def funder_codes
    Funder.where(dataset_id: id).pluck(:code)
  end

  def draft_viewer_emails
    (view_emails + [depositor_email]).uniq
  end

  def funder_names_fulltext
    funder_names.join(" ").to_s
  end

  def view_emails
    (reviewer_emails + editor_emails).uniq
  end

  def reviewer_emails
    UserAbility.where(resource_type: "Dataset",
                      ability:       "view_files",
                      'resource_id': id).pluck(:user_uid).uniq
  end

  def editor_emails
    UserAbility.where(resource_type: "Dataset", ability: "update", 'resource_id': id).pluck(:user_uid).uniq
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
end
