# frozen_string_literal: true

##
# Custom consumer class for handling messages from Medusa via RabbitMQ
class MedusaConsumer < Bunny::Consumer

  ##
  # @return [Boolean] true if the consumer has been cancelled
  def cancelled?
    @cancelled
  end

  ##
  # handle the cancellation of the consumer
  # @param _ [Bunny::DeliveryInfo] delivery info
  def handle_cancellation(_)
    @cancelled = true
  end
end
