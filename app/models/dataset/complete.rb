# frozen_string_literal: true

require "net-ldap"

module Dataset::Complete
  extend ActiveSupport::Concern

  def valid_change2published(params:)
    unless params.has_key?(:dataset) && (params[:dataset]).has_key?(:identifier) && params[:dataset][:identifer] != ""
      return "invalid params: #{params}"
    end

    proposed_dataset = Dataset.create
    proposed_dataset.title = params[:dataset][:title] if params[:dataset].has_key?(:title)
    proposed_dataset.license = params[:dataset][:license] if params[:dataset].has_key?(:license)

    has_license_file = false

    if complete_datafiles.count.positive?

      proposed_dataset.datafiles = []

      complete_datafiles.each do |datafile|
        next unless datafile.bytestream_name && (datafile.bytestream_name.downcase == "license.txt")

        has_license_file = true
        temporary_datafile = datafile.temp_placeholder(temp_dataset_id: proposed_dataset.id)
        proposed_dataset.datafiles.push(temporary_datafile)
      end

      unless has_license_file
        sample_file = complete_datafiles.first
        temporary_datafile = sample_file.temp_placeholder(temp_dataset_id: proposed_dataset.id)
        proposed_dataset.datafiles.push(temporary_datafile)
      end

    end

    proposed_dataset.embargo = params[:dataset][:embargo] if params[:dataset].has_key?(:embargo)

    proposed_dataset.release_date = params[:dataset][:release_date] if params[:dataset].has_key?(:release_date)

    proposed_dataset.license = params[:dataset][:license] if params[:dataset].has_key?(:license)

    if (params[:dataset]).has_key?(:creators_attributes)

      # Rails.logger.warn params[:dataset][:creators_attributes]

      proposed_dataset.creators = []

      params[:dataset][:creators_attributes].each do |creator_params|
        creator_p = creator_params[1]
        temporary_creator = nil
        if creator_p.has_key?(:type_of)

          if creator_p[:type_of] == Databank::CreatorType::PERSON.to_s &&
            creator_p.has_key?(:family_name) && creator_p.has_key?(:given_name) &&
            creator_p[:family_name] != "" && creator_p[:given_name] != ""
            temporary_creator = Creator.create(dataset_id: proposed_dataset.id,
                                               type_of: Databank::CreatorType::PERSON,
                                               family_name: creator_p[:family_name],
                                               given_name: creator_p[:given_name])

          elsif creator_p[:type_of] == Databank::CreatorType::INSTITUTION.to_s &&
            creator_p.has_key?(:institution_name) && creator_p[:institution_name] != ""
            temporary_creator = Creator.create(dataset_id: proposed_dataset.id,
                                               type_of: Databank::CreatorType::INSTITUTION,
                                               institution_name: creator_p[:institution_name])
          else
            return "invalid creator record: #{creator.to_yaml}"
          end
        end

        temporary_creator.email = creator_p[:email] if creator_p.has_key?(:email)
        temporary_creator.is_contact = creator_p[:is_contact] if creator_p.has_key?(:is_contact)

        temporary_creator.save
        proposed_dataset.creators.push(temporary_creator)
      end

    end

    proposed_dataset.save!
    completion_check_message = Dataset.completion_check(proposed_dataset)
    proposed_dataset.destroy
    completion_check_message

  end

  class_methods do
    # making completion_check a class method with passed-in dataset, so it can be used by controller before save
    def completion_check(dataset)
      e_arr = []
      e_arr << "title" if dataset.title.blank?
      e_arr << "at least one creator" if dataset.creators.count < 1
      e_arr << "license" if dataset.license.blank?
      e_arr << "at least one file" unless dataset.complete_datafiles.count.positive?
      e_arr << "select primary contact from author list" unless dataset.contact
      e_arr << "identifier to import" if dataset.is_import? && !dataset.identifier
      e_arr += Dataset.license_error(dataset) || []
      e_arr += Dataset.creator_email_errors(dataset) || []
      e_arr += Dataset.duplicate_doi_error(dataset) || []
      e_arr += Dataset.duplicate_datafile_error(dataset) || []
      e_arr += Dataset.embargo_errors(dataset) || []
      e_arr += Dataset.import_date_errors(dataset) || []
      e_arr << "500 or fewer datafiles" if dataset.datafiles.count > 500
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

        next unless creator.type_of == Databank::CreatorType::PERSON

        netid = creator.email.split("@").first
        # check to see if netid is found, to prevent email system errors
        e_arr << "correct netid in email for #{creator.given_name} #{creator.family_name}" unless valid_netid(netid)
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
      first_dup = datafiles_arr.find { |e| datafiles_arr.count(e) > 1 }
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

    def valid_netid(netid)

      true

      # return false unless netid&.respond_to?(:to_str)
      #
      # netid = netid.to_str unless netid.class == String
      #
      # treebase = "ou=people,dc=ad,dc=uillinois,dc=edu"
      #
      # attrs = %w[uiucEduRegistryInactiveDate uiucEduUserEmailAddr]
      #
      # filter = "(cn=#{netid})"
      #
      # entries = Application.ldap.search(base:       treebase,
      #                                   filter:     filter,
      #                                   attributes: attrs)
      #
      # return false unless entries.length.positive?
      #
      # ldap_hash = to_ldap_hash(entries)
      #
      # return false if ldap_hash.has_key?("uiuceduregistryinactivedate")
      #
      # return false unless ldap_hash.has_key?("uiuceduuseremailaddr")
      #
      # true
    end

    # expects result of ldap search, an array of entries
    def to_ldap_hash(entries)
      ldap_hash = {}
      entries.each do |entry|
        entry.each do |attribute, values|
          ldap_hash[attribute.to_s] = values
        end
      end
      ldap_hash
    end
  end
end
