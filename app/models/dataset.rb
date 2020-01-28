# frozen_string_literal: true

require "fileutils"
require "date"
require "open-uri"
require "uri"
require "net/http"
require "securerandom"
require "concerns/dataset/indexable"
require 'concerns/dataset/stringable'
require 'concerns/dataset/complete'
require 'concerns/dataset/versionable'
require 'concerns/dataset/publishable'
require 'concerns/dataset/exportable'
require 'concerns/dataset/identifiable'
require 'concerns/dataset/globusable'
require "action_pack"
require "openssl"

class Dataset < ActiveRecord::Base
  include ActiveModel::Serialization
  include Recovery
  include MessageText
  include Indexable
  include Stringable
  include Complete
  include Versionable
  include Publishable
  include Exportable
  include Identifiable
  include Globusable

  audited except: %i[creator_text key complete is_test is_import updated_at embargo], allow_mass_assignment: true
  has_associated_audits

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
    string :internal_view_netids, multiple: true
    string :funder_codes, multiple: true
    string :grant_numbers, multiple: true
    string :creator_names, multiple: true
    string :filenames, multiple: true
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

  MIN_FILES = 1
  MAX_FILES = 10_000

  validates :dataset_version, presence: true

  has_many :datafiles, dependent: :destroy
  has_many :creators, dependent: :destroy
  has_many :contributors, dependent: :destroy
  has_many :funders, dependent: :destroy
  has_many :related_materials, dependent: :destroy
  has_many :system_files, dependent: :destroy

  accepts_nested_attributes_for :datafiles, reject_if: :all_blank, allow_destroy: true
  accepts_nested_attributes_for :creators, reject_if: :invalid_name, allow_destroy: true
  accepts_nested_attributes_for :contributors, reject_if: :invalid_name, allow_destroy: true
  accepts_nested_attributes_for :funders, reject_if:     proc {|attributes| attributes["name"].blank? },
                                          allow_destroy: true
  accepts_nested_attributes_for :related_materials, reject_if: :invalid_material, allow_destroy: true

  before_create :set_key
  after_create :store_agreement
  before_save :set_primary_contact
  before_destroy :remove_system_files
  before_destroy :destroy_audit

  def to_param
    key
  end

  def storage_key_dirpart
    raise "Not valid for datasets without identifiers." unless identifier && identifier != ""

    "DOI-#{identifier.parameterize}"
  end

  def invalid_name(attributes)
    attributes["family_name"].blank? &&
        attributes["given_name"].blank? &&
        attributes["institution_name"].blank?
  end

  def invalid_material(attributes)
    attributes["link"].blank? && attributes["citation"].blank?
  end

  def metadata_public?
    [Databank::PublicationState::RELEASED,
     Databank::PublicationState::Embargo::FILE,
     Databank::PublicationState::TempSuppress::FILE,
     Databank::PublicationState::PermSuppress::FILE].include?(publication_state) &&
        (hold_state.nil? || (hold_state == Databank::PublicationState::TempSuppress::NONE))
  end

  def files_public?
    Databank::PublicationState::RELEASED == publication_state &&
        (hold_state.nil? || (hold_state == Databank::PublicationState::TempSuppress::NONE))
  end

  def publication_year
    if release_date
      release_date.year || Time.now.in_time_zone.year
    else
      Time.now.in_time_zone.year
    end
  end

  def today_downloads
    DayFileDownload.where(dataset_key: key).uniq.pluck(:ip_address).count
  end

  def total_downloads
    DatasetDownloadTally.where(dataset_key: key).sum :tally
  end

  def dataset_download_tallies
    DatasetDownloadTally.where(dataset_key: key)
  end

  def ip_downloaded_dataset_today(request_ip)
    filter = "ip_address = ? and dataset_key = ? and download_date = ?"
    DayFileDownload.where([filter, request_ip, key, Date.current]).count.positive?
  end

  def to_datacite_raw_xml
    Nokogiri::XML::Document.parse(to_datacite_xml).to_xml
  end

  def individual_creators
    creators.where(type_of: Databank::CreatorType::PERSON)
  end

  def institutional_creators
    creators.where(type_of: Databank::CreatorType::INSTITUTION)
  end

  def release_datetime
    release_date.to_datetime if publication_state != Databank::PublicationState::DRAFT && release_date
  end

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

  def databank_url
    "#{IDB_CONFIG[:root_url_text]}/datasets/#{key}"
  end

  def set_key
    self.key ||= generate_key
  end

  ##
  # Generates a guaranteed-unique key, of which there are
  # 36^KEY_LENGTH available.
  #
  def generate_key
    proposed_key = nil

    loop do
      num_part = rand(10**7).to_s.rjust(7, "0")
      proposed_key = "#{IDB_CONFIG[:key_prefix]}-#{num_part}"
      break unless self.class.find_by(key: proposed_key)
    end
    proposed_key
  end

  def current_token
    tokens = Token.where(dataset_key: self.key)
    return tokens.first if tokens.count == 1

    if tokens.count > 1
      tokens.destroy_all
      return new_token
    end
    nil
  end

  def new_token
    Token.where(dataset_key: key).destroy_all
    Token.create(dataset_key: key, identifier: generate_auth_token)
  end

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

  def total_filesize
    total = 0

    datafiles.each do |datafile|
      total += datafile.bytestream_size
    end

    total
  end

  def num_external_relationships
    external_relationship_count = 0

    related_materials.each do |material|
      datacite_arr = []

      datacite_arr = material.datacite_list.split(",") if material.datacite_list && material.datacite_list != ""

      datacite_arr.each do |relationship|
        external_relationship_count += 1 if %w[IsPreviousVersionOf IsNewVersionOf].exclude?(relationship)
      end
    end

    external_relationship_count
  end

  def self.local_zip_max_size
    750_000_000
  end

  def valid_datafiles
    datafiles.where.not(storage_root: [nil, ""])
             .where.not(storage_key: [nil, ""])
             .where.not(binary_size: nil)
             .where("binary_size > ?", 0)
  end

  def sorted_datafiles
    valid_datafiles.sort_by(&:bytestream_name)
  end

  def complete_datafiles
    datafiles = []
    sorted_datafiles.each do |datafile|
      datafiles << datafile if datafile.bytestream? &&
          datafile.bytestream_name != "" &&
          datafile.job_status == :complete
    end
    datafiles
  end

  def incomplete_datafiles
    datafiles = []
    sorted_datafiles.each do |datafile|
      datafiles << datafile if datafile.job_status != :complete
    end
    datafiles
  end

  def medusa_ingests
    MedusaIngest.all.select { |m| m.dataset_key == key }
  end

  def fileset_preserved?
    # assume all are preserved unless a file is found that is not preserved

    fileset_preserved = true

    datafiles.each do |df|
      fileset_preserved = false if df.storage_root != Application.storage_manager.medusa_root.name
    end

    fileset_preserved
  end

  def dirname
    if identifier && identifier != ""
      "DOI-#{identifier.parameterize}"
    else
      "DRAFT-#{self.key}"
    end
  end

  def draft_agreement_key
    "drafts/#{self.key}/deposit_agreement.txt"
  end

  def medusa_agreement_key
    "#{dirname}/system/deposit_agreement.txt"
  end

  def send_incomplete_1m
    notification = DatabankMailer.dataset_incomplete_1m(self.key)
    notification.deliver_now
  end

  def send_embargo_approaching_1m
    notification = DatabankMailer.embargo_approaching_1m(self.key)
    notification.deliver_now
  end

  def send_embargo_approaching_1w
    notification = DatabankMailer.embargo_approaching_1w(self.key)
    notification.deliver_now
  end

  def ingest_datetime
    audits.each do |change|
      next unless change.audited_changes.has_key?("publication_state")

      pub_change = change.audited_changes["publication_state"]

      return change.created_at if pub_change.class == Array && pub_change[0] == Databank::PublicationState::DRAFT
    end
    # if we get here, there was no change in changelog from draft to another state
    nil
  end

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

    display_name = User::Shibboleth.display_name(email)
    return "#{email.split("@").first}|#{display_name}" unless display_name.nil? || display_name == "Unknown"

    user = User::Identity.find_by(email: email)
    return "unknown|Unknown Depositor" unless user

    "#{user.uid}|#{User::Identity.display_name(email)}"
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

  def in_pre_publication_review
    publication_state == Databank::PublicationState::DRAFT &&
        ((identifier && identifier != "") ||
            review_requests.count.positive?)
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
    root = Application.storage_manager.draft_root
    system_files.each do |system_file|
      root.delete_content(system_file.storage_key) if root.exist?(system_file.storage_key)
    end
  end
end
