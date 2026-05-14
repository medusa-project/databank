require 'rails_helper'

RSpec.describe Datafile::Viewable, type: :model do
  let(:dataset)  { create(:dataset) }
  let(:datafile) { build(:datafile, dataset: dataset, binary_name: 'sample.txt', mime_type: 'text/plain', binary_size: 100) }

  # ─── class method: peek_type_from_mime ────────────────────────────────────────

  describe '.peek_type_from_mime' do
    subject { Datafile.peek_type_from_mime(mime_type, num_bytes) }

    context 'guard conditions' do
      it { expect(Datafile.peek_type_from_mime('text/plain', nil)).to eq(Databank::PeekType::NONE) }
      it { expect(Datafile.peek_type_from_mime(nil, 100)).to eq(Databank::PeekType::NONE) }
      it { expect(Datafile.peek_type_from_mime('', 100)).to eq(Databank::PeekType::NONE) }
      it { expect(Datafile.peek_type_from_mime('invalid-no-slash', 100)).to eq(Databank::PeekType::NONE) }
    end

    it 'returns MARKDOWN for markdown/* mime type' do
      expect(Datafile.peek_type_from_mime('markdown/plain', 100)).to eq(Databank::PeekType::MARKDOWN)
    end

    it 'returns ALL_TEXT for small text/plain files' do
      expect(Datafile.peek_type_from_mime('text/plain', 100)).to eq(Databank::PeekType::ALL_TEXT)
    end

    it 'returns PART_TEXT for large text/plain files' do
      large = Datafile::Viewable::ALLOWED_DISPLAY_BYTES + 1
      expect(Datafile.peek_type_from_mime('text/plain', large)).to eq(Databank::PeekType::PART_TEXT)
    end

    it 'returns ALL_TEXT for application/csv (text subtype list)' do
      expect(Datafile.peek_type_from_mime('application/csv', 100)).to eq(Databank::PeekType::ALL_TEXT)
    end

    it 'returns IMAGE for supported image/jpeg subtype' do
      expect(Datafile.peek_type_from_mime('image/jpeg', 100)).to eq(Databank::PeekType::IMAGE)
    end

    it 'returns NONE for unsupported image/tiff subtype' do
      expect(Datafile.peek_type_from_mime('image/tiff', 100)).to eq(Databank::PeekType::NONE)
    end

    it 'returns MICROSOFT for a Word docx subtype' do
      mime = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
      expect(Datafile.peek_type_from_mime(mime, 100)).to eq(Databank::PeekType::MICROSOFT)
    end

    it 'returns PDF for application/pdf' do
      expect(Datafile.peek_type_from_mime('application/pdf', 100)).to eq(Databank::PeekType::PDF)
    end

    it 'returns LISTING for application/zip' do
      expect(Datafile.peek_type_from_mime('application/zip', 100)).to eq(Databank::PeekType::LISTING)
    end

    it 'returns NONE for an unknown application subtype' do
      expect(Datafile.peek_type_from_mime('application/octet-stream', 100)).to eq(Databank::PeekType::NONE)
    end
  end

  # ─── class method: peek_string ───────────────────────────────────────────────

  describe '.peek_string' do
    it 'encodes bytes as UTF-8, replaces invalid chars, and removes null bytes' do
      raw = StringIO.new("hello\x00world")
      result = Datafile.peek_string(peek_bytes: raw)
      expect(result).to eq('helloworld')
    end
  end

  # ─── instance method: handle_peek ─────────────────────────────────────────────

  describe '#handle_peek' do
    it 'returns false when binary_name is nil' do
      datafile.binary_name = nil
      expect(datafile.handle_peek).to be false
    end

    it 'renders markdown and saves for .md extension' do
      datafile.binary_name = 'readme.md'
      allow(datafile).to receive(:all_text_peek).and_return('# Header')
      allow(datafile).to receive(:save).and_return(true)

      result = datafile.handle_peek

      expect(datafile.peek_type).to eq(Databank::PeekType::MARKDOWN)
      expect(result).to be true
    end

    it 'sets peek_type and peek_text for ALL_TEXT, then saves' do
      datafile.binary_name = 'data.txt'
      allow(Datafile).to receive(:peek_type_from_mime).and_return(Databank::PeekType::ALL_TEXT)
      allow(datafile).to receive(:all_text_peek).and_return('file contents')
      allow(datafile).to receive(:save).and_return(true)

      datafile.handle_peek

      expect(datafile.peek_type).to eq(Databank::PeekType::ALL_TEXT)
      expect(datafile.peek_text).to eq('file contents')
    end

    it 'sets peek_type and peek_text for PART_TEXT, then saves' do
      datafile.binary_name = 'big.txt'
      allow(Datafile).to receive(:peek_type_from_mime).and_return(Databank::PeekType::PART_TEXT)
      allow(datafile).to receive(:part_text_peek).and_return('partial...')
      allow(datafile).to receive(:save).and_return(true)

      datafile.handle_peek

      expect(datafile.peek_type).to eq(Databank::PeekType::PART_TEXT)
      expect(datafile.peek_text).to eq('partial...')
    end

    it 'calls initiate_processing_task for LISTING peek type' do
      datafile.binary_name = 'archive.zip'
      allow(Datafile).to receive(:peek_type_from_mime).and_return(Databank::PeekType::LISTING)
      expect(datafile).to receive(:initiate_processing_task)

      datafile.handle_peek
    end

    it 'sets only peek_type and saves for other types (e.g. IMAGE)' do
      datafile.binary_name = 'photo.jpg'
      allow(Datafile).to receive(:peek_type_from_mime).and_return(Databank::PeekType::IMAGE)
      allow(datafile).to receive(:save).and_return(true)

      datafile.handle_peek

      expect(datafile.peek_type).to eq(Databank::PeekType::IMAGE)
    end

    it 'recovers from StandardError, resets peek_type to NONE and returns false' do
      datafile.binary_name = 'error.txt'
      allow(Datafile).to receive(:peek_type_from_mime).and_raise(StandardError.new('boom'))
      allow(datafile).to receive(:update_attribute)
      allow(Rails.logger).to receive(:warn)

      result = datafile.handle_peek

      expect(result).to be false
      expect(datafile).to have_received(:update_attribute).with('peek_type', Databank::PeekType::NONE)
      expect(datafile).to have_received(:update_attribute).with('peek_text', '')
    end
  end

  # ─── instance method: mime_type_from_name ─────────────────────────────────────

  describe '#mime_type_from_name' do
    it 'returns nil when binary_name is nil' do
      datafile.binary_name = nil
      expect(datafile.mime_type_from_name).to be_nil
    end

    it 'returns a mime type string for a known extension' do
      datafile.binary_name = 'report.pdf'
      result = datafile.mime_type_from_name
      expect(result).to include('pdf')
    end
  end

  # ─── instance methods: storage peek helpers ────────────────────────────────────

  describe '#part_text_peek' do
    it 'returns "file not found" when storage key does not exist' do
      root = instance_double('StorageRoot', exist?: false)
      allow(datafile).to receive(:current_root).and_return(root)

      expect(datafile.part_text_peek).to eq('file not found')
    end
  end

  describe '#all_text_peek' do
    it 'returns "file not found" when storage key does not exist' do
      root = instance_double('StorageRoot', exist?: false)
      allow(datafile).to receive(:current_root).and_return(root)

      expect(datafile.all_text_peek).to eq('file not found')
    end
  end

  # ─── instance method: iiif_bytestream_path ─────────────────────────────────────

  describe '#iiif_bytestream_path' do
    it 'returns draft iiif path for draft storage root' do
      datafile.storage_root = 'draft'
      datafile.storage_key  = 'abc123'
      expect(datafile.iiif_bytestream_path).to eq(File.join(IDB_CONFIG[:iiif][:draft_base], 'abc123'))
    end

    it 'returns medusa iiif path for medusa storage root' do
      datafile.storage_root = 'medusa'
      datafile.storage_key  = 'abc123'
      expect(datafile.iiif_bytestream_path).to eq(File.join(IDB_CONFIG[:iiif][:medusa_base], 'abc123'))
    end

    it 'raises for an unrecognized storage root' do
      datafile.storage_root = 'unknown'
      expect { datafile.iiif_bytestream_path }.to raise_error(StandardError, /invalid storage_root/)
    end
  end

  # ─── instance method: file_extension ──────────────────────────────────────────

  describe '#file_extension' do
    it 'returns empty string when bytestream_name is nil' do
      allow(datafile).to receive(:bytestream_name).and_return(nil)
      expect(datafile.file_extension).to eq('')
    end

    it 'returns empty string when filename has no dot' do
      allow(datafile).to receive(:bytestream_name).and_return('Makefile')
      expect(datafile.file_extension).to eq('')
    end

    it 'returns the extension for a dotted filename' do
      allow(datafile).to receive(:bytestream_name).and_return('data.csv')
      expect(datafile.file_extension).to eq('csv')
    end
  end

  # ─── peek type predicates ─────────────────────────────────────────────────────

  describe 'peek type predicates' do
    {
      Databank::PeekType::MARKDOWN  => :markdown?,
      Databank::PeekType::LISTING   => :archive?,
      Databank::PeekType::ALL_TEXT  => :all_txt?,
      Databank::PeekType::PART_TEXT => :part_txt?,
      Databank::PeekType::MICROSOFT => :microsoft?,
      Databank::PeekType::PDF       => :pdf?,
    }.each do |type, predicate|
      it "returns true for #{predicate} when peek_type is #{type}" do
        datafile.peek_type = type
        expect(datafile.public_send(predicate)).to be true
      end
    end
  end

  describe '#image?' do
    it 'returns true for IMAGE peek type with a supported extension' do
      datafile.peek_type = Databank::PeekType::IMAGE
      allow(datafile).to receive(:file_extension).and_return('jpg')
      expect(datafile.image?).to be true
    end

    it 'returns false for IMAGE peek type with an unsupported extension' do
      datafile.peek_type = Databank::PeekType::IMAGE
      allow(datafile).to receive(:file_extension).and_return('svg')
      expect(datafile.image?).to be false
    end
  end

  describe '#microsoft_preview_url' do
    it 'returns the Office preview URL for microsoft files' do
      datafile.peek_type = Databank::PeekType::MICROSOFT
      datafile.web_id    = 'abc123'
      expect(datafile.microsoft_preview_url).to include('view.officeapps.live.com')
      expect(datafile.microsoft_preview_url).to include('abc123')
    end

    it 'returns nil for non-microsoft files' do
      datafile.peek_type = Databank::PeekType::PDF
      expect(datafile.microsoft_preview_url).to be_nil
    end
  end
end
