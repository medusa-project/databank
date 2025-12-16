# frozen_string_literal: true

##
# Represents a dataset in the application.
# @note Dataset is the primary model for the application.
# It is the core model that holds all the metadata information for a dataset.
#
# == Attributes
#
# * +key+ - the unique identifier for the dataset
# * +title+ - the title of the dataset
# * +creator_text+ - the list of creators of the dataset, no value is stored (could be removed from the table)
# * +identifier+ - the identifier of the dataset
# * +publisher+ - the publisher of the dataset
# * +description+ - the description of the dataset
# * +license+ - the license of the dataset
# * +depositor_name+ - the name of the depositor of the dataset
# * +depositor_email+ - the email of the depositor of the dataset
# * +complete+ - true if the dataset is complete
# * +corresponding_creator_name+ - the name of the corresponding creator of the dataset
# * +corresponding_creator_email+ - the email of the corresponding creator of the dataset
# * +keywords+ - the keywords of the dataset
# * +publication_state+ - the publication state of the dataset
# * +curator_hold+ - true if the dataset is on hold by the curator
# * +release_date+ - the release date of the dataset
# * +embargo+ - the embargo of the dataset
# * +is_test+ - true if the dataset is a test dataset
# * +is_import+ - true if the dataset is an import
# * +tombstone_date+ - the tombstone date of the dataset
# * +have_permission+ - assertion that depositor has permission to deposit this dataset, one of "yes", "no", or "unknown"
# * +removed_private+ - assertion that private files have been removed, one of "yes", "no", or "na"
# * +agree+ - assertion that the depositor agrees to the terms of deposit, one of "yes", "no", or "unknown"
# * +hold_state+ - the hold state of the dataset
# * +medusa_dataset_dir+ - the medusa dataset directory of the dataset
# * +dataset_version+ - the version of the dataset
# * +suppress_changelog+ - true if the changelog is suppressed
# * +version_comment+ - the version comment of the dataset
# * +subject+ - the subject of the dataset
# * +org_creators+ - true if the creators are organizations
# * +data_curation_network+ - true if the dataset is part of the data curation network
# * +nested_updated_at+ - the nested updated at of the dataset
#
# Includes methods for interacting with the metadata and files of a dataset.
# Methods not concerned with computed attributes are included in the Dataset modules.

require "fileutils"
require "date"
require "open-uri"
require "uri"
require "net/http"
require "action_pack"
require "openssl"

