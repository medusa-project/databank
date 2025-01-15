# spec/controllers/datasets_controller_spec.rb
require 'rails_helper'

RSpec.describe DatasetsController, type: :controller do
  fixtures :users, :datasets, :datafiles
  let(:user) { users(:researcher1) }
  let(:valid_attributes) { { depositor_email: user.email, depositor_name: user.name, corresponding_creator_email: user.email, corresponding_creator_name: user.name } }
  let!(:dataset) { create(:dataset, valid_attributes) }

  before do
    sign_in user
  end

  describe 'GET #index' do
    it 'returns a success response' do
      get :index
      expect(response).to be_successful
    end
  end

  describe 'GET #show' do
    it 'returns a success response' do
      get :show, params: { id: dataset.to_param }
      expect(response).to be_successful
    end
  end

  describe 'GET #new' do
    it 'returns a success response' do
      get :new
      expect(response).to be_successful
    end
  end

  describe 'GET #edit' do
    it 'returns a success response' do
      get :edit, params: { id: dataset.to_param }
      expect(response).to be_successful
    end
  end

  describe 'POST #create' do
    context 'with valid params' do
      it 'creates a new Dataset' do
        expect {
          post :create, params: { dataset: attributes_for(:dataset) }
        }.to change(Dataset, :count).by(1)
      end

      it 'redirects to the created dataset' do
        post :create, params: { dataset: attributes_for(:dataset) }
        expect(response).to redirect_to(edit_dataset_path(Dataset.last))
      end
    end

    context 'with invalid params' do
      it 'returns a success response (i.e., to display the "new" template)' do
        post :create, params: { dataset: { dataset_version: nil } }
        expect(response).to be_successful
      end
    end
  end

  describe 'PUT #update' do
    context 'with valid params' do
      let(:new_attributes) {
        { title: 'New Title' }
      }

      it 'updates the requested dataset' do
        put :update, params: { id: dataset.to_param, dataset: new_attributes }
        dataset.reload
        expect(dataset.title).to eq('New Title')
      end

      it 'redirects to the dataset' do
        put :update, params: { id: dataset.to_param, dataset: new_attributes }
        expect(response).to redirect_to(dataset_path(dataset))
      end
    end

    context 'with invalid params' do
      it 'returns a success response (i.e., to display the "edit" template)' do
        put :update, params: { id: dataset.to_param, dataset: attributes_for(:dataset, dataset_version: nil) }
        expect(response).to be_successful
      end
    end
  end

  describe 'POST #copy_version_files' do
    it 'initiates file copy process' do
      post :copy_version_files, params: { id: dataset.to_param, dataset: { version_files_attributes: { '0' => { selected: true } } } }
      expect(response).to be_successful
    end
  end

  # assumes that the to be copied to the globus ingest directory is already in the draft directory, setup during load fixtures
  describe 'POST #import_from_globus' do
    context 'with file object in globus import directory' do
      before do
        dataset.copy_to_globus_ingest_dir(source_root_name: 'draft', source_key: 'testf/sample_file.txt')
      end
      after do
        dataset.delete_from_globus_ingest_dir(storage_key: 'testf/sample_file.txt')
      end
      it 'imports dataset from globus' do
        post :import_from_globus, params: { id: dataset.to_param }
        expect(response).to be_successful
      end
    end
  end

  describe 'POST #publish' do
    context 'with valid draft dataset, valid logged_in user' do 
      it 'publishes the dataset' do        
        # assumes that the dataset exists and is in draft state, setup during load fixtures
        draft1 = Dataset.find_by(key: "TESTIDB-1423696")
        # visit the dataset show page
        get :show, params: { id: draft1.to_param }
        expect(response).to be_successful
        draft1.store_agreement
        post :publish, params: { id: draft1.to_param }
        expect(response.status).to eq(302)
      end
      after do
        draft1 = Dataset.find_by(key: "TESTIDB-1423696")
        draft1.publication_state = Databank::PublicationState::DRAFT
        draft1.identifier = ""
        draft1.save
        expect(draft1.publication_state).to eq(Databank::PublicationState::DRAFT)
        expect(draft1.identifier).to eq("")
      end
    end
  end

  describe 'POST #validate_change2published' do
    it 'validates change to published' do
      post :validate_change2published, params: { id: dataset.to_param }
      expect(response).to be_successful
    end
  end

  describe 'POST #share' do
    it 'creates a share link' do
      draft1 = Dataset.find_by(key: "TESTIDB-1423696")
      post :share, params: { id: draft1.to_param }
      expect(response.status).to eq(302)
    end
  end

  describe 'POST #remove_sharing_link' do
    it 'removes the sharing link' do
      post :remove_sharing_link, params: { id: dataset.to_param }
      expect(response.status).to eq(302)
    end
  end

  describe 'POST #suppress_changelog' do
    it 'suppresses the changelog' do
      sign_in users(:curator1)
      post :suppress_changelog, params: { id: dataset.to_param }
      expect(response.status).to eq(302)
    end
  end

  describe 'POST #unsuppress_changelog' do
    it 'unsuppresses the changelog' do
      sign_in users(:curator1)
      post :unsuppress_changelog, params: { id: dataset.to_param }
      expect(response.status).to eq(302)
    end
  end

  describe 'POST #temporarily_suppress_files' do
    it 'temporarily suppresses files' do
      sign_in users(:curator1)
      post :temporarily_suppress_files, params: { id: dataset.to_param }
      expect(response.status).to eq(302)
    end
  end

  describe 'POST #temporarily_suppress_metadata' do
    it 'temporarily suppresses metadata' do
      sign_in users(:curator1)
      post :temporarily_suppress_metadata, params: { id: dataset.to_param }
      expect(response.status).to eq(302)
    end
  end

  describe 'POST #unsuppress' do
    it 'unsuppresses the dataset' do
      sign_in users(:curator1)
      post :unsuppress, params: { id: dataset.to_param }
      expect(response.status).to eq(302)
    end
  end

  describe 'POST #request_review' do
    it 'requests a review' do
      post :request_review, params: { id: dataset.to_param }
      expect(response).to be_successful
    end
  end

  describe 'GET #get_new_token' do
    it 'gets a new token' do
      get :get_new_token, params: { id: dataset.to_param }
      expect(response).to be_successful
    end
  end

  describe 'GET #get_current_token' do 
    it 'gets the current token' do
      get :get_current_token, params: { id: dataset.to_param }
      expect(response).to be_successful
    end
  end

  describe 'GET #download_endNote_XML' do
    it 'downloads the endNote XML' do
      released1 = Dataset.find_by(key: "TESTIDB-5920542")
      get :download_endNote_XML, params: { id: released1.to_param }
      expect(response).to be_successful
    end
  end

  describe 'GET #confirmation_message' do
    context 'with a dataset that has been published' do
      it 'returns a success response' do
        released1 = Dataset.find_by(key: "TESTIDB-5920542")
        get :confirmation_message, params: { id: released1.to_param }
        expect(response).to be_successful
      end
      it 'returns a success response with JSON format' do
        released1 = Dataset.find_by(key: "TESTIDB-5920542")
        get :confirmation_message, params: { id: released1.to_param }, format: :json
        expect(response).to have_http_status(:ok)
        expect(response.content_type).to eq('application/json; charset=utf-8')
      end
      it 'returns a message that includes specific text' do
        released1 = Dataset.find_by(key: "TESTIDB-5920542")
        get :confirmation_message, params: { id: released1.to_param }
        expect(response.body).to include('This action will make your updates to your dataset record')
      end
    end
    context 'with a dataset that has not been published' do
      it 'returns a success response' do
        draft1 = Dataset.find_by(key: "TESTIDB-1423696")
        get :confirmation_message, params: { id: draft1.to_param }
        expect(response).to be_successful
      end
      it 'returns a success response with JSON format' do
        draft1 = Dataset.find_by(key: "TESTIDB-1423696")
        get :confirmation_message, params: { id: draft1.to_param }, format: :json
        expect(response).to have_http_status(:ok)
        expect(response.content_type).to eq('application/json; charset=utf-8')
      end
      it 'returns a message that includes specific text' do
        draft1 = Dataset.find_by(key: "TESTIDB-1423696")
        get :confirmation_message, params: { id: draft1.to_param }
        expect(response.body).to include('This action will make your dataset')
        expect(response.body).to include('visible through search engines')
      end
    end
    context 'with a dataset that is file embargoed' do
      it 'returns a success response' do
        embargoed1 = Dataset.find_by(key: "TESTIDB-5720850")
        get :confirmation_message, params: { id: embargoed1.to_param }
        expect(response).to be_successful
      end
      it 'returns a success response with JSON format' do
        embargoed1 = Dataset.find_by(key: "TESTIDB-5720850")
        get :confirmation_message, params: { id: embargoed1.to_param }, format: :json
        expect(response).to have_http_status(:ok)
        expect(response.content_type).to eq('application/json; charset=utf-8')
      end
      it 'returns a message that includes specific text' do
        embargoed1 = Dataset.find_by(key: "TESTIDB-5720850")
        get :confirmation_message, params: { id: embargoed1.to_param }
        expect(response.body).to include('This action will make your updates to your dataset')
        expect(response.body).to include('visible through search engines')
      end
    end
    context 'with a new embargo state param of Databank::PublicationState::Embargo::FILE' do
      it 'returns a success response with JSON format' do
        embargoed1 = Dataset.find_by(key: "TESTIDB-5720850")
        get :confirmation_message, params: { id: embargoed1.to_param, new_embargo_state: Databank::PublicationState::Embargo::FILE }, format: :json
        expect(response).to have_http_status(:ok)
        expect(response.content_type).to eq('application/json; charset=utf-8')
      end
      it 'returns a message that includes specific text' do
        embargoed1 = Dataset.find_by(key: "TESTIDB-5720850")
        get :confirmation_message, params: { id: embargoed1.to_param, new_embargo_state: Databank::PublicationState::Embargo::FILE }
        expect(response).to be_successful
        expect(response.body).to include('This action will make your updates to your dataset')
        expect(response.body).to include('visible through search engines')
      end
    end
    context 'with a new embargo state param of Databank::PublicationState::Embargo::METADATA' do
      it 'returns a success response with JSON format' do
        released1 = Dataset.find_by(key: "TESTIDB-5920542")
        get :confirmation_message, params: { id: released1.to_param, new_embargo_state: Databank::PublicationState::Embargo::METADATA, release_date: Date.current + 1.month }, format: :json
        puts "metadata embargoed new param test"
        puts response.body
        expect(response).to have_http_status(:ok)
        expect(response.content_type).to eq('application/json; charset=utf-8')
      end
      it 'returns a message that includes specific text' do
        released1 = Dataset.find_by(key: "TESTIDB-5920542")
        get :confirmation_message, params: { id: released1.to_param, new_embargo_state: Databank::PublicationState::Embargo::METADATA, release_date: Date.current + 1.month }
        expect(response).to be_successful
        expect(response.body).to include('This action will remove your dataset')
        expect(response.body).to include('your dataset is not visible')
      end
    end
    context 'with an invalid new embargo state param' do
      it 'returns a success response with JSON format' do
        embargoed1 = Dataset.find_by(key: "TESTIDB-5720850")
        get :confirmation_message, params: { id: embargoed1.to_param, new_embargo_state: 'invalid' }, format: :json
        expect(response).to have_http_status(:ok)
        expect(response.content_type).to eq('application/json; charset=utf-8')
      end
      it 'returns a message that includes specific text' do
        embargoed1 = Dataset.find_by(key: "TESTIDB-5720850")
        get :confirmation_message, params: { id: embargoed1.to_param, new_embargo_state: 'invalid' }
        expect(response).to be_successful
        expect(response.body).to include('This action will make your updates to your dataset')
        expect(response.body).to include('visible through search engines')
      end
    end
  end

  describe 'DELETE #destroy' do
    context 'when the dataset exists' do
      it 'destroys the requested dataset' do
        dataset = Dataset.create! valid_attributes
        expect {
          delete :destroy, params: { id: dataset.to_param }
        }.to change(Dataset, :count).by(-1)
      end
    end
  end

  describe 'POST #update_permissions' do
    let(:reviewer_emails) { ['researcher2@mailinator.com'] }
    let(:editor_emails) { ['researcher3@mailinator.com'] }

    before do
      sign_in users(:curator1)
      allow(UserAbility).to receive(:update_permissions)
    end

    context 'with valid params' do
      it 'updates the permissions' do
        post :update_permissions, params: { id: dataset.to_param, reviewer_emails: reviewer_emails, editor_emails: editor_emails }
        expect(UserAbility).to have_received(:update_permissions).with(dataset.key, reviewer_emails, editor_emails)
        expect(response).to redirect_to(dataset_path(dataset.key))
        expect(flash[:notice]).to eq('Permissions updated.')
      end

      it 'returns a success response with JSON format' do
        post :update_permissions, params: { id: dataset.to_param, reviewer_emails: reviewer_emails, editor_emails: editor_emails }, format: :json
        expect(response).to have_http_status(:ok)
        expect(response.content_type).to eq('application/json; charset=utf-8')
      end
    end

    context 'with invalid params' do
      before do
        allow_any_instance_of(Dataset).to receive(:save).and_return(false)
      end

      it 'redirects to the dataset with an alert' do
        post :update_permissions, params: { id: dataset.to_param, reviewer_emails: reviewer_emails, editor_emails: editor_emails }
        expect(response).to redirect_to(dataset_path(dataset.key))
        expect(flash[:alert]).to eq('Error attempting to update permissions.')
      end

      it 'returns an unprocessable entity response with JSON format' do
        post :update_permissions, params: { id: dataset.to_param, reviewer_emails: reviewer_emails, editor_emails: editor_emails }, format: :json
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.content_type).to eq('application/json; charset=utf-8')
      end
    end
  end
end