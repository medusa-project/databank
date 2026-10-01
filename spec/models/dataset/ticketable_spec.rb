require 'rails_helper'

RSpec.describe Dataset::Ticketable, type: :model do
  let(:dataset) { build(:dataset, ticket_id: 123) }
  let(:client) { TdxClient.instance }

  it 'looks up contacts through the TdxClient contacts method' do
    expect(client).to receive(:contacts).with(ticket_id: 123).and_return([{ "UID" => "person-uid" }])

    expect(dataset.current_contacts).to eq([{ "UID" => "person-uid" }])
  end

  it 'adds pre-publication changes to the specified ticket' do
    datafile = instance_double(Datafile, web_id: "file-id")
    expect(client).to receive(:add_comment).with(
      ticket_id: 123,
      comment: "Pre-publication change of type updated occurred for datafile file-id"
    )

    dataset.handle_prepub_change(ticket_id: 123, datafile: datafile, change_type: "updated")
  end
end
