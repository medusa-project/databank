# frozen_string_literal: true

##
# This module supports the storing of datasets.
# It deals with storage locations and Medusa integration
# It is included in the Dataset model.

module Dataset::Storable
  extend ActiveSupport::Concern

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
  # @return [ActiveRecord::Relation] all Medusa Ingest records for the dataset
  def medusa_ingests
    MedusaIngest.all.select {|m| m.dataset_key == key }
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

end
