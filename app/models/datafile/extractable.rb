# frozen_string_literal: true

##
# Datafile::Extractable
# ------------------
# This module is included in the Datafile model to provide methods for handling the extraction of content metadata
# from an archive-type datafile
# This module is included in the Datafile model.

module Datafile::Extractable
  extend ActiveSupport::Concern

  ##
  # Initiate a task to process the datafile for inspecting and recording its contents
  # To be used for archive type files, such as .zip, .tar, .gz, .7z, etc.
  def initiate_processing_task
    return nil if Rails.env.test?

    extractor_task = ExtractorTask.create(web_id:)
    update_attribute(:task_id, extractor_task.id) if extractor_task
  end

  ##
  # Returns the datafile's ExtractorTask, if any
  def extractor_task
    return nil unless task_id

    ExtractorTask.find_by(id: task_id)
  end

end