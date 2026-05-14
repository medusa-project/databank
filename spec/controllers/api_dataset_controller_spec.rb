require 'rails_helper'
require 'ostruct'
require 'tempfile'

RSpec.describe ApiDatasetController, type: :controller do
  let(:draft_dataset) do
    instance_double(
      Dataset,
      id: 101,
      key: 'TESTIDB-DRAFT',
      publication_state: Databank::PublicationState::DRAFT
    )
  end
  let(:released_dataset) do
    instance_double(
      Dataset,
      id: 202,
      key: 'TESTIDB-RELEASED',
      publication_state: Databank::PublicationState::RELEASED
    )
  end
  let(:draft_root) { double('draft_root', name: 'draft-root') }
  let(:storage_manager) { double('storage_manager', draft_root: draft_root) }

  def fake_datafile(save_raises: nil)
    file = OpenStruct.new
    file.define_singleton_method(:generate_web_id) { 'abc12' }
    if save_raises
      file.define_singleton_method(:save) { raise save_raises }
    else
      file.define_singleton_method(:save) { true }
    end
    file
  end

  describe 'POST #datafile' do
    context 'authentication guard' do
      it 'returns not found when dataset is not a draft dataset' do
        allow(Dataset).to receive(:find_by).with(key: released_dataset.key).and_return(released_dataset)

        post :datafile, params: { dataset_key: released_dataset.key }, format: :json

        expect(response).to have_http_status(:not_found)
        expect(response.body).to include('Dataset Not Found')
      end

      it 'returns unauthorized for draft dataset when token authentication fails' do
        allow(Dataset).to receive(:find_by).with(key: draft_dataset.key).and_return(draft_dataset)

        post :datafile, params: { dataset_key: draft_dataset.key }, format: :json

        expect(response).to have_http_status(:unauthorized)
        expect(response.body).to include('HTTP Token: Access denied')
      end
    end

    context 'when authentication is already satisfied' do
      before do
        allow(controller).to receive(:authenticate).and_return(true)
        allow(StorageManager).to receive(:instance).and_return(storage_manager)
      end

      it 'returns invalid request when neither binary nor tus params are present' do
        allow(Dataset).to receive(:find_by).with(key: draft_dataset.key).and_return(draft_dataset)

        post :datafile, params: { dataset_key: draft_dataset.key }, format: :json

        expect(response).to have_http_status(:internal_server_error)
        expect(response.body).to include('invalid request')
      end

      it 'uploads a binary payload and returns success' do
        tempfile = Tempfile.new('api-upload-success')
        tempfile.write('archive-bytes')
        tempfile.rewind
        uploaded_io = ActionDispatch::Http::UploadedFile.new(
          tempfile: tempfile,
          filename: 'archive.zip',
          type: 'application/zip'
        )
        df = fake_datafile

        allow(Dataset).to receive(:find_by).with(key: draft_dataset.key).and_return(draft_dataset)
        allow(Datafile).to receive(:new).with(dataset_id: draft_dataset.id).and_return(df)
        expect(draft_root).to receive(:copy_io_to).with('abc12/archive.zip', uploaded_io, nil, uploaded_io.size)
        allow(controller).to receive(:params).and_return(
          ActionController::Parameters.new('dataset_key' => draft_dataset.key, 'binary' => uploaded_io)
        )

        post :datafile, params: { dataset_key: draft_dataset.key }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('successfully uploaded archive.zip')
        expect(response.body).to include("/datasets/#{draft_dataset.key}")
        tempfile.close!
      end

      it 'returns internal server error when binary upload copy fails' do
        tempfile = Tempfile.new('api-upload-failure')
        tempfile.write('archive-bytes')
        tempfile.rewind
        uploaded_io = ActionDispatch::Http::UploadedFile.new(
          tempfile: tempfile,
          filename: 'archive.zip',
          type: 'application/zip'
        )
        df = fake_datafile

        allow(Dataset).to receive(:find_by).with(key: draft_dataset.key).and_return(draft_dataset)
        allow(Datafile).to receive(:new).with(dataset_id: draft_dataset.id).and_return(df)
        allow(draft_root).to receive(:copy_io_to).and_raise(StandardError, 'copy failed')
        allow(controller).to receive(:params).and_return(
          ActionController::Parameters.new('dataset_key' => draft_dataset.key, 'binary' => uploaded_io)
        )

        post :datafile, params: { dataset_key: draft_dataset.key }

        expect(response).to have_http_status(:internal_server_error)
        expect(response.body).to include('copy failed')
        tempfile.close!
      end

      it 'uploads a tus payload and returns success' do
        df = fake_datafile

        allow(Dataset).to receive(:find_by).with(key: draft_dataset.key).and_return(draft_dataset)
        allow(Datafile).to receive(:new).with(dataset_id: draft_dataset.id).and_return(df)

        post :datafile,
             params: {
               dataset_key: draft_dataset.key,
               tus_url: 'https://uploads.example/tus/segment-key-99',
               filename: 'chunked.csv',
               size: 128
             },
             format: :json

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('successfully uploaded chunked.csv')
      end

      it 'returns internal server error when tus save fails' do
        df = fake_datafile(save_raises: StandardError.new('save failed'))

        allow(Dataset).to receive(:find_by).with(key: draft_dataset.key).and_return(draft_dataset)
        allow(Datafile).to receive(:new).with(dataset_id: draft_dataset.id).and_return(df)

        post :datafile,
             params: {
               dataset_key: draft_dataset.key,
               tus_url: 'https://uploads.example/tus/segment-key-99',
               filename: 'chunked.csv',
               size: 128
             },
             format: :json

        expect(response).to have_http_status(:internal_server_error)
        expect(response.body).to include('save failed')
      end
    end
  end
end
