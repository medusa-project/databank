require 'rails_helper'

RSpec.describe NotesController, type: :controller do
  let(:admin) { create(:user, :admin) }
  let!(:dataset) { create(:dataset) }
  let!(:note) { Note.create!(dataset: dataset, body: 'Initial note', author: 'Curator') }

  before do
    sign_in admin
  end

  describe 'GET #index' do
    it 'returns success and assigns dataset notes from dataset_id key' do
      get :index, params: { dataset_id: dataset.key }

      expect(response).to be_successful
      expect(assigns(:dataset)).to eq(dataset)
      expect(assigns(:notes)).to contain_exactly(note)
    end

    it 'returns not found when dataset_id key does not resolve a dataset' do
      get :index, params: { dataset_id: 'missing-dataset' }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET #show' do
    it 'returns success and resolves dataset from note id' do
      get :show, params: { dataset_id: dataset.key, id: note.id }

      expect(response).to be_successful
      expect(assigns(:note)).to eq(note)
      expect(assigns(:dataset)).to eq(dataset)
    end
  end

  describe 'GET #new' do
    it 'returns success and builds a dataset note' do
      get :new, params: { dataset_id: dataset.key }

      expect(response).to be_successful
      expect(assigns(:note)).to be_a_new(Note)
      expect(assigns(:note).dataset).to eq(dataset)
    end
  end

  describe 'POST #create' do
    it 'creates a note when dataset_id is nested under note params' do
      expect {
        post :create, params: {
          dataset_id: dataset.key,
          note: {
            dataset_id: dataset.id,
            body: 'Created body',
            author: 'Curator Two'
          }
        }
      }.to change(Note, :count).by(1)

      expect(response).to redirect_to(dataset_notes_path(dataset))
      expect(Note.last.body).to eq('Created body')
    end

    it 'renders new when save fails' do
      allow_any_instance_of(Note).to receive(:save).and_return(false)

      post :create, params: {
        dataset_id: dataset.key,
        note: {
          dataset_id: dataset.id,
          body: 'Created body',
          author: 'Curator Two'
        }
      }

      expect(response).to render_template(:new)
    end

    it 'resolves dataset when note keys arrive as strings' do
      post :create, params: {
        dataset_id: dataset.key,
        'note' => {
          'dataset_id' => dataset.id,
          'body' => 'String body',
          'author' => 'Curator Three'
        }
      }

      expect(response).to redirect_to(dataset_notes_path(dataset))
      expect(Note.last.body).to eq('String body')
    end
  end

  describe 'PUT #update' do
    it 'updates the note and redirects to dataset notes path' do
      put :update, params: {
        dataset_id: dataset.key,
        id: note.id,
        note: {
          body: 'Updated body',
          author: 'Curator Updated'
        }
      }

      expect(response).to redirect_to(dataset_notes_path(dataset))
      expect(note.reload.body).to eq('Updated body')
    end

    it 'renders edit when update fails' do
      allow_any_instance_of(Note).to receive(:update).and_return(false)

      put :update, params: {
        dataset_id: dataset.key,
        id: note.id,
        note: {
          body: 'Updated body',
          author: 'Curator Updated'
        }
      }

      expect(response).to render_template(:edit)
    end
  end

  describe 'DELETE #destroy' do
    it 'destroys the note and redirects to dataset notes path' do
      delete :destroy, params: { dataset_id: dataset.key, id: note.id }

      expect(response).to redirect_to(dataset_notes_path(dataset))
      expect(Note.where(id: note.id)).to be_empty
    end
  end
end