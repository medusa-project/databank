# frozen_string_literal: true

##
# ContainerManager
# This class is a singleton that manages the ECS client
# It is used by ExtractorTask to manage the ECS client

require "singleton"

class ContainerManager
  include Singleton
  attr_accessor :ecs_client

  def initialize
    self.ecs_client = cloud_client
  end

  def cloud_client
    Aws::ECS::Client.new(region: "us-east-2")
  end

end
