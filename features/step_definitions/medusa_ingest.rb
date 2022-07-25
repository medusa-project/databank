Then("Databank should have sent an ingest request messages to Medusa") do
  AmqpHelper::Connector[:databank].with_message(MedusaIngest.outgoing_queue) do |raw_message|
    message = JSON.parse(raw_message)
    expect(message['operation']).to eq('ingest')
  end
end