require 'rails_helper'

RSpec.describe MedusaIngest, type: :model do
  let(:dataset) { Dataset.find_by_key("TESTIDB-5920542") }
  let(:datafile) { Datafile.find_by_web_id("eetmg") }
  let(:response_hash) { { "staging_key" => "does_not_matter", "medusa_key" => "DOI-10-70114-testidb-5920542_v1/dataset_files/geometry_topics.doc", "uuid" => "uuid", "parent_dir" => {"url_path" => "example.org/placeholder"}, "pass_through" => { "class" => "datafile", "identifier" => datafile.web_id } } }

  describe '#dataset_key' do
    it 'returns the dataset key for a datafile ingest' do
      medusa_ingest = MedusaIngest.new(idb_class: 'datafile', idb_identifier: datafile.web_id)
      expect(medusa_ingest.dataset_key).to eq(dataset.key)
      MedusaIngest.destroy_all
    end

    it 'returns the dataset_key for dataset ingest' do
      medusa_dataset_ingest = create(:medusa_ingest, idb_class: 'dataset', idb_identifier: dataset.key) 
      expect(medusa_dataset_ingest.idb_identifier).to eq(dataset.key)
      expect(medusa_dataset_ingest.dataset_key).to eq(medusa_dataset_ingest.idb_identifier)
      MedusaIngest.destroy_all
    end
  end

  describe '#datafile_web_id' do
    it 'returns the web_id of the datafile for a datafile ingest' do
      medusa_ingest = MedusaIngest.new(idb_class: 'datafile', idb_identifier: datafile.web_id)
      expect(medusa_ingest.datafile_web_id).to eq(datafile.web_id)
      MedusaIngest.destroy_all
    end

    it 'returns nil for dataset ingest' do
      medusa_dataset_ingest = create(:medusa_ingest, idb_class: 'dataset', idb_identifier: dataset.key)
      expect(medusa_dataset_ingest.datafile_web_id).to be_nil
    end
  end

  describe '#draft_obj_exist?' do
    context "draft datafile exists" do

      after do
        MedusaIngest.destroy_all
      end

      it 'returns true if the object exists in the draft storage system' do
        datafile = Datafile.find_by(web_id: "y7jq0")
        datafile_target_key = "#{datafile.dataset.dirname}/dataset_files/#{datafile.binary_name}"
        medusa_ingest = MedusaIngest.new
        medusa_ingest.staging_key = datafile.storage_key
        medusa_ingest.target_key = datafile_target_key
        medusa_ingest.idb_class = "datafile"
        medusa_ingest.idb_identifier = datafile.web_id
        medusa_ingest.save
        expect(medusa_ingest.draft_obj_exist?).to be true
      end
    end

    context "draft datafile does not exist" do
      after do
        MedusaIngest.destroy_all
      end
      it 'returns false if the object does not exist in the draft storage system' do
        datafile = Datafile.find_by(web_id: "eetmg")
        datafile_target_key = "#{datafile.dataset.dirname}/dataset_files/#{datafile.binary_name}"
        medusa_ingest = MedusaIngest.new
        medusa_ingest.staging_key = "invalid_key"
        medusa_ingest.target_key = datafile_target_key
        medusa_ingest.idb_class = "datafile"
        medusa_ingest.idb_identifier = datafile.web_id
        medusa_ingest.save
        key_exists_on_draft_root = StorageManager.instance.draft_root.exist?(medusa_ingest.staging_key)
        expect(medusa_ingest.draft_obj_exist?).to be false
      end
    end
  end

  describe '#medusa_obj_exist?' do
    context "medusa datafile exists" do
      after do
        MedusaIngest.destroy_all
      end
      it 'returns true if the object exists in the medusa storage system' do
        datafile = Datafile.find_by(web_id: "eetmg")
        datafile_target_key = "#{datafile.dataset.dirname}/dataset_files/#{datafile.binary_name}"
        medusa_ingest = MedusaIngest.new
        medusa_ingest.staging_key = "does_not_matter"
        medusa_ingest.target_key = datafile.storage_key
        medusa_ingest.idb_class = "datafile"
        medusa_ingest.idb_identifier = datafile.web_id
        medusa_ingest.save
        expect(medusa_ingest.medusa_obj_exist?).to be true
      end
    end

    context "medusa datafile does not exist" do
      after do
        MedusaIngest.destroy_all
      end
      it 'returns false if the object does not exist in the medusa storage system' do
        datafile = Datafile.find_by(web_id: "eetmg")
        datafile_target_key = "#{datafile.dataset.dirname}/dataset_files/#{datafile.binary_name}"
        medusa_ingest = MedusaIngest.new
        medusa_ingest.staging_key = "does_not_matter"
        medusa_ingest.target_key = "invalid_key"
        medusa_ingest.idb_class = "datafile"
        medusa_ingest.idb_identifier = datafile.web_id
        medusa_ingest.save
        expect(medusa_ingest.medusa_obj_exist?).to be false
      end
    end
  end

  describe '.incoming_queue' do
    it 'returns the name of the incoming queue from config' do
      expect(MedusaIngest.incoming_queue).to eq(IDB_CONFIG["medusa"]["incoming_queue"])
    end
  end

  describe '.outgoing_queue' do
    it 'returns the name of the outgoing queue from config' do
      expect(MedusaIngest.outgoing_queue).to eq(IDB_CONFIG["medusa"]["outgoing_queue"])
    end
  end

  describe '.on_medusa_message' do
    
    it 'processes a valid message from Medusa' do
      datafile_target_key = "#{datafile.dataset.dirname}/dataset_files/#{datafile.binary_name}"
      medusa_ingest = MedusaIngest.new
      medusa_ingest.staging_key = "does_not_matter"
      medusa_ingest.target_key = datafile.storage_key
      medusa_ingest.idb_class = "datafile"
      medusa_ingest.idb_identifier = datafile.web_id
      medusa_ingest.save
      response = response_hash.to_json
      allow(MedusaIngest).to receive(:message_valid?).and_return(true)
      expect { MedusaIngest.on_medusa_message(response) }.to change { IngestResponse.count }.by(1)
    end

    it 'processes an invalid message from Medusa' do
      response = { "status" => "invalid" }.to_json
      allow(MedusaIngest).to receive(:message_valid?).and_return(false)
      expect { MedusaIngest.on_medusa_message(response) }.to change { IngestResponse.count }.by(1)
    end
  end

  describe '.message_valid?' do
    let(:response) { { "status" => "ok" }.to_json }

    it 'returns true for a valid message' do
      expect(MedusaIngest.message_valid?(response)).to be true
    end

    it 'returns false for an invalid message' do
      invalid_response = { "status" => "invalid" }.to_json
      expect(MedusaIngest.message_valid?(invalid_response)).to be false
    end
  end

  describe '.send_dataset_to_medusa' do
    it 'sends a dataset to Medusa' do
      allow(StorageManager.instance.draft_root).to receive(:write_string_to)
      allow(MedusaIngest).to receive(:send_datafile_to_medusa)
      # separate ingests are created for dataset system files and each datafile
      expect { MedusaIngest.send_dataset_to_medusa(dataset) }.to change { MedusaIngest.count }.by(3)
    end
  end

  describe '.send_datafile_to_medusa' do
    it 'sends a datafile to Medusa' do
      allow(StorageManager.instance.draft_root).to receive(:exist?).and_return(true)
      expect { MedusaIngest.send_datafile_to_medusa(datafile.web_id) }.to change { MedusaIngest.count }.by(1)
    end
  end

  # describe '.on_medusa_succeeded_message' do
    
  #   context "medusa ingest for datafile exists" do

  #     before do
  #       MedusaIngest.destroy_all
  #     end
  #     after do
  #       MedusaIngest.destroy_all
  #     end
  #     it 'handles a successful message from Medusa' do
  #       datafile = Datafile.find_by(web_id: "eetmg")
  #       datafile_target_key = "#{datafile.dataset.dirname}/dataset_files/#{datafile.binary_name}"
  #       medusa_ingest = MedusaIngest.new
  #       medusa_ingest.staging_key = "does_not_matter"
  #       medusa_ingest.target_key = datafile_target_key
  #       medusa_ingest.idb_class = "datafile"
  #       medusa_ingest.idb_identifier = datafile.web_id
  #       medusa_ingest.save
  #       expect(MedusaIngest.on_medusa_succeeded_message(response_hash)).to be true
  #     end
  #   end
  # end

  describe '.on_medusa_failed_message' do
    let(:response_hash) { { "staging_key" => "staging_key", "status" => "error", "error" => "error message" } }

    it 'handles a failed message from Medusa' do
      expect { MedusaIngest.on_medusa_failed_message(response_hash) }.to change { MedusaIngest.count }.by(0)
    end
  end

  # describe '#send_medusa_ingest_message' do
  #   it 'sends the ingest message to Medusa' do
  #     allow(Application).to receive(:server_envs).and_return([Rails.env])
  #     allow(IDB_CONFIG).to receive(:[]).with(:rabbit_or_sqs).and_return("rabbit")
  #     allow(AmqpHelper::Connector[:databank]).to receive(:send_message)
  #     medusa_ingest.send_medusa_ingest_message
  #     expect(AmqpHelper::Connector[:databank]).to have_received(:send_message)
  #   end
  # end

  # describe '#medusa_ingest_message' do
  #   it 'creates the ingest message for Medusa' do
  #     expect(medusa_ingest.medusa_ingest_message).to eq({ operation: "ingest", staging_key: medusa_ingest.staging_key, target_key: medusa_ingest.target_key, pass_through: { class: medusa_ingest.idb_class, identifier: medusa_ingest.idb_identifier } })
  #   end
  # end
end