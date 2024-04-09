# frozen_string_literal: true

##
# Dataset model
# @note Dataset is the primary model for the application.
# It is the core model that holds all the metadata and file information for a dataset.
# It includes methods for creating, updating, and deleting datasets.
# It also includes methods for interacting with the metadata and files of a dataset.
#
# @note Dataset includes the following modules:
# - Dataset::Complete
# - Dataset::Exportable
# - Dataset::Filterable
# - Dataset::Globusable
# - Dataset::Identifiable
# - Dataset::Indexable
# - Dataset::MessageText
# - Dataset::Publishable
# - Dataset::Recoverable
# - Dataset::Stringable
# - Dataset::Versionable
#
# @note Dataset includes the following associations:
# - audited
# - has_many :datafiles
# - has_many :version_files
# - has_many :creators
# - has_many :contributors
# - has_many :funders
# - has_many :related_materials
# - has_many :system_files
# - has_many :notes
# - has_one :share_code
# - accepts_nested_attributes_for :datafiles
# - accepts_nested_attributes_for :creators
# - accepts_nested_attributes_for :contributors
# - accepts_nested_attributes_for :funders
# - accepts_nested_attributes_for :related_materials
# - accepts_nested_attributes_for :version_files
#
# @note Dataset includes the following callbacks:
# - before_create :set_key
# - after_create :store_agreement
# - after_create :ensure_globus_ingest_dir
# - before_save :set_primary_contact
# - before_destroy :destroy_review_requests
# - before_destroy :remove_system_files
# - before_destroy :destroy_audit
# - before_destroy :remove_globus_ingest_dir
# - before_destroy :remove_from_globus_download
# - before_destroy :remove_related_reference
#
# @note Dataset includes the following validations:
# - validates :dataset_version, presence: true
#
# @note Dataset includes the following methods:
# - to_param
# - updated_date
# - ok_to_publish?
# - handle_related_materials
# - add_version_metadata_copy
# - nonversion_related_materials
# - sharing_link
# - current_share_code
# - storage_key_dirpart
# - invalid_name
# - invalid_material
# - metadata_public?
# - draft?
# - files_public?

# fileutlils is used to manipulate files and directories
require "fileutils"
require "date"
require "open-uri"
require "uri"
require "net/http"
require "securerandom"
require "action_pack"
require "openssl"

