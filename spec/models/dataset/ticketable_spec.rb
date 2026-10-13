require 'rails_helper'

RSpec.describe Dataset::Ticketable, type: :model do
  let(:dataset) { build(:dataset, ticket_id: 123) }
  let(:client) { TdxClient.instance }

  it 'creates a consult ticket with public form and attribute IDs and saves its ID' do
    dataset.ticket_id = nil
    expect(client).to receive(:person_uid_from_email).with(email: dataset.depositor_email).and_return('depositor-uid')
    expect(client).to receive(:create_ticket).with(
      title: "[Dataset] #{dataset.key}",
      description: "Dataset: #{dataset.databank_url}\n\nMessage: Review requested",
      form_id: TICKET_CONFIG[:consult_form_id],
      requestor_uid: 'depositor-uid',
      attributes: [{ ID: TICKET_CONFIG[:consult_attribute_id], Value: dataset.key, ValueText: dataset.key }]
    ).and_return(456)
    expect(dataset).to receive(:update!).with(ticket_id: 456)

    expect(dataset.create_consult_ticket(msg: 'Review requested')).to eq(456)
  end

  it 'looks up contacts through the TdxClient contacts method' do
    expect(client).to receive(:contacts).with(ticket_id: 123).and_return([{ "UID" => "person-uid" }])

    expect(dataset.current_contacts).to eq([{ "UID" => "person-uid" }])
  end

  it 'marks the latest review modified when a file is added during pre-publication review' do
    allow_any_instance_of(ReviewRequest).to receive(:create_ticket_review_request)
    earlier_review = create(:review_request, dataset: dataset, created_at: 2.days.ago)
    latest_review = create(:review_request, dataset: dataset, created_at: 1.day.ago)
    datafile = instance_double(Datafile, web_id: "file-id", binary_name: "added.txt")
    expect(client).to receive(:add_comment).with(
      ticket_id: 123,
      comment: "Datafile added web_id file-id, name: added.txt.",
      notify: nil
    )

    expect(dataset.in_pre_publication_review?).to be true
    dataset.handle_prepub_file_change(datafile: datafile, change_type: "added")

    expect(latest_review.reload.modified).to be true
    expect(earlier_review.reload.modified).to be false
  end

  it 'marks the latest review modified when a file is removed during pre-publication review' do
    allow_any_instance_of(ReviewRequest).to receive(:create_ticket_review_request)
    earlier_review = create(:review_request, dataset: dataset, created_at: 2.days.ago)
    latest_review = create(:review_request, dataset: dataset, created_at: 1.day.ago)
    datafile = instance_double(Datafile, web_id: "file-id", binary_name: "removed.txt")
    expect(client).to receive(:add_comment).with(
      ticket_id: 123,
      comment: "Datafile removed web_id file-id, name: removed.txt.",
      notify: nil
    )

    expect(dataset.in_pre_publication_review?).to be true
    dataset.handle_prepub_file_change(datafile: datafile, change_type: "removed")

    expect(latest_review.reload.modified).to be true
    expect(earlier_review.reload.modified).to be false
  end

  it 'marks the latest review modified when metadata changes during pre-publication review' do
    allow_any_instance_of(ReviewRequest).to receive(:create_ticket_review_request)
    earlier_review = create(:review_request, dataset: dataset, created_at: 2.days.ago)
    latest_review = create(:review_request, dataset: dataset, created_at: 1.day.ago)
    expect(client).to receive(:add_comment).with(
      ticket_id: 123,
      comment: "Change of type metadata occurred: title changed.",
      notify: nil
    )

    expect(dataset.in_pre_publication_review?).to be true
    dataset.handle_prepub_metadata_change(change_type: "metadata", details: "title changed")

    expect(latest_review.reload.modified).to be true
    expect(earlier_review.reload.modified).to be false
  end
end
