require 'rails_helper'
require 'tmpdir'

RSpec.describe WelcomeController, type: :controller do
  describe 'POST #update_ticket_config' do
    it 'persists the selected assignee for subsequent requests' do
      Dir.mktmpdir('ticket-config') do |dir|
        path = File.join(dir, 'ticket_config', 'current_assignee.txt')
        allow(TICKET_CONFIG).to receive(:[]).and_call_original
        allow(TICKET_CONFIG).to receive(:[]).with(:current_assignee_path).and_return(path)
        allow(controller).to receive(:authorize!).with(:update_ticket_config, :welcome)

        post :update_ticket_config, params: { ticket_config: { current_assignee_netid: 'curator2' } }

        expect(response).to redirect_to('/admin')
        expect(File.read(path)).to eq('curator2')
        expect(TdxClient.current_assignee[:netid]).to eq('curator2')
      end
    end
  end
end
