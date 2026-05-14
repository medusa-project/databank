require 'rails_helper'
require 'tmpdir'
require 'fileutils'

RSpec.describe Dataset::Recoverable, type: :model do
  let(:tmp_root) { Dir.mktmpdir('medusa-recoverable-spec') }
  let(:identifier) { '10.1234/abcd' }
  let(:dataset_dir) { File.join(tmp_root, 'DOI-10-1234-abcd') }
  let(:system_dir) { File.join(dataset_dir, 'system') }
  let(:config_copy) { IDB_CONFIG.deep_dup }

  before do
    config_copy['medusa']['medusa_path_root'] = tmp_root
    stub_const('IDB_CONFIG', config_copy)
  end

  after do
    FileUtils.remove_entry(tmp_root) if File.exist?(tmp_root)
  end

  describe '.serializations_from_medusa' do
    it 'returns serialization payloads for DOI directories only' do
      FileUtils.mkdir_p(File.join(tmp_root, 'DOI-10-1111-aaaa'))
      FileUtils.mkdir_p(File.join(tmp_root, 'DOI-10-2222-bbbb'))
      FileUtils.mkdir_p(File.join(tmp_root, 'misc-folder'))

      allow(Dataset).to receive(:get_serialzation_json_from_medusa) do |id|
        "payload-for-#{id}"
      end

      result = Dataset.serializations_from_medusa

      expect(result).to contain_exactly('payload-for-10.1111-aaaa', 'payload-for-10.2222-bbbb')
    end
  end

  describe '.get_serialzation_json_from_medusa' do
    it 'raises when identifier is missing' do
      expect { Dataset.get_serialzation_json_from_medusa(nil) }
        .to raise_error(StandardError, 'missing identifier')
    end

    it 'raises when identifier is invalid' do
      expect { Dataset.get_serialzation_json_from_medusa('doi:10.1234/abcd') }
        .to raise_error(StandardError, 'invalid identifier')
    end

    it 'returns error json when dataset directory is missing' do
      result = Dataset.get_serialzation_json_from_medusa(identifier)

      expect(result).to include("NO DIR: #{dataset_dir}")
    end

    it 'returns only serialization content when exactly one file is present' do
      FileUtils.mkdir_p(system_dir)
      File.write(File.join(system_dir, 'serialization.2024-01-01_09-00.json'), '{"version":1}')

      result = Dataset.get_serialzation_json_from_medusa(identifier)

      expect(result).to eq('{"version":1}')
    end

    it 'returns the latest serialization content when multiple files are present' do
      FileUtils.mkdir_p(system_dir)
      File.write(File.join(system_dir, 'serialization.2023-12-31_23-59.json'), '{"version":"old"}')
      File.write(File.join(system_dir, 'serialization.2024-02-01_11-10.json'), '{"version":"new"}')

      result = Dataset.get_serialzation_json_from_medusa(identifier)

      expect(result).to eq('{"version":"new"}')
    end
  end

  describe '.get_changelog_from_medusa' do
    it 'returns error json when system directory is missing' do
      FileUtils.mkdir_p(dataset_dir)

      result = Dataset.get_changelog_from_medusa(identifier)

      expect(result).to include("NO SYSDIR: #{system_dir}")
    end

    it 'returns only changelog content when exactly one file is present' do
      FileUtils.mkdir_p(system_dir)
      File.write(File.join(system_dir, 'changelog.2024-01-01_09-00.json'), '[{"change":"one"}]')

      result = Dataset.get_changelog_from_medusa(identifier)

      expect(result).to eq('[{"change":"one"}]')
    end

    it 'returns the latest changelog content when multiple files are present' do
      FileUtils.mkdir_p(system_dir)
      File.write(File.join(system_dir, 'changelog.2023-12-31_23-59.json'), '[{"change":"old"}]')
      File.write(File.join(system_dir, 'changelog.2024-02-01_11-10.json'), '[{"change":"new"}]')

      result = Dataset.get_changelog_from_medusa(identifier)

      expect(result).to eq('[{"change":"new"}]')
    end
  end
end
