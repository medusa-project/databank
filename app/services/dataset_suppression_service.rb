# frozen_string_literal: true

class DatasetSuppressionService
  Result = Struct.new(:saved, :doi_updated, :integration_error, keyword_init: true) do
    def integration_failed?
      !integration_error.nil?
    end
  end

  def initialize(dataset)
    @dataset = dataset
  end

  def suppress_changelog
    @dataset.suppress_changelog = true
    save
  end

  def unsuppress_changelog
    @dataset.suppress_changelog = false
    save
  end

  def temporarily_suppress_files
    @dataset.hold_state = Databank::PublicationState::TempSuppress::FILE
    save
  end

  def temporarily_suppress_metadata
    @dataset.hold_state = Databank::PublicationState::TempSuppress::METADATA
    return Result.new(saved: false) unless @dataset.save

    Result.new(saved: true, doi_updated: !!@dataset.update_doi)
  end

  def unsuppress
    @dataset.hold_state = Databank::PublicationState::TempSuppress::NONE
    return Result.new(saved: false) unless @dataset.save

    Result.new(saved: true, doi_updated: !!@dataset.update_doi)
  end

  def permanently_suppress_files
    @dataset.publication_state = Databank::PublicationState::PermSuppress::FILE
    @dataset.hold_state = Databank::PublicationState::PermSuppress::FILE
    @dataset.embargo = Databank::PublicationState::Embargo::NONE
    @dataset.tombstone_date = Date.current

    begin
      @dataset.remove_from_globus_download
      Result.new(saved: @dataset.save)
    rescue StandardError => e
      Rails.logger.error("Failed to remove dataset #{@dataset.key} from Globus Download: #{e.class}: #{e.message}")
      @dataset.save
      Result.new(saved: false, integration_error: e)
    end
  end

  def suppress_review
    @dataset.hold_state = Databank::PublicationState::TempSuppress::VERSION
    save
  end

  def unsuppress_review
    @dataset.hold_state = Databank::PublicationState::TempSuppress::NONE
    return Result.new(saved: false) unless @dataset.save

    @dataset.send_approve_version
    Result.new(saved: true)
  end

  def permanently_suppress_metadata
    @dataset.hold_state = Databank::PublicationState::PermSuppress::METADATA
    @dataset.publication_state = Databank::PublicationState::PermSuppress::METADATA
    @dataset.tombstone_date = Date.current.iso8601
    @dataset.embargo = Databank::PublicationState::Embargo::NONE
    @dataset.save

    begin
      @dataset.hide_doi
      @dataset.remove_from_globus_download
      Result.new(saved: @dataset.save)
    rescue StandardError => e
      Rails.logger.error("Failed to suppress dataset #{@dataset.key} in DataCite or Globus: #{e.class}: #{e.message}")
      @dataset.save
      Result.new(saved: false, integration_error: e)
    end
  end

  private

  def save
    Result.new(saved: @dataset.save)
  end
end
