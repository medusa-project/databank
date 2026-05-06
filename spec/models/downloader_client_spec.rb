require 'rails_helper'

RSpec.describe DownloaderClient, type: :model do
  describe '.datafiles_download_hash' do
    let(:dataset) { create(:dataset) }
    let!(:datafile1) { create(:datafile, dataset: dataset, web_id: 'abc123', storage_key: 'path/one.txt') }
    let!(:datafile2) { create(:datafile, dataset: dataset, web_id: 'def456', storage_key: 'path/two.txt') }

    before do
      allow(dataset).to receive(:record_text).and_return('dataset metadata')
      allow(datafile1).to receive(:bytestream_size).and_return(10)
      allow(datafile2).to receive(:bytestream_size).and_return(20)
      allow(Datafile).to receive(:find_by).with(web_id: 'abc123').and_return(datafile1)
      allow(Datafile).to receive(:find_by).with(web_id: 'def456').and_return(datafile2)
    end

    it 'returns ok hash with urls and total size for valid downloader response' do
      allow(DownloaderClient).to receive(:request_download_hash)
        .and_return({ status: 'ok', download_url: 'https://dl.example/file.zip', status_url: 'https://dl.example/status/1' })

      result = DownloaderClient.datafiles_download_hash(
        dataset: dataset,
        web_ids: ['abc123', 'def456'],
        zip_name: 'bundle.zip'
      )

      expect(result[:status]).to eq('ok')
      expect(result[:download_url]).to eq('https://dl.example/file.zip')
      expect(result[:status_url]).to eq('https://dl.example/status/1')
      expect(result[:total_size]).to eq(46)
    end

    it 'returns downloader response without total size when status is error' do
      allow(DownloaderClient).to receive(:request_download_hash)
        .and_return({ status: 'error', error: 'downloader unavailable' })

      result = DownloaderClient.datafiles_download_hash(
        dataset: dataset,
        web_ids: ['abc123'],
        zip_name: 'bundle.zip'
      )

      expect(result).to eq({ status: 'error', error: 'downloader unavailable' })
    end

    it 'returns error when file path lookup fails while building targets' do
      allow(dataset.datafiles).to receive(:find_by).and_return(nil)

      result = DownloaderClient.datafiles_download_hash(
        dataset: dataset,
        web_ids: ['abc123'],
        zip_name: 'bundle.zip'
      )

      expect(result).to eq({ status: 'error', error: 'internal error file path not found' })
    end

    it 'returns error when no valid web ids are provided' do
      allow(DownloaderClient).to receive(:targets_arr)
        .and_return([])

      result = DownloaderClient.datafiles_download_hash(
        dataset: dataset,
        web_ids: ['missing'],
        zip_name: 'bundle.zip'
      )

      expect(result).to eq({ status: 'error', error: 'internal error no valid files found' })
    end

    it 'returns error when downloader service response is invalid' do
      allow(DownloaderClient).to receive(:request_download_hash)
        .and_return({ status: 'error', error: 'invalid response from downloader service' })

      result = DownloaderClient.datafiles_download_hash(
        dataset: dataset,
        web_ids: ['abc123'],
        zip_name: 'bundle.zip'
      )

      expect(result).to eq({ status: 'error', error: 'invalid response from downloader service' })
    end

    it 'returns error when downloader interaction raises' do
      allow(DownloaderClient).to receive(:request_download_hash)
        .and_return({ status: 'error', error: 'internal error downloading files' })

      result = DownloaderClient.datafiles_download_hash(
        dataset: dataset,
        web_ids: ['abc123'],
        zip_name: 'bundle.zip'
      )

      expect(result).to eq({ status: 'error', error: 'internal error downloading files' })
    end
  end

end
