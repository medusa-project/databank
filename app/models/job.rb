# frozen_string_literal: true

##
# This module is used to namespace the Job model.
# Jobs are used in asynchronous tasks, such as import file over html.

module Job
  def self.table_name_prefix
    "job_"
  end
end