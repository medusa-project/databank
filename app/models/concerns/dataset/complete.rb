# frozen_string_literal: true

module Complete
  extend ActiveSupport::Concern

  class_methods do
    # making completion_check a class method with passed-in dataset, so it can be used by controller before save
    def completion_check(dataset, current_user)
      e_arr = []
      e_arr << "title" if dataset.title.blank?
      e_arr << "at least one creator" if dataset.creators.count < 1
      e_arr << "license" if dataset.license.blank?
      e_arr << "at least one file" unless dataset.datafiles.count.positive?
      e_arr << "select primary contact from author list" unless dataset.contact
      e_arr << "identifier to import" if dataset.is_import? && !dataset.identifier
      e_arr += Dataset.license_error(dataset) || []
      e_arr += Dataset.creator_email_errors(dataset) || []
      e_arr += Dataset.duplicate_doi_error(dataset) || []
      e_arr += Dataset.duplicate_datafile_error(dataset) || []
      e_arr += Dataset.embargo_errors(dataset) || []
      e_arr += Dataset.import_date_errors(dataset) || []
      return "ok" if e_arr.empty?

      validation_error_message = "Required elements for a complete dataset missing: "
      e_arr.each_with_index do |m, i|
        validation_error_message += ", " if i.positive?
        validation_error_message += m
      end
      validation_error_message += "."
    end

    def creator_email_errors(dataset)
      e_arr = []
      dataset.creators.each do |creator|
        return ["an email address for all creators"] unless creator.email && creator.email != ""

        next unless creator.email.include?("@illinois.edu")

        netid = creator.email.split("@").first
        # check to see if netid is found, to prevent email system errors
        begin
          open("https://quest.grainger.uiuc.edu/directory/ed/person/#{netid}").read
        rescue OpenURI::HTTPError
          e_arr << "correct netid in email for #{creator.given_name} #{creator.family_name}"
        end
      end
      e_arr
    end

    def license_error(dataset)
      return nil if !dataset.license || dataset.license != "license.txt"

      has_file = false
      dataset.datafiles&.each do |datafile|
        has_file = true if datafile.bytestream_name&.casecmp("license.txt")&.zero?
      end
      return ["a license file named license.txt or a different license selection"] unless has_file
    end

    def duplicate_doi_error(dataset)
      return nil if dataset.identifier.blank?
      ["a unique DOI"] if Dataset.where(identifier: dataset.identifier).count > 1
    end

    def duplicate_datafile_error(dataset)
      datafiles_arr = []
      dataset.datafiles.each do |datafile|
        datafiles_arr << datafile.bytestream_name
      end
      first_dup = datafiles_arr.find {|e| datafiles_arr.count(e) > 1 }
      ["no duplicate filenames (#{first_dup})"] if first_dup
    end

    def embargo_errors(dataset)
      embargo_states = [Databank::PublicationState::Embargo::FILE, Databank::PublicationState::Embargo::METADATA]

      if dataset.embargo && embargo_states.include?(dataset.embargo) &&
          (!dataset.release_date || dataset.release_date <= Date.current)
        return ["a future release date for delayed publication (embargo) selection"]
      end

      if (!dataset.embargo || embargo_states.exclude?(dataset.embargo)) &&
          (dataset.release_date && dataset.release_date > Date.current)
        return ["a delayed publication (embargo) selection for a future release date"]
      end

      nil
    end

    def import_date_errors(dataset)
      return ["a release date for imported dataset"] if dataset.is_import && dataset.release_date.nil?

      nil
    end
  end
end
