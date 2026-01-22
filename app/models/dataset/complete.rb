# frozen_string_literal: true

##
# Concern to check if a dataset is complete
# This module is included in the Dataset model.

module Dataset::Complete
  extend ActiveSupport::Concern

  # completion_check is an instance method so it can be used by controller before save
  # returns a string with error messages if dataset is incomplete
  # returns "ok" if dataset is complete
  def valid_change2published(new_params:)
    dataset = self
    return "Permanently suppressed dataset cannot be published." if dataset.PublicationState == Databank::PublicationState::PermSuppress::METADATA
 
    params = new_params
    unless params.has_key?(:dataset) && (params[:dataset]).has_key?(:identifier) && params[:dataset][:identifer] != ""
      return "invalid params: #{params}"
    end

    e_arr = []
 
    unless params[:dataset].has_key?(:embargo) && params[:dataset][:embargo] ==  Databank::PublicationState::Embargo::NONE
      e_arr << "release date" unless Dataset.key_not_empty?(params: params, key: :release_date)
    end
    e_arr << "title" unless Dataset.key_not_empty?(params: params, key: :title)
    has_creators_params = Dataset.key_not_empty?(params: params, key: :creators_attributes)
    if has_creators_params && params[:dataset][:creators_attributes].to_unsafe_hash.size.positive?
      has_primary_contact = Dataset.has_primary_contact?(creator_params: params[:dataset][:creators_attributes])
      e_arr << "select primary contact from author list" unless has_primary_contact
    else
      e_arr << "at least one creator"
    end
    e_arr << "license" unless Dataset.key_not_empty?(params: params, key: :license)
    e_arr << "at least one file" unless dataset.complete_datafiles.count.positive?
    new_identifier = params[:dataset][:identifier]
    identifier_changed = new_identifier != dataset.identifier
    e_arr << "a unique DOI" if identifier_changed && Dataset.where(identifier: new_identifier).count.positive?
    e_arr += Dataset.update_embargo_errors(params: params) || []
    e_arr << "500 or fewer datafiles" if dataset.datafiles.count > 500
    return "ok" if e_arr.empty?

    validation_error_message = "Required elements for a complete dataset missing: "
    e_arr.each_with_index do |m, i|
      validation_error_message += ", " if i.positive?
      validation_error_message += m
    end
     validation_error_message += "."
  end

  class_methods do
    # making completion_check a class method with passed-in dataset, so it can be used by controller before save
    def completion_check(dataset)
      return "na" if dataset.PublicationState == Databank::PublicationState::PermSuppress::METADATA
      e_arr = []
      e_arr << "title" if dataset.title.blank?
      e_arr << "at least one creator" if dataset.creators.count < 1
      e_arr << "license" if dataset.license.blank?
      e_arr << "at least one file" unless dataset.complete_datafiles.count.positive?
      e_arr << "remove incomplete uploads" if dataset.incomplete_datafiles.count.positive?
      e_arr << "select primary contact from author list" unless dataset.contact
      e_arr << "identifier to import" if dataset.is_import? && !dataset.identifier
      e_arr += Dataset.license_error(dataset) || []
      e_arr += Dataset.creator_email_errors(dataset) || []
      e_arr += Dataset.duplicate_doi_error(dataset) || []
      e_arr += Dataset.duplicate_datafile_error(dataset) || []
      e_arr += Dataset.embargo_errors(dataset) || []
      e_arr += Dataset.import_date_errors(dataset) || []
      e_arr += Dataset.related_material_errors(dataset) || []
      e_arr << "500 or fewer datafiles" if dataset.datafiles.count > 500
      return "ok" if e_arr.empty?

      validation_error_message = "Required elements for a complete dataset missing: "
      e_arr.each_with_index do |m, i|
        validation_error_message += ", " if i.positive?
        validation_error_message += m
      end
      validation_error_message += "."
      validation_error_message
    end

    # helper methods for completion_check
    # these methods are used to check for specific errors
    # they are called by completion_check
    # they return an array of error messages
    # if there are no errors, they return an empty array
    # if there are errors, they return an array of error messages
    # the error messages are used to build the validation_error_message
    # which is returned by completion_check

    def creator_email_errors(dataset)
      e_arr = []
      dataset.creators.each do |creator|
        return ["an email address for all creators"] unless creator.email && creator.email != ""
      end
      e_arr
    end

    def license_error(dataset)
      return nil if !dataset.license || dataset.license != "license.txt"

      has_file = false

      # check if dataset has a license file any case variation of "license.txt"
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

    def update_embargo_errors(params:)
      embargo_states = [Databank::PublicationState::Embargo::FILE, Databank::PublicationState::Embargo::METADATA]
      dataset_embargo = params[:dataset][:embargo]
      dataset_release_date = if params[:dataset].has_key?(:release_date) && params[:dataset][:release_date] != ""
                               DateTime.parse(params[:dataset][:release_date])
                             else
                               Date.current
                             end
      if dataset_embargo && embargo_states.include?(dataset_embargo) &&
        (!dataset_release_date || dataset_release_date <= Date.current)
        return ["a future release date for delayed publication (embargo) selection"]
      end

      if (!dataset_embargo || embargo_states.exclude?(dataset_embargo)) &&
        (dataset_release_date && dataset_release_date > Date.current)
        return ["a delayed publication (embargo) selection for a future release date"]
      end

      nil
    end

    def import_date_errors(dataset)
      return ["a release date for imported dataset"] if dataset.is_import && dataset.release_date.nil?

      nil
    end

    def related_material_errors(dataset)
      return [] if dataset.related_materials.count.zero?

      dataset.related_materials.each do |related_material|
        if related_material.uri_type.blank? && related_material.uri.present?
          return ["a uri_type for uri for each related material"]
        end
      end

      []
    end

    def has_primary_contact?(creator_params:)
      creator_params.each do |creator|
        return true if creator[1].has_key?(:is_contact)
      end
      false
    end

    def key_not_empty?(params:, key:)
      params.has_key?(:dataset) && params[:dataset].has_key?(key) && params[:dataset][key] != ""
    end
  end
end