class Dataset < ApplicationRecord
  include ActiveModel::Serialization
  include Dataset::Authorable
  include Dataset::Complete
  include Dataset::Downloadable
  include Dataset::Embargoable
  include Dataset::Exportable
  include Dataset::Filesetable
  include Dataset::Filterable
  include Dataset::Globusable
  include Dataset::Identifiable
  include Dataset::Indexable
  include Dataset::MessageText
  include Dataset::Publishable
  include Dataset::Recoverable
  include Dataset::Relatable
  include Dataset::Sharable
  include Dataset::Stringable
  include Dataset::Storable
  include Dataset::Uploadable
  include Dataset::Versionable

  # audit trail is used to track changes to the dataset and to compute milestone dates such as release date
  audited except: %i[creator_text key complete is_test is_import updated_at embargo nested_updated_at], allow_mass_assignment: true
  has_associated_audits

  MIN_FILES = 1
  MAX_FILES = 10_000

  validates :dataset_version, presence: true

  has_many :datafiles, dependent: :destroy
  has_many :version_files, dependent: :destroy
  has_many :creators, dependent: :destroy
  has_many :contributors, dependent: :destroy
  has_many :funders, dependent: :destroy
  has_many :related_materials, dependent: :destroy
  has_many :system_files, dependent: :destroy
  has_many :notes, dependent: :destroy
  has_one :share_code, dependent: :destroy

  accepts_nested_attributes_for :datafiles, reject_if: :all_blank, allow_destroy: true
  accepts_nested_attributes_for :creators, reject_if: :invalid_name, allow_destroy: true
  accepts_nested_attributes_for :contributors, reject_if: :invalid_name, allow_destroy: true
  accepts_nested_attributes_for :funders, reject_if:     proc {|attributes| attributes["name"].blank? },
                                          allow_destroy: true
  accepts_nested_attributes_for :related_materials, reject_if: :invalid_material, allow_destroy: true
  accepts_nested_attributes_for :version_files, allow_destroy: true

  before_create :set_key
  after_create :store_agreement
  after_create :ensure_globus_ingest_dir
  before_save :set_primary_contact
  before_destroy :destroy_review_requests
  before_destroy :remove_system_files
  before_destroy :destroy_audit
  before_destroy :remove_globus_ingest_dir
  before_destroy :remove_from_globus_download
  before_destroy :remove_related_reference

  searchable do
    text :title,
         :identifier,
         :description,
         :subject_text,
         :keywords,
         :funder_names_fulltext,
         :grant_numbers_fulltext,
         :creator_names_fulltext,
         :filenames_fulltext,
         :datafile_extensions_fulltext,
         :publication_year

    string :identifier
    string :publication_year
    string :license_code
    string :depositor
    string :depositor_netid
    string :subject_text
    string :depositor_email
    string :visibility_code
    string :dataset_version
    string :view_emails, multiple: true
    string :draft_viewer_emails, multiple: true
    string :funder_codes, multiple: true
    string :grant_numbers, multiple: true
    string :creator_names, multiple: true
    string :filenames, multiple: true
    string :editor_emails, multiple: true
    string :datafile_extensions, multiple: true
    string :hold_state
    string :publication_state
    boolean :is_test
    boolean :is_most_recent_version
    time :ingest_datetime
    time :release_date
    time :created_at
    time :updated_at
  end

  def updated_datetime
    if draft?
      return updated_at.to_date.iso8601 if nested_updated_at.nil?

      return [updated_at.to_date.iso8601, nested_updated_at.to_date.iso8601].max
    end
    # not a draft
    changelog_array = display_changelog
    unless changelog_array
      return updated_at.to_date.iso8601 if nested_updated_at.nil?

      return [updated_at.to_date.iso8601, nested_updated_at.to_date.iso8601].max
    end

    if changelog_array.empty?
      return release_datetime.to_date.iso8601 if release_datetime > Time.zone.now

      return updated_at.to_date.iso8601 if ingest_datetime.nil?

      return ingest_datetime.to_date.iso8601
    end

    changelog_array[0][:created_at].to_date.iso8601
  end

  ##
  # @return [ActiveRecord::Relation] all datasets that have public metadata
  def self.all_with_public_metadata
    Dataset.all.select(&:metadata_public?)
  end

  ##
  # Returns the dataset key as the parameter for the dataset
  #
  # @return [String] the dataset key
  def to_param
    key
  end

  ##
  # @return [Boolean] true if the dataset meets all criteria:
  # - is not a test dataset
  # - the publication state is released, embargoed, or suppressed
  # - the hold state is nil, none, or only file-only suppressed
  # Otherwise, it returns false
  def metadata_public?
    is_test == false &&
    [Databank::PublicationState::RELEASED,
     Databank::PublicationState::Embargo::FILE,
     Databank::PublicationState::TempSuppress::FILE,
     Databank::PublicationState::PermSuppress::FILE].include?(publication_state) &&
        (hold_state.nil? ||
            [Databank::PublicationState::TempSuppress::NONE,
             Databank::PublicationState::TempSuppress::FILE,
             Databank::PublicationState::PermSuppress::FILE].include?(hold_state))
  end

  ##
  # @return [Boolean] true if the publication state is draft
  # Otherwise, it returns false
  def draft?
    publication_state == Databank::PublicationState::DRAFT
  end

  ##
  # @return [Boolean] true the publication state is released and the hold state is nil or file-only suppressed
  # Otherwise, it returns false
  def files_public?
    (publication_state == Databank::PublicationState::RELEASED) &&
      ((hold_state.nil? || (hold_state == Databank::PublicationState::TempSuppress::NONE)))
  end

  ##
  # @return [Boolean] true if the files can be downloaded in an aggregate form, for use in the UI
  # Otherwise, it returns false
  # The criteria for this is at least one of the following is true:
  # - the dataset files are all in Medusa Collection Registry (fileset_preserved?)
  # - the dataset files are all in Globus (globus_downloadable?)
  # - the dataset has a Granite link (!external_files_link.nil?)
  def aggregate_downloadable?
    fileset_preserved? || globus_downloadable? || !external_files_link.nil?
  end

  ##
  # @return [Boolean] true if the dataset has external files
  # Otherwise, it returns false
  # The criteria for this is at least one of the following is true:
  # - the dataset has external files not that is not nill, empty, or ""
  def has_external_files?
    no_external_files = external_files_note.nil? || external_files_note.empty? || external_files_note == ""
    return !no_external_files
  end

  ##
  # @return [Boolean] true if the dataset is too big to be downloaded in an aggregate form
  # Otherwise, it returns false
  # The criteria for this is at least one of the following is true:
  # - the dataset has a total file size greater than the Globus only limit from configuration
  def is_too_big?
    total_filesize.to_i > (IDB_CONFIG[:globus_only_gb].to_i * (2**30))
  end

  def has_datafiles?
    datafiles.count.positive?
  end

  ##
  # @return [Integer] the year of the publication date, defaults to the current year if no date is set
  def publication_year
    if release_date
      release_date.year || Time.now.in_time_zone.year
    else
      Time.now.in_time_zone.year
    end
  end

  ##
  # @return [DateTime] the release date of the dataset, if it is not a draft and it has a release_date
  def release_datetime
    release_date.to_datetime if Databank::PublicationState::DRAFT_ARRAY.exclude?(publication_state) && release_date
  end

  ##
  # @return [String] the name of the license for the dataset
  def license_name
    license_name = "License not selected"

    LICENSE_INFO_ARR.each do |license_info|
      if (license_info.code == license) && (license != "license.txt")
        license_name = license_info.name
      elsif license == "license.txt"
        license_name = "See license.txt file in dataset."
      end
    end

    license_name
  end

  ##
  # @return [String] url text for the dataset
  def databank_url
    "#{IDB_CONFIG[:root_url_text]}/datasets/#{key}"
  end

  ##
  # @return [DateTime] when the dataset was ingested, which means when it was first something other than a draft
  def ingest_datetime

    return DateTime.current if Rails.env.test? || Rails.env.development?

    audits.each do |change|
      next unless change.audited_changes.has_key?("publication_state")

      pub_change = change.audited_changes["publication_state"]

      return change.created_at if pub_change.class == Array && Databank::PublicationState::DRAFT_ARRAY.include?(pub_change[0])
    end
    # if we get here, there was no change in changelog from draft to another state
    nil
  end

  ##
  # @return [String] the dataset's persistent (DataCite DOI related) URL base
  def persistent_url_base
    if is_test?
      IDB_CONFIG[:datacite_test][:url_base]
    else
      IDB_CONFIG[:datacite][:url_base]
    end
  end

  ##
  # @return [String] the dataset's persistent (DataCite DOI related) URL
  def persistent_url
    identifier.present? ? "#{persistent_url_base}/#{identifier}" : ""
  end

  ##
  # @return [String] the dataset's licence code for use in UI elements
  def license_code
    if license && license != ""
      if license.include?(".txt")
        "custom"
      else
        license
      end
    else
      "unselected"
    end
  end

  ##
  # @param [String] email_address the email address (from current user) to compare to the depositor's email address
  # @return [String] a code for use in UI elements indicating whether this dataset is the current user's
  def mine_or_not_mine(email_address)
    if email_address == depositor_email
      "mine"
    else
      "not_mine"
    end
  end

  # utility method that could probably be refactored to somewhere else more central
  def error_hash(message)
    {status: "error", error_text: message}
  end

  private

  ##
  # sets the key for the dataset, generating it if it is not already set
  def set_key
    self.key ||= generate_key
  end

  ##
  # generates a guaranteed-unique key, of which there are
  # 36^KEY_LENGTH available.
  def generate_key
    proposed_key = nil

    loop do
      num_part = rand(10**7).to_s.rjust(7, "0")
      proposed_key = "#{IDB_CONFIG[:key_prefix]}-#{num_part}"
      break unless self.class.find_by(key: proposed_key)
    end
    proposed_key
  end

  ##
  # destroys all audit records associated with the dataset, only for use when the dataset is destroyed
  def destroy_audit
    associated_audits.each(&:destroy)
    audits.each(&:destroy)
  end

  ##
  # destroys all system files associated with the dataset, only for use when the dataset is destroyed
  def remove_system_files
    root = StorageManager.instance.draft_root
    system_files.each do |system_file|
      root.delete_content(system_file.storage_key) if root.exist?(system_file.storage_key)
    end
  end
end
