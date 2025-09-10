# frozen_string_literal: true

## Datafile::AsyncUploadable
# ------------------
# This module is included in the Datafile model to provide methods for handling the asynchronous upload of the datafile

module Datafile::AsyncUploadable
  extend ActiveSupport::Concern
  ##
  # The delayed job controlling the datafile's upload from Box or HTML, if any
  # @return [Delayed::Job] the datafile's delayed job, if any
  def job
    Delayed::Job.find_by(id: job_id) if job_id
  end

  ##
  # @return [Symbol] the status of the datafile's delayed job, if any
  # :pending if the job is waiting to be processed
  # :processing if the job is currently being processed
  # :complete if the job has been processed
  def job_status
    if job
      if job.locked_by
        :processing
      else
        :pending
      end
    else
      :complete
    end
  end

  ##
  # Destroy the datafile's delayed job, if any
  def destroy_job
    job&.destroy
  end
  ##
  # Returns whether any imports from box or html (controlled by a delayed job) are complete
  # @return [Boolean] whether any uploads controlled by delayed job are complete
  def upload_complete?
    return false if job_status == :processing

    return false if job_status == :pending

    return false if storage_root.nil?

    return false if storage_root == ""

    return false if binary_size.nil? || binary_size&.zero?

    bytestream?
  end
end