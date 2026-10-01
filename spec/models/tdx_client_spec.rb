require 'rails_helper'
require 'tmpdir'

RSpec.describe TdxClient, type: :model do
  let(:client) { described_class.instance }
  let(:url) { "#{TICKET_CONFIG[:base_url].to_s.chomp('/').sub(%r{/api\z}, '')}/api/#{TICKET_CONFIG[:app_id]}/tickets/123" }

  describe '.update_config' do
    it 'persists a changed assignee in a private directory for later reads' do
      Dir.mktmpdir('ticket-config') do |dir|
        path = File.join(dir, 'ticket_config', 'current_assignee.txt')
        allow(TICKET_CONFIG).to receive(:[]).and_call_original
        allow(TICKET_CONFIG).to receive(:[]).with(:current_assignee_path).and_return(path)

        expect(described_class.update_config('current_assignee_netid' => 'curator2')).to be true
        expect(File.read(path)).to eq('curator2')
        expect(described_class.current_assignee[:netid]).to eq('curator2')

        expect(described_class.update_config('current_assignee_netid' => 'curator3')).to be true
        expect(described_class.current_assignee[:netid]).to eq('curator3')
        expect(described_class.update_config('current_assignee_netid' => 'unknown')).to be false
        expect(File.read(path)).to eq('curator3')
      end
    end
  end

  describe '#update_ticket' do
    it 'does not send a patch when no updates are supplied' do
      expect(client).not_to receive(:patch_json)

      expect(client.update_ticket(ticket_id: 123)).to be_nil
    end

    it 'only patches supplied values, including empty strings' do
      expect(client).to receive(:patch_json).with(
        url: url,
        body: [
          { op: "replace", path: "/Title", value: "" },
          { op: "replace", path: "/ResponsibleUID", value: "person-uid" }
        ],
        error_message: "TeamDynamix ticket update failed",
        notify_new_responsible: true
      ).and_return(:updated)

      expect(client.update_ticket(ticket_id: 123, title: "", assignee_uid: "person-uid",
                                  notify_new_responsible: true)).to eq(:updated)
    end

    it 'patches description alone without requesting a notification' do
      expect(client).to receive(:patch_json).with(
        url: url,
        body: [{ op: "replace", path: "/Description", value: "New description" }],
        error_message: "TeamDynamix ticket update failed",
        notify_new_responsible: false
      )

      client.update_ticket(ticket_id: 123, description: "New description")
    end
  end

  describe '#assign_ticket' do
    it 'patches only the responsible UID and requests a notification' do
      expect(client).to receive(:patch_json).with(
        url: url,
        body: [{ op: "replace", path: "/ResponsibleUID", value: "person-uid" }],
        error_message: "Assigning ticket to person-uid",
        notify_new_responsible: true
      ).and_return(:updated)

      expect(client.assign_ticket(ticket_id: 123, assignee_uid: "person-uid")).to eq(:updated)
    end

    it 'uses the current assignee UID by default' do
      allow(described_class).to receive(:current_assignee).and_return(uid: "default-uid", netid: "netid")
      expect(client).to receive(:update_ticket).with(
        ticket_id: 123, assignee_uid: "default-uid", notify_new_responsible: true,
        error_message: "Assigning ticket to default-uid"
      )

      client.assign_ticket(ticket_id: 123)
    end
  end

  describe '#create_ticket' do
    it 'sends the assignee UID and returns the created ticket ID' do
      allow(described_class).to receive(:current_assignee).and_return(uid: "default-uid", netid: "netid")
      expect(client).to receive(:post_json).with(
        url: url.delete_suffix("/123"),
        body: hash_including(Title: "Title", Description: "Description", ResponsibleUID: "default-uid"),
        error_message: "TeamDynamix ticket creation failed"
      ).and_return("ID" => 123)

      expect(client.create_ticket(title: "Title", description: "Description")).to eq(123)
    end
  end

  describe '#find_ticket_by_title' do
    it 'uses the keyword-based JSON request and finds an exact match' do
      expect(client).to receive(:post_json).with(
        url: "#{url.delete_suffix('/123')}/search",
        body: { SearchText: "Title" },
        error_message: "TeamDynamix ticket search failed"
      ).and_return([{ "Title" => "Other" }, { "Title" => "Title" }])

      expect(client.find_ticket_by_title("Title")).to eq("Title" => "Title")
    end
  end

  describe '#add_comment' do
    it 'posts comment and notification recipients with keyword arguments' do
      expect(client).to receive(:post_json).with(
        url: "#{url}/feed",
        body: { Comments: "Message", Notify: ["person@example.com"] },
        error_message: "TeamDynamix add comment failed"
      )

      expect(client.add_comment(ticket_id: 123, comment: "Message",
                                notify: ["person@example.com"])).to eq(123)
    end
  end
end
