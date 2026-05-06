# spec/models/datafile_spec.rb
require 'rails_helper'

RSpec.describe Datafile, type: :model do
  let(:dataset) { create(:dataset) }
  let(:datafile) { build(:datafile, dataset: dataset) }

  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(datafile).to be_valid
    end

    it 'is not valid without a dataset' do
      datafile.dataset = nil
      expect(datafile).to_not be_valid
    end

    it 'is not valid without a binary_name' do
      datafile.binary_name = nil
      expect(datafile).to_not be_valid
    end

    it 'is not valid without a web_id' do
      datafile.web_id = nil
      datafile.save
      expect(datafile.web_id).to be_present
    end
  end

  describe 'associations' do
    it { should belong_to(:dataset) }
    it { should have_many(:nested_items).dependent(:destroy) }
  end

  describe 'callbacks' do
    it 'generates a web_id before creation' do
      datafile.save
      expect(datafile.web_id).to be_present
    end

    it 'sets dataset nested_updated_at after creation' do
      expect(dataset).to receive(:update_attribute).with(:nested_updated_at, anything)
      datafile.save
    end

    it 'sets dataset nested_updated_at before destruction' do
      datafile.save
      expect(dataset).to receive(:update_attribute).with(:nested_updated_at, anything)
      datafile.destroy
    end
  end

  describe '#to_param' do
    it 'returns the web_id as the parameter' do
      expect(datafile.to_param).to eq(datafile.web_id)
    end
  end

  describe '#as_json' do
    it 'returns a JSON representation of the datafile' do
      json = datafile.as_json
      expect(json).to include('web_id', 'binary_name', 'binary_size', 'medusa_id', 'storage_root', 'storage_key', 'created_at', 'updated_at')
    end
  end

  describe '#set_dataset_nested_updated_at' do
    it 'sets the nested_updated_at attribute of the dataset to the current time' do
      datafile.save
      expect(dataset.nested_updated_at).to be_within(1.second).of(Time.now.utc)
    end
  end

  describe '#bytestream_name' do
    it 'returns the binary_name' do
      expect(datafile.bytestream_name).to eq(datafile.binary_name)
    end
  end

  describe '#bytestream_size' do
    it 'returns the binary_size if it is set' do
      datafile.binary_size = 1024
      expect(datafile.bytestream_size).to eq(1024)
    end

    it 'returns 0 and logs a warning if the binary is not found' do
      allow(datafile).to receive(:current_root).and_return(nil)
      expect(Rails.logger).to receive(:warn).with("binary not found for datafile: #{datafile.web_id} root: #{datafile.storage_root}, key: #{datafile.storage_key}")
      expect(datafile.bytestream_size).to eq(0)
    end
  end

  describe '#s3_object' do
    it 'returns nil if the file does not exist on storage' do
      allow(datafile).to receive(:exists_on_storage?).and_return(false)
      expect(datafile.s3_object).to be_nil
    end
  end

  describe '#etag' do
    it 'returns the etag of the S3 object if it exists' do
      s3_object = double('s3_object', etag: 'etag_value')
      allow(datafile).to receive(:s3_object).and_return(s3_object)
      expect(datafile.etag).to eq('etag_value')
    end

    it 'returns nil if the S3 object does not exist' do
      allow(datafile).to receive(:s3_object).and_return(nil)
      expect(datafile.etag).to be_nil
    end
  end

  describe '#name' do
    it 'returns the binary_name' do
      expect(datafile.name).to eq(datafile.binary_name)
    end
  end

  describe '#ensure_mime_type' do
    it 'sets the mime type if it is not set' do
      datafile.mime_type = nil
      allow(datafile).to receive(:mime_type_from_name).and_return('text/plain')
      datafile.ensure_mime_type
      expect(datafile.mime_type).to eq('text/plain')
    end
  end

  describe '#readme?' do
    it 'returns true if the binary_name includes "readme"' do
      datafile.binary_name = 'README.txt'
      expect(datafile.readme?).to be true
    end

    it 'returns false if the binary_name does not include "readme"' do
      datafile.binary_name = 'sample.txt'
      expect(datafile.readme?).to be false
    end
  end

  describe '#generate_web_id' do
    it 'generates a unique web_id' do
      web_id = datafile.generate_web_id
      expect(Datafile.find_by(web_id: web_id)).to be_nil
    end
  end

  describe '.tus_storage_key' do
    it 'extracts the final path segment from tus_url' do
      expect(Datafile.tus_storage_key('https://example.test/files/upload-key-123')).to eq('upload-key-123')
    end

    it 'raises when tus_url does not contain a key' do
      expect { Datafile.tus_storage_key('') }.to raise_error(ArgumentError, /missing key/)
      expect { Datafile.tus_storage_key('/') }.to raise_error(ArgumentError, /missing key/)
    end
  end

  describe '.build_from_tus' do
    it 'builds a datafile with centralized TUS attributes' do
      draft_root_name = StorageManager.instance.draft_root.name

      built = Datafile.build_from_tus(
        dataset: dataset,
        tus_url: 'https://example.test/files/abc123',
        filename: 'file.csv',
        size: 345,
        mime_type: 'text/csv'
      )

      expect(built.dataset_id).to eq(dataset.id)
      expect(built.web_id).to be_present
      expect(built.storage_root).to eq(draft_root_name)
      expect(built.binary_name).to eq('file.csv')
      expect(built.storage_key).to eq('abc123')
      expect(built.binary_size).to eq(345)
      expect(built.mime_type).to eq('text/csv')
    end
  end

  describe '.peek_type_from_mime' do
    it 'returns none when mime type is missing or malformed' do
      expect(Datafile.peek_type_from_mime(nil, 100)).to eq(Databank::PeekType::NONE)
      expect(Datafile.peek_type_from_mime('text', 100)).to eq(Databank::PeekType::NONE)
    end

    it 'returns markdown for markdown mime top-level type' do
      expect(Datafile.peek_type_from_mime('markdown/plain', 100)).to eq(Databank::PeekType::MARKDOWN)
    end

    it 'returns all_text for small text and part_text for large text' do
      small = Datafile::Viewable::ALLOWED_DISPLAY_BYTES - 1
      large = Datafile::Viewable::ALLOWED_DISPLAY_BYTES + 1

      expect(Datafile.peek_type_from_mime('text/plain', small)).to eq(Databank::PeekType::ALL_TEXT)
      expect(Datafile.peek_type_from_mime('text/plain', large)).to eq(Databank::PeekType::PART_TEXT)
    end

    it 'maps supported media/document mime types' do
      expect(Datafile.peek_type_from_mime('image/png', 100)).to eq(Databank::PeekType::IMAGE)
      expect(Datafile.peek_type_from_mime('application/pdf', 100)).to eq(Databank::PeekType::PDF)
      expect(Datafile.peek_type_from_mime('application/zip', 100)).to eq(Databank::PeekType::LISTING)
      expect(Datafile.peek_type_from_mime('application/msword', 100)).to eq(Databank::PeekType::MICROSOFT)
      expect(Datafile.peek_type_from_mime('image/webp', 100)).to eq(Databank::PeekType::NONE)
    end
  end

  describe '#handle_peek' do
    it 'renders markdown preview and saves markdown peek type' do
      datafile.binary_name = 'notes.md'
      allow(datafile).to receive(:all_text_peek).and_return('# Header')
      renderer = double('markdown_renderer', render: '<h1>Header</h1>')
      allow(Application).to receive(:markdown).and_return(renderer)

      expect(datafile.handle_peek).to be true
      expect(datafile.peek_type).to eq(Databank::PeekType::MARKDOWN)
      expect(datafile.peek_text).to eq('<h1>Header</h1>')
    end

    it 'handles listing peek type by starting processing task' do
      datafile.binary_name = 'archive.zip'
      datafile.mime_type = 'application/zip'
      datafile.binary_size = 500
      allow(datafile).to receive(:initiate_processing_task).and_return(true)

      expect(datafile.handle_peek).to be true
      expect(datafile).to have_received(:initiate_processing_task)
    end
  end

  describe '#part_text_peek' do
    it 'returns file not found when storage object is missing' do
      root = double('storage_root', exist?: false)
      allow(datafile).to receive(:current_root).and_return(root)

      expect(datafile.part_text_peek).to eq('file not found')
    end

    it 'returns decoded bytes in s3 mode' do
      config_copy = IDB_CONFIG.deep_dup
      config_copy[:aws][:s3_mode] = true
      stub_const('IDB_CONFIG', config_copy)

      raw = StringIO.new("abc\u0000def")
      root = double('storage_root', exist?: true, get_bytes: raw)
      allow(datafile).to receive(:current_root).and_return(root)

      expect(datafile.part_text_peek).to eq('abcdef')
    end
  end

  describe '#all_text_peek' do
    it 'returns full file contents in local filesystem mode' do
      config_copy = IDB_CONFIG.deep_dup
      config_copy[:aws][:s3_mode] = false
      stub_const('IDB_CONFIG', config_copy)

      root = double('storage_root', exist?: true)
      allow(datafile).to receive(:current_root).and_return(root)

      Dir.mktmpdir('viewable-local-peek') do |dir|
        path = File.join(dir, 'peek.txt')
        File.write(path, 'full file preview')
        allow(datafile).to receive(:filepath).and_return(path)

        expect(datafile.all_text_peek).to eq('full file preview')
      end
    end
  end

  describe '#mime_type_from_name' do
    it 'returns nil when binary_name is missing' do
      datafile.binary_name = nil

      expect(datafile.mime_type_from_name).to be_nil
    end

    it 'returns application/octet-stream when MIME lookup raises' do
      datafile.binary_name = 'example.txt'
      allow(MIME::Types).to receive(:type_for).and_raise(StandardError.new('lookup failed'))

      expect(Rails.logger).to receive(:warn).with(/unexpected problem deriving mime type/)
      expect(Rails.logger).to receive(:warn).with(StandardError)
      expect(Rails.logger).to receive(:warn).with('lookup failed')

      expect(datafile.mime_type_from_name).to eq('application/octet-stream')
    end
  end

  describe '#iiif_bytestream_path' do
    it 'returns draft iiif path when storage_root is draft' do
      datafile.storage_root = 'draft'
      datafile.storage_key = 'alpha/beta.txt'

      expect(datafile.iiif_bytestream_path).to eq(File.join(IDB_CONFIG[:iiif][:draft_base], 'alpha/beta.txt'))
    end

    it 'returns medusa iiif path when storage_root is medusa' do
      datafile.storage_root = 'medusa'
      datafile.storage_key = 'gamma/delta.txt'

      expect(datafile.iiif_bytestream_path).to eq(File.join(IDB_CONFIG[:iiif][:medusa_base], 'gamma/delta.txt'))
    end

    it 'raises when storage_root is invalid' do
      datafile.storage_root = 'unknown'

      expect { datafile.iiif_bytestream_path }.to raise_error(StandardError, /invalid storage_root/)
    end
  end

  describe '#viewable helper predicates' do
    it 'returns file extension when present' do
      datafile.binary_name = 'archive.tar.gz'

      expect(datafile.file_extension).to eq('gz')
    end

    it 'returns empty extension when filename has no dot' do
      datafile.binary_name = 'README'

      expect(datafile.file_extension).to eq('')
    end

    it 'identifies image preview only for supported image extensions' do
      datafile.peek_type = Databank::PeekType::IMAGE
      datafile.binary_name = 'photo.jpg'
      expect(datafile.image?).to be true

      datafile.binary_name = 'photo.gif'
      expect(datafile.image?).to be false
    end
  end

  describe '#microsoft_preview_url' do
    it 'returns Office preview URL for microsoft peek type' do
      datafile.peek_type = Databank::PeekType::MICROSOFT
      datafile.web_id = 'abc12'

      expect(datafile.microsoft_preview_url).to include('view.officeapps.live.com/op/view.aspx?src=')
      expect(datafile.microsoft_preview_url).to include('datafiles%2Fabc12%2Fview')
    end

    it 'returns nil when datafile is not microsoft preview type' do
      datafile.peek_type = Databank::PeekType::PDF

      expect(datafile.microsoft_preview_url).to be_nil
    end
  end

  describe '#handle_peek error fallback' do
    it 'sets none/blank preview and returns false when an unexpected error occurs' do
      persisted_datafile = create(
        :datafile,
        dataset: dataset,
        binary_name: 'notes.txt',
        mime_type: 'text/plain',
        binary_size: 100
      )
      allow(persisted_datafile).to receive(:all_text_peek).and_raise(StandardError.new('peek explosion'))

      expect(persisted_datafile.handle_peek).to be false
      persisted_datafile.reload
      expect(persisted_datafile.peek_type).to eq(Databank::PeekType::NONE)
      expect(persisted_datafile.peek_text).to eq('')
    end
  end

  describe 'storable concern helpers' do
    it 'returns bucket only in s3 mode' do
      config_copy = IDB_CONFIG.deep_dup
      config_copy[:aws][:s3_mode] = true
      stub_const('IDB_CONFIG', config_copy)

      root = double(bucket: 'idb-bucket')
      allow(datafile).to receive(:current_root).and_return(root)

      expect(datafile.storage_root_bucket).to eq('idb-bucket')
    end

    it 'returns key with prefix in s3 mode and raw key otherwise' do
      s3_config = IDB_CONFIG.deep_dup
      s3_config[:aws][:s3_mode] = true
      stub_const('IDB_CONFIG', s3_config)
      root = double(prefix: 'draft-prefix/')
      allow(datafile).to receive(:current_root).and_return(root)
      datafile.storage_key = 'path/file.txt'

      expect(datafile.storage_key_with_prefix).to eq('draft-prefix/path/file.txt')

      local_config = IDB_CONFIG.deep_dup
      local_config[:aws][:s3_mode] = false
      stub_const('IDB_CONFIG', local_config)

      expect(datafile.storage_key_with_prefix).to eq('path/file.txt')
    end

    it 'returns filesystem storage path only in non-s3 mode' do
      local_config = IDB_CONFIG.deep_dup
      local_config[:aws][:s3_mode] = false
      stub_const('IDB_CONFIG', local_config)
      root = double(real_path: '/tmp/storage')
      allow(datafile).to receive(:current_root).and_return(root)

      expect(datafile.storage_root_path).to eq('/tmp/storage')

      s3_config = IDB_CONFIG.deep_dup
      s3_config[:aws][:s3_mode] = true
      stub_const('IDB_CONFIG', s3_config)

      expect(datafile.storage_root_path).to be_nil
    end

    it 'builds filepath when a filesystem root path exists' do
      allow(datafile).to receive(:storage_root_path).and_return('/tmp/root')
      datafile.storage_key = 'a/b/c.txt'

      expect(datafile.filepath).to eq('/tmp/root/a/b/c.txt')
    end

    it 'raises when filepath is requested without filesystem root path' do
      allow(datafile).to receive(:storage_root_path).and_return(nil)

      expect { datafile.filepath }.to raise_error(StandardError, /no filesystem path found/)
    end

    it 'checks bytestream presence based on root existence and key fields' do
      root = double(exist?: true)
      allow(datafile).to receive(:current_root).and_return(root)
      datafile.storage_root = 'draft'
      datafile.storage_key = 'exists-key'

      expect(datafile.bytestream?).to be true

      datafile.storage_key = ''
      expect(datafile.bytestream?).to be false
    end

    it 'returns false for exists_on_storage? when storage_key is nil' do
      datafile.storage_key = nil

      expect(datafile.exists_on_storage?).to be false
    end

    it 'removes from storage only when object exists' do
      root = double
      allow(datafile).to receive(:current_root).and_return(root)
      allow(datafile).to receive(:exists_on_storage?).and_return(true)
      datafile.storage_key = 'drop/me'

      expect(root).to receive(:delete_content).with('drop/me')
      datafile.remove_from_storage
    end

    it 'uses temp filesystem for large input files and Dir.tmpdir for small files' do
      datafile.binary_size = 600.megabytes
      allow(StorageManager.instance).to receive(:tmpdir).and_return('/tmp/large-files')
      expect(datafile.tmpdir_for_with_input_file).to eq('/tmp/large-files')

      datafile.binary_size = 10.megabytes
      expect(datafile.tmpdir_for_with_input_file).to eq(Dir.tmpdir)
    end

    it 'passes through input io and input file wrappers to current root' do
      root = double
      allow(datafile).to receive(:current_root).and_return(root)
      datafile.storage_key = 'input/key'
      datafile.binary_size = 10
      allow(datafile).to receive(:tmpdir_for_with_input_file).and_return('/tmp/spec-tmp')

      io_obj = StringIO.new('abc')
      file_obj = '/tmp/spec-file'
      expect(root).to receive(:with_input_io).with('input/key').and_yield(io_obj)
      yielded_io = nil
      datafile.with_input_io { |io| yielded_io = io }
      expect(yielded_io).to eq(io_obj)

      expect(root).to receive(:with_input_file).with('input/key', tmp_dir: '/tmp/spec-tmp').and_yield(file_obj)
      yielded_file = nil
      datafile.with_input_file { |f| yielded_file = f }
      expect(yielded_file).to eq(file_obj)
    end

    it 'builds tmpfs key from dataset key and datafile name' do
      allow(dataset).to receive(:key).and_return('DSKEY')
      datafile.binary_name = 'file.txt'

      expect(datafile.tmpfs_key).to eq(File.join('DSKEY', 'file.txt'))
    end

    it 'copies to tmpfs and raises when tmpfs key already exists' do
      allow(datafile).to receive(:tmpfs_key).and_return('DSKEY/file.txt')
      allow(datafile).to receive(:binary_size).and_return(123)
      input_io = StringIO.new('tmp content')

      allow(datafile.tmpfs_root).to receive(:exist?).with('DSKEY/file.txt').and_return(false)
      expect(datafile.tmpfs_root).to receive(:copy_io_to).with('DSKEY/file.txt', input_io, nil, 123)
      allow(datafile).to receive(:with_input_io).and_yield(input_io)
      datafile.copy_to_tmpfs

      allow(datafile.tmpfs_root).to receive(:exist?).with('DSKEY/file.txt').and_return(true)
      expect { datafile.copy_to_tmpfs }.to raise_error(StandardError, /already exists/)
    end

    it 'removes from tmpfs and prunes dataset folder when empty' do
      allow(datafile).to receive(:tmpfs_key).and_return('DSKEY/file.txt')
      allow(dataset).to receive(:key).and_return('DSKEY')
      allow(datafile.tmpfs_root).to receive(:exist?).with('DSKEY/file.txt').and_return(true)
      expect(datafile.tmpfs_root).to receive(:delete_content).with('DSKEY/file.txt')
      allow(datafile.tmpfs_root).to receive(:real_path).and_return('/tmpfs-root')
      allow(Dir).to receive(:empty?).with('/tmpfs-root/DSKEY').and_return(true)
      expect(datafile.tmpfs_root).to receive(:delete_tree).with('DSKEY')

      datafile.remove_from_tmpfs
    end

    it 'returns true when tmpfs key does not exist during removal' do
      allow(datafile).to receive(:tmpfs_key).and_return('DSKEY/file.txt')
      allow(datafile.tmpfs_root).to receive(:exist?).with('DSKEY/file.txt').and_return(false)

      expect(datafile.remove_from_tmpfs).to be true
    end
  end

  describe '#in_medusa' do
    it 'returns false and warns when dataset is missing' do
      orphan = build(:datafile, dataset: nil)

      expect(Rails.logger).to receive(:warn).with(/dataset not found for datafile/)
      expect(orphan.in_medusa).to be false
    end

    it 'returns false when dataset has no identifier' do
      datafile.dataset.identifier = nil

      expect(datafile.in_medusa).to be false
    end

    it 'updates storage root/key and saves when object exists in medusa' do
      datafile.dataset.identifier = '10.13012/B2IDB-1234567_V1'
      datafile.storage_root = 'medusa'
      datafile.storage_key = 'old/key'
      target_key = 'new/medusa/key'
      allow(datafile).to receive(:target_key).and_return(target_key)
      allow(StorageManager.instance.medusa_root).to receive(:exist?).with(target_key).and_return(true)
      expect(datafile).to receive(:save!)

      expect(datafile.in_medusa).to be true
      expect(datafile.storage_root).to eq('medusa')
      expect(datafile.storage_key).to eq(target_key)
    end

    it 'deletes duplicate draft object when medusa object has matching size' do
      datafile.dataset.identifier = '10.13012/B2IDB-1234567_V1'
      datafile.storage_root = 'draft'
      datafile.storage_key = 'draft/key'
      target_key = 'medusa/key'
      allow(datafile).to receive(:target_key).and_return(target_key)
      allow(StorageManager.instance.medusa_root).to receive(:exist?).with(target_key).and_return(true)
      allow(StorageManager.instance.draft_root).to receive(:exist?).with('draft/key').and_return(true)
      allow(StorageManager.instance.draft_root).to receive(:size).with('draft/key').and_return(123)
      allow(StorageManager.instance.medusa_root).to receive(:size).with(target_key).and_return(123)
      expect(StorageManager.instance.draft_root).to receive(:delete_content).with('draft/key')
      expect(datafile).to receive(:save!)

      expect(datafile.in_medusa).to be true
    end
  end
end
