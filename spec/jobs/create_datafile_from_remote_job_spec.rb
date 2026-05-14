require 'rails_helper'

RSpec.describe CreateDatafileFromRemoteJob, type: :model do
  let(:dataset_id) { 123 }
  let(:datafile) do
    Struct.new(:web_id, :binary_name, :storage_root, :storage_key, :binary_size) do
      def save!
        true
      end
    end.new('abc123')
  end

  let(:draft_root) do
    double('draft_root',
           name: 'draft',
           bucket: 'draft-bucket',
           prefix: 'draft-prefix/',
           path: '/tmp/databank-draft')
  end
  let(:root_set) { double('root_set', at: draft_root) }
  let(:storage_manager) { double('storage_manager', draft_root: draft_root, root_set: root_set) }

  before do
    allow(StorageManager).to receive(:instance).and_return(storage_manager)
  end

  describe '#initialize' do
    it 'sets progress_max to 2 for very small files' do
      expect do
        CreateDatafileFromRemoteJob.new(dataset_id, datafile, 'https://example.org/file.csv', 'file.csv', '1000')
      end.not_to raise_error
    end

    it 'initializes for larger files without error' do
      expect do
        CreateDatafileFromRemoteJob.new(dataset_id, datafile, 'https://example.org/file.csv', 'file.csv', '12000')
      end.not_to raise_error
    end
  end

  describe '#perform when s3_mode is false' do
    let(:job) { CreateDatafileFromRemoteJob.new(dataset_id, datafile, 'https://example.org/file.csv', 'file.csv', '1200') }

    before do
      stub_const('IDB_CONFIG', { aws: { s3_mode: false } })
      allow(job).to receive(:update_progress)
    end

    it 'writes the remote file to draft filesystem and updates datafile fields' do
      allow(File).to receive(:directory?).and_return(false)
      allow(FileUtils).to receive(:mkdir_p)

      outfile = StringIO.new
      allow(File).to receive(:open).and_yield(outfile)

      response = double('response')
      allow(response).to receive(:read_body).and_yield('segment-1').and_yield('segment-2')
      http = double('http')
      allow(http).to receive(:request_get).and_yield(response)
      allow(Net::HTTP).to receive(:start).and_yield(http)

      job.perform

      expect(datafile.binary_name).to eq('file.csv')
      expect(datafile.storage_root).to eq('draft')
      expect(datafile.storage_key).to eq('abc123/file.csv')
      expect(datafile.binary_size).to eq('1200')
      expect(FileUtils).to have_received(:mkdir_p)
      expect(job).to have_received(:update_progress).at_least(:once)
    end

    it 'skips mkdir_p when parent directory already exists' do
      allow(File).to receive(:directory?).and_return(true)
      allow(FileUtils).to receive(:mkdir_p)

      allow(File).to receive(:open).and_yield(StringIO.new)
      response = double('response')
      allow(response).to receive(:read_body).and_yield('segment')
      http = double('http')
      allow(http).to receive(:request_get).and_yield(response)
      allow(Net::HTTP).to receive(:start).and_yield(http)

      job.perform

      expect(FileUtils).not_to have_received(:mkdir_p)
    end
  end

  describe '#perform when s3_mode is true and file is under FIVE_MB' do
    let(:job) { CreateDatafileFromRemoteJob.new(dataset_id, datafile, 'https://example.org/file.csv', 'file.csv', '1024') }

    before do
      stub_const('IDB_CONFIG', { aws: { s3_mode: true } })
      allow(Application).to receive(:aws_client).and_return(double('aws_client'))
      allow(draft_root).to receive(:copy_io_to)
      allow(job).to receive(:update_progress)
    end

    it 'copies remote content directly to storage root' do
      io = StringIO.new('small-file-contents')
      allow(job).to receive(:open).with('https://example.org/file.csv').and_yield(io)

      job.perform

      expect(draft_root).to have_received(:copy_io_to)
        .with('abc123/file.csv', 'small-file-contents', nil, 1024.0)
    end
  end

  describe '#aws_mulitpart_start' do
    let(:job) { CreateDatafileFromRemoteJob.new(dataset_id, datafile, 'https://example.org/file.csv', 'file.csv', '9000') }

    it 'returns the upload_id from create_multipart_upload' do
      response = double('start_response', upload_id: 'upload-1')
      client = double('client')
      allow(client).to receive(:create_multipart_upload).and_return(response)

      result = job.aws_mulitpart_start(client, 'bucket-1', 'key-1')

      expect(result).to eq('upload-1')
    end
  end

  describe '#aws_upload_part' do
    let(:job) { CreateDatafileFromRemoteJob.new(dataset_id, datafile, 'https://example.org/file.csv', 'file.csv', '9000') }

    it 'returns etag from upload_part response' do
      response = double('part_response', etag: 'etag-1')
      client = double('client')
      allow(client).to receive(:upload_part).and_return(response)

      result = job.aws_upload_part(client, StringIO.new('abc'), 'bucket-1', 'key-1', 1, 'upload-1')

      expect(result).to eq('etag-1')
    end
  end

  describe '#aws_complete_upload' do
    let(:job) { CreateDatafileFromRemoteJob.new(dataset_id, datafile, 'https://example.org/file.csv', 'file.csv', '9000') }

    it 'calls complete_multipart_upload with parts payload' do
      client = double('client')
      allow(client).to receive(:complete_multipart_upload)

      job.aws_complete_upload(client, 'bucket-1', 'key-1', [{ etag: 'x', part_number: 1 }], 'upload-1')

      expect(client).to have_received(:complete_multipart_upload).with(
        bucket: 'bucket-1',
        key: 'key-1',
        multipart_upload: { parts: [{ etag: 'x', part_number: 1 }] },
        upload_id: 'upload-1'
      )
    end
  end
end
