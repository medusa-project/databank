# frozen_string_literal: true

module CloudImports
  MAX_BYTES = 150_000_000_000
  CHUNK_BYTES = 8 * 1024 * 1024
  MAX_PARTS = 10_000
  TARGET_PARTS = 8_500
  ACTIVE_STATUSES = ["queued", "importing"].freeze
  STATUSES = (ACTIVE_STATUSES + ["complete", "failed", "cancelled"]).freeze
  class Error < StandardError; end
  class RetryableError < Error; end

  def self.ensure_importable!(dataset, user, provider:)
    unless user && Ability.new(user).can?(:manage, dataset)
      raise Error, "Only curators can import from #{provider} during this pilot."
    end
    if Databank::Application.file_mode == Databank::FileMode::READ_ONLY
      raise Error, "File changes are currently disabled."
    end
    unless [Databank::PublicationState::DRAFT, Databank::PublicationState::TempSuppress::VERSION]
             .include?(dataset.publication_state)
      raise Error, "Files can only be imported into an editable draft dataset."
    end
  end

  def self.part_bytes(file_size)
    [CHUNK_BYTES, (file_size + TARGET_PARTS - 1) / TARGET_PARTS].max
  end
end
