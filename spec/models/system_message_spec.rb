require 'rails_helper'
require 'tmpdir'

RSpec.describe SystemMessage, type: :model do
  def with_read_only_path(path)
    stub_const('IDB_CONFIG', IDB_CONFIG.merge(read_only_msg_path: path))
    yield
  end

  describe '.read_only_msg_middle' do
    it 'returns nil when the message file does not exist' do
      Dir.mktmpdir('system-message-missing') do |dir|
        path = File.join(dir, 'missing.txt')

        with_read_only_path(path) do
          expect(SystemMessage.read_only_msg_middle).to be_nil
        end
      end
    end

    it 'returns nil when the message file is blank after stripping' do
      Dir.mktmpdir('system-message-blank') do |dir|
        path = File.join(dir, 'readonly.txt')
        File.write(path, "   \n\t  ")

        with_read_only_path(path) do
          expect(SystemMessage.read_only_msg_middle).to be_nil
        end
      end
    end

    it 'returns stripped message text when file has content' do
      Dir.mktmpdir('system-message-content') do |dir|
        path = File.join(dir, 'readonly.txt')
        File.write(path, "  Planned restart at 5pm.  \n")

        with_read_only_path(path) do
          expect(SystemMessage.read_only_msg_middle).to eq('Planned restart at 5pm.')
        end
      end
    end
  end

  describe '.read_only_message' do
    it 'returns default message wrapper when middle message is blank' do
      allow(SystemMessage).to receive(:read_only_msg_middle).and_return(nil)

      msg = SystemMessage.read_only_message

      expect(msg).to include('datasets cannot be added or edited')
      expect(msg).to include('Contact Research Data Service')
      expect(msg).not_to include('Planned restart')
    end

    it 'includes the custom middle message when present' do
      allow(SystemMessage).to receive(:read_only_msg_middle).and_return('Planned restart')

      msg = SystemMessage.read_only_message

      expect(msg).to include('datasets cannot be added or edited')
      expect(msg).to include('Planned restart')
      expect(msg).to include('Contact Research Data Service')
    end
  end

  describe '.remove_read_only_message' do
    it 'returns true when path does not exist' do
      Dir.mktmpdir('system-message-remove-missing') do |dir|
        path = File.join(dir, 'missing.txt')

        with_read_only_path(path) do
          expect(SystemMessage.remove_read_only_message).to be true
        end
      end
    end

    it 'returns false when path exists but is not a file' do
      Dir.mktmpdir('system-message-remove-dir') do |dir|
        with_read_only_path(dir) do
          expect(SystemMessage.remove_read_only_message).to be false
        end
      end
    end

    it 'deletes existing file and returns true' do
      Dir.mktmpdir('system-message-remove-file') do |dir|
        path = File.join(dir, 'readonly.txt')
        File.write(path, 'message')

        with_read_only_path(path) do
          expect(SystemMessage.remove_read_only_message).to be true
          expect(File.exist?(path)).to be false
        end
      end
    end
  end

  describe '.update_read_only_message' do
    it 'returns false when new message is blank' do
      Dir.mktmpdir('system-message-update-blank') do |dir|
        path = File.join(dir, 'readonly.txt')

        with_read_only_path(path) do
          expect(SystemMessage.update_read_only_message('   ')).to be false
        end
      end
    end

    it 'returns false when existing message cannot be removed' do
      allow(SystemMessage).to receive(:remove_read_only_message).and_return(false)

      expect(SystemMessage.update_read_only_message('new message')).to be false
    end

    it 'writes message content and returns true when write succeeds' do
      Dir.mktmpdir('system-message-update-success') do |dir|
        path = File.join(dir, 'readonly.txt')

        with_read_only_path(path) do
          expect(SystemMessage.update_read_only_message('maintenance window')).to be true
          expect(File.read(path)).to eq('maintenance window')
        end
      end
    end
  end
end