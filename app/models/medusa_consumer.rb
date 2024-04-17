# frozen_string_literal: true

##
# MedusaConsumer
# --------------
# Custom consumer class for handling messages from Medusa via RabbitMQ
class MedusaConsumer < Bunny::Consumer

  ##
  # cancelled?
  # @return [Boolean] true if the consumer has been cancelled
  def cancelled?
    @cancelled
  end

  ##
  # handle_cancellation
  # @param _ [Bunny::DeliveryInfo] delivery info
  def handle_cancellation(_)
    @cancelled = true
  end
end