class Dataset < ApplicationRecord
  include ActiveModel::Serialization
  include Dataset::Complete
  include Dataset::Exportable
  include Dataset::Filterable
  include Dataset::Globusable
  include Dataset::Identifiable
  include Dataset::Indexable
  include Dataset::MessageText
  include Dataset::Publishable
  include Dataset::Recoverable
  include Dataset::Stringable
  include Dataset::Versionable

  audited except: %i[creator_text key complete is_test is_import updated_at embargo], allow_mass_assignment: true
  has_associated_audits

  attr_accessor :materials_related,
                :materials_cited_by,
                :num_external_relationships

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
         :description,
         :subject_text,
         :keywords,
         :identifier,
         :funder_names_fulltext,
         :grant_numbers_fulltext,
         :creator_names_fulltext,
         :filenames_fulltext,
         :datafile_extensions_fulltext,
         :publication_year

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


  ##
  # Returns the dataset key as the parameter for the dataset
  #
  # @return [String] the dataset key
  def to_param
    key
  end

  ##
  # Returns the updated date of the dataset, including consideration of nested objects
  # The nested_updated_at attribute is set when any nested objects are updated
  # @return [String] the updated date of the dataset in ISO8601 format
  def updated_date
    return updated_at.to_date.iso8601 if nested_updated_at.nil?

    [updated_at.to_date.iso8601, nested_updated_at.to_date.iso8601].max
  end

  ##
  # Returns whether the dataset is ok to publish
  # This method checks the publication state and embargo status of the dataset
  # @return [Boolean] true if the dataset is ok to publish, false otherwise
  def ok_to_publish?
    # metadata-only embargo datasets are ok to publish, which removes the embargo
    return true if (publication_state != Databank::PublicationState::DRAFT) &&
      (publication_state != Databank::PublicationState::Embargo::METADATA) &&
      (embargo == Databank::PublicationState::Embargo::METADATA)

    # draft datasets are ok to publish
    return true if publication_state == Databank::PublicationState::DRAFT

    # file-embargoed datasets are ok to publish, which removes the embargo
    return true if publication_state == Databank::PublicationState::Embargo::METADATA &&
      embargo != Databank::PublicationState::Embargo::METADATA

    false
  end

  ##
  # Handles related materials
  # This method sets the related materials, cited materials, and external relationships for the dataset
  # It sets the related materials as those that are supplemental to or supplemented by the dataset
  # It sets the cited materials as those that cite the dataset
  # It sets the external relationships as those that are not version related
  def handle_related_materials
    self.num_external_relationships = 0
    self.materials_related = self.materials_cited_by = []
    tmp_related = Set.new
    tmp_cited = Set.new
    tmp_external = Set.new
    if related_materials.count.positive?
      related_materials.each do |material|
        datacite_arr = []
        datacite_arr = material.datacite_list.split(",") if material.datacite_list && material.datacite_list != ""
        datacite_arr.each do |relationship|
          if [Databank::Relationship::NEW_VERSION_OF, Databank::Relationship::PREVIOUS_VERSION_OF].exclude?(relationship)
            tmp_external.add(material)
          end
          if [Databank::Relationship::SUPPLEMENT_TO, Databank::Relationship::SUPPLEMENTED_BY].include?(relationship)
            tmp_related.add(material)
          end
          tmp_cited.add(material) if relationship == Databank::Relationship::CITED_BY
        end
      end
    end
    self.materials_related = tmp_related.to_a
    self.materials_cited_by = tmp_cited.to_a
    self.num_external_relationships = tmp_external.count
  end

  ##
  # Adds version metadata copy
  # This method sets the metadata based on the previous version of the dataset
  # It then saves the dataset
  # @param [Dataset] previous the previous version of the dataset
  def add_version_metadata_copy(previous:)
    return true if title == previous.title

    previous_version_number = previous.dataset_version.to_i
    version_number = previous_version_number + 1
    identifier_base = previous.identifier.chop
    self.title = previous.title
    self.creator_text = previous.creator_text
    self.identifier = "#{identifier_base}#{version_number}"
    self.publisher = previous.publisher
    self.description = previous.description
    self.license = previous.license
    self.corresponding_creator_name = "researcher1"
    self.corresponding_creator_email = "researcher1@mailinator.com"
    self.keywords = previous.keywords
    self.publication_state = Databank::PublicationState::TempSuppress::VERSION
    self.curator_hold = true
    self.release_date = nil
    self.embargo = Databank::PublicationState::Embargo::NONE
    self.is_test = previous.is_test
    self.is_import = false
    self.tombstone_date = nil
    self.hold_state = Databank::PublicationState::TempSuppress::VERSION
    self.medusa_dataset_dir = nil
    self.dataset_version =  version_number.to_s
    self.suppress_changelog = false
    self.subject = previous.subject
    self.org_creators = previous.org_creators
    self.data_curation_network = false
    save
  end

  ##
  # Related materials that are not version related
  # This method returns the related materials that are not version related
  # @return [Array] the related materials that are not version related
  def nonversion_related_materials
    relationship_arr = []
    related_materials.each do |material|
      relationship_arr << material if material.nonversion_relationships.count.positive?
    end
    relationship_arr
  end

  ##
  # Sharing link
  # This method returns the sharing link for the dataset
  # It returns the sharing link if there is a current share code
  # Otherwise, it returns "N/A no current sharing link"
  # @return [String] the sharing link for the dataset
  def sharing_link
    return "N/A no current sharing link" unless current_share_code

    "#{IDB_CONFIG[:root_url_text]}/datasets/#{key}?code=#{current_share_code}"
  end

  ##
  # Current share code
  # This method returns the current share code for the dataset
  # It destroys the share code if it is older than one year
  # It returns nil if there is no share code
  # @return [String] the current share code for the dataset
  def current_share_code
    share_code.destroy if share_code && share_code.created_at < 1.year.ago

    return nil unless share_code

    share_code.code
  end

  ##
  # Storage key dirpart
  # A dirpart is the directory part of the identifier, based on identifiers mimicking filesystem paths
  # This method returns the storage key dirpart for the dataset
  # It raises an error if the dataset does not have an identifier
  # @return [String] the storage key dirpart for the dataset
  def storage_key_dirpart
    raise "Not valid for datasets without identifiers." unless identifier && identifier != ""

    "DOI-#{identifier.parameterize}"
  end

  ##
  # Invalid name
  # This method returns whether the name is invalid
  # @param [Hash] attributes the attributes of the name
  # @return [Boolean] true if the family name, given name, and institution name are blank
  # Otherwise, it returns false
  def invalid_name(attributes)
    attributes["family_name"].blank? &&
        attributes["given_name"].blank? &&
        attributes["institution_name"].blank?
  end

  ##
  # Invalid material
  # This method returns whether the material is invalid
  # @param [Hash] attributes the attributes of the material
  # @return [Boolean] true if the link and citation are blank
  # Otherwise, it returns false
  def invalid_material(attributes)
    attributes["link"].blank? && attributes["citation"].blank?
  end

  ##
  # Metadata public
  # This method returns whether the metadata is public
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
  # This method returns whether the dataset is a draft
  # @return [Boolean] true if the publication state is draft
  # Otherwise, it returns false
  def draft?
    publication_state == Databank::PublicationState::DRAFT
  end

  ##
  # This method returns whether the files are public
  # @return [Boolean] true the publication state is released and the hold state is nil or file-only suppressed
  # Otherwise, it returns false
  def files_public?
    (publication_state == Databank::PublicationState::RELEASED) &&
      ((hold_state.nil? || (hold_state == Databank::PublicationState::TempSuppress::NONE)))
  end

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

  ##
  # @return [ActiveRecord::Relation] all datasets that have public metadata
  def self.all_with_public_metadata
    Dataset.all.select(&:metadata_public?)
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
  # Add each creator as an editor
  def ensure_creator_editors
    return true unless creators.count.positive?

    creators.each(&:add_editor)
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
  # @return [Integer] the number of downloads for the dataset today
  # multiple downloads from the same IP address are counted only once
  def today_downloads
    DayFileDownload.where(dataset_key: key).uniq.pluck(:ip_address).count
  end

  ##
  # @return [Integer] the total number of downloads for the dataset
  def total_downloads
    DatasetDownloadTally.where(dataset_key: key).sum :tally
  end

  ##
  # @return [Integer] the total number of downloads for the dataset today
  def dataset_download_tallies
    DatasetDownloadTally.where(dataset_key: key)
  end

  ##
  # @param [String] request_ip the IP address of the request
  # @return [Integer] the total number of downloads for the dataset today from the same IP address
  def ip_downloaded_dataset_today(request_ip)
    filter = "ip_address = ? and dataset_key = ? and download_date = ?"
    DayFileDownload.where([filter, request_ip, key, Date.current]).count.positive?
  end

  ##
  # @return [String] the DataCite XML for the dataset
  # @note this method is used to generate the DataCite XML for the dataset
  def to_datacite_raw_xml
    Nokogiri::XML::Document.parse(to_datacite_xml).to_xml
  end

  ##
  # @return [ActiveRecord::Relation] all creators of this dataset that are individuals
  def individual_creators
    creators.where(type_of: Databank::CreatorType::PERSON)
  end

  ##
  # @return [ActiveRecord::Relation] all creators of this dataset that are institutions
  def institutional_creators
    creators.where(type_of: Databank::CreatorType::INSTITUTION)
  end

  ##
  # @return [DateTime] the release date of the dataset, if it is not a draft and it has a release_date
  def release_datetime
    release_date.to_datetime if Databank::PublicationState::DRAFT_ARRAY.exclude(publication_state) && release_date
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
  # sets the key for the dataset, generating it if it is not already set
  def set_key
    self.key ||= generate_key
  end

  ##
  # Generates a guaranteed-unique key, of which there are
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
  # @return [String] a token for use by the file upload API
  def upload_token
    current_token.identifier
  end

  ##
  # @return [String] the token for use by the file upload API
  # @note it returns the first token if there is only one token
  # @note it destroys all tokens if there are multiple tokens and creates a new token
  def current_token
    tokens = Token.where(dataset_key: self.key)
    return tokens.first if tokens.count == 1

    if tokens.count > 1
      tokens.destroy_all
      return new_token
    end
    nil
  end

  ##
  # @return [String] the token for use by the file upload API
  # @note it destroys all tokens and creates a new token
  def new_token
    Token.where(dataset_key: key).destroy_all
    Token.create(dataset_key: key, identifier: generate_auth_token)
  end

  ##
  # Sets the primary contact for the dataset
  # @note it sets the corresponding_creator_name and corresponding_creator_email
  # based on the creator that is the primary contact
  def set_primary_contact
    self.corresponding_creator_name = nil
    self.corresponding_creator_email = nil

    creators.each do |creator|
      next unless creator.is_contact?

      if creator.type_of == Databank::CreatorType::PERSON
        self.corresponding_creator_name = "#{creator.given_name} #{creator.family_name}"

      elsif creator.type_of == Databank::CreatorType::INSTITUTION
        self.corresponding_creator_name = creator.institution_name
      end
      self.corresponding_creator_email = creator.email
    end
  end

  ##
  # @return [Integer] the total number of bytes in the dataset datafiles
  def total_filesize
    total = 0

    datafiles.each do |datafile|
      total += datafile.bytestream_size
    end

    total
  end

  ##
  # @return [ActiveRecord::Relation] all datafiles that are valid
  # @note it returns datafiles that have a storage_root, storage_key, binary_size, and binary_size > 0
  def valid_datafiles
    datafiles.where.not(storage_root: [nil, ""])
             .where.not(storage_key: [nil, ""])
             .where.not(binary_size: nil)
             .where("binary_size > ?", 0)
  end

  ##
  # @return [ActiveRecord::Relation] sorted dataset datafiles that are valid
  def sorted_valid_datafiles
    basic_sorted = valid_datafiles.sort_by(&:binary_name)
    basic_sorted.select(&:readme?) | basic_sorted # put readme files on top
  end

  ##
  # @return [ActiveRecord::Relation] sorted dataset datafiles
  def sorted_datafiles
    basic_sorted = datafiles.sort_by(&:binary_name)
    basic_sorted.select(&:readme?) | basic_sorted # put readme files on top
  end

  ##
  # @return [ActiveRecord::Relation] all dataset datafiles that are complete
  def complete_datafiles
    return [] if datafiles.count.zero?

    unsorted = datafiles.select(&:upload_complete?)
    return [] if unsorted.count.zero?

    basic_sorted = unsorted.sort_by(&:binary_name)
    basic_sorted.select(&:readme?) | basic_sorted # put readme files on top
  end

  ##
  # @return [ActiveRecord::Relation] all dataset datafiles that are incomplete
  def incomplete_datafiles
    return [] if datafiles.count.zero?

    datafiles.reject(&:upload_complete?).sort_by(&:binary_name)
  end

  ##
  # @return [ActiveRecord::Relation] all Medusa Ingest records for the dataset
  def medusa_ingests
    MedusaIngest.all.select {|m| m.dataset_key == key }
  end

  ##
  # @return [Boolean] true if all datafiles in the dataset are in Medusa
  def fileset_preserved?
    # assume all are preserved unless a file is found that is not preserved

    fileset_preserved = true

    datafiles.each do |df|
      fileset_preserved = false if df.storage_root != StorageManager.instance.medusa_root.name
    end

    fileset_preserved
  end

  ##
  # @return [String] the dataset directory name, based on its identifier
  def dirname
    if identifier && identifier != ""
      "DOI-#{identifier.parameterize}"
    else
      "DRAFT-#{self.key}"
    end
  end

  ##
  # @return [String] the storage key for the deposit agreement while it is a draft
  def draft_agreement_key
    "drafts/#{self.key}/deposit_agreement.txt"
  end

  ##
  # @return [String] the storage key for the deposit agreement while it is in Medusa
  def medusa_agreement_key
    "#{dirname}/system/deposit_agreement.txt"
  end

  ##
  # send email to notify depositor that dataset version is approved
  def send_approve_version
    notification = DatabankMailer.approve_version(dataset_key: self.key)
    notification.deliver_now
  end

  ##
  # send email to notify depositor that dataset is incomplete one month after creation
  def send_incomplete_1m
    notification = DatabankMailer.dataset_incomplete_1m(self.key)
    notification.deliver_now
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

  ##
  # @return [DateTime] when the dataset was ingested, which means when it was first something other than a draft
  def ingest_datetime
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
      IDB_CONFIG[:test_datacite][:url_base]
    else
      IDB_CONFIG[:datacite][:url_base]
    end
  end

  def persistent_url
    identifier.present? ? "#{persistent_url_base}/#{identifier}" : ""
  end

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

  def contact
    contact = nil
    creators.each do |creator|
      contact = creator if creator.is_contact?
    end
    contact
  end

  def depositor
    return "unknown|Unknown Depositor" unless depositor_email

    email = depositor_email
    user = User::Shibboleth.find_by(email: email)
    return "unknown|Unknown Depositor" unless user

    "#{depositor_netid}|#{user.name}"
  end

  def depositor_netid
    return nil unless depositor_email

    user = User::Shibboleth.find_by(email: depositor_email)
    return user.email.split("@").first if user

    nil
  end

  def mine_or_not_mine(email_address)
    if email_address == depositor_email
      "mine"
    else
      "not_mine"
    end
  end

  def ind_creators_to_contributors
    individual_creators.each do |creator|
      Contributor.create(dataset_id:        creator.dataset_id,
                         given_name:        creator.given_name,
                         family_name:       creator.family_name,
                         email:             creator.email,
                         identifier:        creator.identifier,
                         identifier_scheme: creator.identifier_scheme,
                         row_order:         creator.row_order,
                         row_position:      creator.row_position,
                         type_of:           Databank::CreatorType::PERSON)
      creator.destroy
    end
  end

  def contributors_to_ind_creators
    contributors.each do |contributor|
      Creator.create(dataset_id:        contributor.dataset_id,
                     given_name:        contributor.given_name,
                     family_name:       contributor.family_name,
                     email:             contributor.email,
                     identifier:        contributor.identifier,
                     identifier_scheme: contributor.identifier_scheme,
                     row_order:         contributor.row_order,
                     row_position:      contributor.row_position,
                     type_of:           Databank::CreatorType::PERSON)
      contributor.destroy
    end
  end

  def review_requests
    ReviewRequest.where(dataset_key: self.key)
  end

  def in_pre_publication_review?
    Databank::PublicationState::DRAFT_ARRAY.include?(publication_state) && has_review_request?
  end

  def show_publish_only?
    return false unless in_pre_publication_review?

    return false unless [Databank::PublicationState::TempSuppress::NONE, nil].include?(hold_state)

    return false unless Dataset.completion_check(self) == "ok"

    true
  end

  def error_hash(message)
    {status: "error", error_text: message}
  end

  private

  def generate_auth_token
    SecureRandom.uuid.delete("-")
  end

  def destroy_audit
    associated_audits.each(&:destroy)
    audits.each(&:destroy)
  end

  def remove_system_files
    root = StorageManager.instance.draft_root
    system_files.each do |system_file|
      root.delete_content(system_file.storage_key) if root.exist?(system_file.storage_key)
    end
  end
end
