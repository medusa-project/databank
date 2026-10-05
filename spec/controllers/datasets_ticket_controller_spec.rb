require 'rails_helper'

RSpec.describe DatasetsController, type: :controller do
  render_views

  let(:user) { create(:user, :admin) }
  let(:dataset) { create(:dataset, ticket_id: nil) }
  let(:client) { TdxClient.instance }

  before do
    sign_in user
  end

  describe 'GET #ticket' do
    it 'renders an accessible association form when no ticket is found' do
      allow(client).to receive(:find_ticket_by_title).and_return(nil)

      get :ticket, params: { id: dataset.to_param }

      expect(response).to have_http_status(:ok)
      page = Nokogiri::HTML(response.body)
      expect(page.at_css("form[action='#{associate_ticket_dataset_path(dataset)}']")).to be_present
      expect(page.at_css("label[for='dataset_ticket_id']").text).to eq('TeamDynamix ticket ID')
      expect(page.at_css('#dataset_ticket_id')['aria-describedby']).to eq('ticket-id-help')
      expect(page.at_css("form[action='#{create_ticket_dataset_path(dataset)}']")).to be_present
      expect(page.at_css("label[for='ticket_description']").text).to eq('Custom description (optional)')
      expect(page.at_css('#ticket_description')['aria-describedby']).to eq('ticket-description-help')
    end

    it 'does not show the form when an existing ticket is found' do
      dataset.update!(ticket_id: 123)
      allow(client).to receive(:find_ticket_by_id).with(123).and_return('ID' => 123, 'Description' => 'Ticket description')
      allow(client).to receive(:comments).with(ticket_id: 123).and_return([])

      get :ticket, params: { id: dataset.to_param }

      expect(response).to have_http_status(:ok)
      expect(Nokogiri::HTML(response.body).at_css('#dataset_ticket_id')).to be_nil
      expect(Nokogiri::HTML(response.body).at_css('#ticket_description')).to be_nil
    end
  end

    describe 'POST #create_ticket' do
      before do
        allow(client).to receive(:find_ticket_by_title).and_return(nil)
        allow(client).to receive(:person_uid_from_email).with(email: dataset.depositor_email).and_return('depositor-uid')
      end

      it 'creates a non-consult ticket with a custom message and persists the returned ID' do
        expect(client).to receive(:create_ticket).with(
          title: "[Dataset] #{dataset.key}",
          description: "Dataset: #{dataset.databank_url}\n\nMessage: Custom description",
          form_id: TdxClient::FORM_ID,
          requestor_uid: 'depositor-uid',
          attributes: nil
        ).and_return(123)

        post :create_ticket, params: { id: dataset.to_param, ticket: { description: 'Custom description' } }

        expect(response).to redirect_to(ticket_dataset_path(dataset))
        expect(dataset.reload.ticket_id).to eq(123)
      end

      it 'uses the default description when no custom description is provided' do
        expect(client).to receive(:create_ticket).with(hash_including(
          description: "Dataset: #{dataset.databank_url}\n\nMessage: Ticket created for this dataset.",
          form_id: TdxClient::FORM_ID
        )).and_return(123)

        post :create_ticket, params: { id: dataset.to_param }

        expect(response).to redirect_to(ticket_dataset_path(dataset))
        expect(dataset.reload.ticket_id).to eq(123)
      end

      it 'preserves the description and shows an error when creation fails' do
        allow(client).to receive(:create_ticket).and_return(nil)

        post :create_ticket, params: { id: dataset.to_param, ticket: { description: 'Please help' } }

        expect(response).to have_http_status(:unprocessable_content)
        expect(dataset.reload.ticket_id).to be_nil
        page = Nokogiri::HTML(response.body)
        expect(page.at_css('#ticket-creation-error').text).to include('The ticket could not be created.')
        expect(page.at_css('#ticket_description').text.delete_prefix("\n")).to eq('Please help')
        expect(page.at_css('#ticket_description')['autofocus']).not_to be_nil
      end

      it 'does not create another ticket when an existing ticket is found' do
        allow(client).to receive(:find_ticket_by_title).and_return('ID' => 456)
        expect(client).not_to receive(:create_ticket)

        post :create_ticket, params: { id: dataset.to_param }

        expect(response).to redirect_to(ticket_dataset_path(dataset))
        expect(flash[:alert]).to eq('A ticket already exists for this dataset.')
      end

      it 'requires the same manager permission as the ticket page' do
        sign_in create(:user)
        expect(client).not_to receive(:create_ticket)

        post :create_ticket, params: { id: dataset.to_param }

        expect(response).to have_http_status(:forbidden)
        expect(dataset.reload.ticket_id).to be_nil
      end
  end

  describe 'PATCH #associate_ticket' do
    it 'verifies and persists the ticket ID without changing other dataset fields' do
      allow(client).to receive(:find_ticket_by_id).with(123).and_return('ID' => 123)
      original_title = dataset.title

      patch :associate_ticket, params: { id: dataset.to_param, dataset: { ticket_id: '123', title: 'Untrusted title' } }

      expect(response).to redirect_to(ticket_dataset_path(dataset))
      expect(dataset.reload.ticket_id).to eq(123)
      expect(dataset.title).to eq(original_title)
    end

    ['123abc', '', '0', '-1', '2147483648'].each do |invalid_id|
      it "rejects invalid ticket ID #{invalid_id.inspect} without an API request" do
        expect(client).not_to receive(:find_ticket_by_id)

        patch :associate_ticket, params: { id: dataset.to_param, dataset: { ticket_id: invalid_id } }

        expect(response).to have_http_status(:unprocessable_content)
        expect(dataset.reload.ticket_id).to be_nil
        page = Nokogiri::HTML(response.body)
        expect(page.at_css('#ticket-id-error').text).to include('Enter a valid positive ticket ID.')
        expect(page.at_css('#dataset_ticket_id')['aria-invalid']).to eq('true')
        expect(page.at_css('#dataset_ticket_id')['autofocus']).not_to be_nil
      end
    end

    it 'keeps the existing association when the submitted ticket cannot be verified' do
      dataset.update!(ticket_id: 456)
      allow(client).to receive(:find_ticket_by_id).with(123).and_return(nil)

      patch :associate_ticket, params: { id: dataset.to_param, dataset: { ticket_id: '123' } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(dataset.reload.ticket_id).to eq(456)
      expect(response.body).to include('The ticket could not be found or verified.')
      expect(Nokogiri::HTML(response.body).at_css('#dataset_ticket_id')['value']).to eq('123')
    end

    it 'denies depositors permission to associate a ticket' do
      sign_in create(:user)
      expect(client).not_to receive(:find_ticket_by_id)

      patch :associate_ticket, params: { id: dataset.to_param, dataset: { ticket_id: '123' } }

      expect(response).to have_http_status(:forbidden)
      expect(dataset.reload.ticket_id).to be_nil
    end
  end
end
