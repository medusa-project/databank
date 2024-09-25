# frozen_string_literal: true

##
# QueueManager
# @note: This class is used to manage the queue client for the application
# @note: This class is a singleton

LOCAL_ENDPOINT = "http://localhost:9324"

require "singleton"

class QueueManager
  include Singleton
  attr_accessor :sqs_client

  def initialize
    self.sqs_client = if IDB_CONFIG[:aws][:queue_mode] == "local"
                   local_client
                 else
                   cloud_client
                 end
  end

  def local_client
    Aws::SQS::Client.new(
      endpoint: LOCAL_ENDPOINT,
      region:   IDB_CONFIG[:aws][:region] #required but not used since endpoint is specified
    )
  end

  def cloud_client
    Aws::SQS::Client.new(
      region: IDB_CONFIG[:aws][:region]
    )
  end

end
