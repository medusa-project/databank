# spec/controllers/datasets_controller_spec.rb
require 'rails_helper'

RSpec.describe DatasetsController, type: :controller do
  let(:user) { create(:user) }
  let(:dataset) { create(:dataset, depositor_email: user.email, depositor_name: user.name, corresponding_creator_email: user.email, corresponding_creator_name: user.name) }
  # let(:dataset) { create(:dataset, user: user, title: "Custom Title", depositor_name: user.name, depositor_email: user.email) }

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
  # describe 'POST #import_from_globus' do
  #   context 'with file object in globus import directory' do
  #     before do
  #       dataset.copy_to_globus_ingest_dir(source_root_name: 'draft', source_key: 'testf/sample_file.txt')
  #     end
  #     it 'imports dataset from globus' do
  #       post :import_from_globus, params: { id: dataset.to_param }
  #       puts response.body
  #       puts response.status
  #       expect(response).to be_successful
  #     end
  #   end
  # end

#   describe 'POST #send_to_medusa' do
#     it 'sends dataset to medusa' do
#       post :send_to_medusa, params: { id: dataset.to_param }
#       expect(response).to be_successful
#     end
#   end

#   describe 'POST #publish' do
#     it 'publishes the dataset' do
#       post :publish, params: { id: dataset.to_param }
#       expect(response).to be_successful
#     end
#   end

#   describe 'POST #send_publication_notice' do
#     it 'sends publication notice' do
#       post :send_publication_notice, params: { id: dataset.to_param }
#       expect(response).to be_successful
#     end
#   end

#   describe 'POST #validate_change2published' do
#     it 'validates change to published' do
#       post :validate_change2published, params: { id: dataset.to_param }
#       expect(response).to be_successful
#     end
#   end

#   describe 'POST #cancel_box_upload' do
#     it 'cancels box upload' do
#       post :cancel_box_upload, params: { id: dataset.to_param, web_id: 'some_web_id' }
#       expect(response).to be_successful
#     end
#   end

#   describe 'POST #share' do
#     it 'creates a share link' do
#       post :share, params: { id: dataset.to_param }
#       expect(response).to be_successful
#     end
#   end

#   describe 'POST #remove_sharing_link' do
#     it 'removes the sharing link' do
#       post :remove_sharing_link, params: { id: dataset.to_param }
#       expect(response).to be_successful
#     end
#   end

#   describe 'POST #suppress_changelog' do
#     it 'suppresses the changelog' do
#       post :suppress_changelog, params: { id: dataset.to_param }
#       expect(response).to be_successful
#     end
#   end

#   describe 'POST #unsuppress_changelog' do
#     it 'unsuppresses the changelog' do
#       post :unsuppress_changelog, params: { id: dataset.to_param }
#       expect(response).to be_successful
#     end
#   end

#   describe 'POST #temporarily_suppress_files' do
#     it 'temporarily suppresses files' do
#       post :temporarily_suppress_files, params: { id: dataset.to_param }
#       expect(response).to be_successful
#     end
#   end

#   describe 'POST #temporarily_suppress_metadata' do
#     it 'temporarily suppresses metadata' do
#       post :temporarily_suppress_metadata, params: { id: dataset.to_param }
#       expect(response).to be_successful
#     end
#   end

#   describe 'POST #unsuppress' do
#     it 'unsuppresses the dataset' do
#       post :unsuppress, params: { id: dataset.to_param }
#       expect(response).to be_successful
#     end
#   end

#   describe 'POST #permanently_suppress_files' do
#     it 'permanently suppresses files' do
#       post :permanently_suppress_files, params: { id: dataset.to_param }
#       expect(response).to be_successful
#     end
#   end

#   describe 'POST #permanently_suppress_metadata' do
#     it 'permanently suppresses metadata' do
#       post :permanently_suppress_metadata, params: { id: dataset.to_param }
#       expect(response).to be_successful
#     end
#   end

#   describe 'POST #request_review' do
#     it 'requests a review' do
#       post :request_review, params: { id: dataset.to_param }
#       expect(response).to be_successful
#     end
#   end

#   describe 'POST #version_request' do
#     it 'requests a version' do
#       post :version_request, params: { id: dataset.to_param, previous_key: dataset.to_param }
#       expect(response).to be_successful
#     end
#   end

#   describe 'POST #version_confirm' do
#     it 'confirms a version' do
#       post :version_confirm, params: { id: dataset.to_param, dataset: attributes_for(:dataset) }
#       expect(response).to be_successful
#     end
#   end

#   describe 'POST #version_to_draft' do
#     it 'changes version to draft' do
#       post :version_to_draft, params: { id: dataset.to_param }
#       expect(response).to be_successful
#     end
#   end

#   describe 'POST #draft_to_version' do
#     it 'changes draft to version' do
#       post :draft_to_version, params: { id: dataset.to_param }
#       expect(response).to be_successful
#     end
#   end
# end
# describe 'DELETE #destroy' do
#   context 'when user is signed in' do
#     it 'destroys the requested dataset' do
#       dataset = create(:dataset, depositor_email: user.email, depositor_name: user.name)
#       expect {
#         delete :destroy, params: { id: dataset.to_param }
#       }.to change(Dataset, :count).by(-1)
#     end

#     it 'redirects to the user-specific datasets list' do
#       dataset = create(:dataset, depositor_email: user.email, depositor_name: user.name)
#       delete :destroy, params: { id: dataset.to_param }
#       expect(response).to redirect_to("/datasets?q=&#{CGI.escape('depositors[]')}=#{user.username}")
#     end
#   end

#   context 'when no user is signed in' do
#     before do
#       sign_out user
#     end

#     it 'destroys the requested dataset' do
#       dataset = create(:dataset)
#       expect {
#         delete :destroy, params: { id: dataset.to_param }
#       }.to change(Dataset, :count).by(-1)
#     end

#     it 'redirects to the datasets list' do
#       dataset = create(:dataset)
#       delete :destroy, params: { id: dataset.to_param }
#       expect(response).to redirect_to(datasets_url)
#     end
#   end
end
