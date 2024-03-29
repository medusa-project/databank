# frozen_string_literal: true

class MedusaIngest < ApplicationRecord
  def dataset_key
    if idb_class == "datafile"
      datafile = Datafile.find_by(web_id: idb_identifier)
      return nil unless datafile

      dataset = datafile.dataset
      dataset.key
    else
      idb_identifier
    end
  end

  def datafile_web_id
    return nil unless idb_class == "datafile"

    datafile = Datafile.find_by(web_id: idb_identifier)
    return nil unless datafile

    datafile.web_id
  end

  def draft_obj_exist?
    return false unless staging_key

    StorageManager.instance.draft_root.exist?(staging_key)
  end

  def medusa_obj_exist?
    return false unless target_key

    StorageManager.instance.medusa_root.exist?(target_key)
  end

  def self.incoming_queue
    IDB_CONFIG["medusa"]["incoming_queue"]
  end

  def self.outgoing_queue
    IDB_CONFIG["medusa"]["outgoing_queue"]
  end

  def self.on_medusa_message(response)
    response_hash = JSON.parse(response)

    if MedusaIngest.message_valid?(response) && response_hash["status"] == "ok"
      ingest_response = IngestResponse.new(status:        "ok",
                                           response_time: Time.current.iso8601,
                                           staging_key:   response_hash["staging_key"],
                                           medusa_key:    response_hash["medusa_key"],
                                           uuid:          response_hash["uuid"])
      ingest_response.as_text = response
      ingest_response.save!
      on_medusa_succeeded_message(response_hash)
    else
      IngestResponse.create!(as_text: response, status: response_hash["status"])
      on_medusa_failed_message(response_hash)
    end
  end

  def self.message_valid?(response)
    response_hash = JSON.parse(response)
    if
      response_hash.has_key?("status") && %w[ok error].include?(response_hash["status"])
      true
    else
      notification = DatabankMailer.error("invalid message, #{response_hash['status']}")
      notification.deliver_now
      false
    end
  end

  def self.send_dataset_to_medusa(dataset)
    ### skip datafiles already ingested, but send new system files ###
    file_time = Time.now.in_time_zone.strftime("%Y-%m-%d_%H-%M-%S")

    # START description file
    # always send a description file
    description_xml = dataset.to_datacite_xml
    description_key = "#{dataset.dirname}/system/description.#{file_time}.xml"
    StorageManager.instance.draft_root.write_string_to(description_key, description_xml)
    SystemFile.create(dataset_id: dataset.id, storage_root: "draft", storage_key: description_key, file_type: "description")

    medusa_ingest = MedusaIngest.new
    medusa_ingest.staging_key = description_key
    medusa_ingest.target_key = description_key
    medusa_ingest.idb_class = "description"
    medusa_ingest.idb_identifier = dataset.key
    medusa_ingest.save
    medusa_ingest.send_medusa_ingest_message

    # END description file

    # START datafiles
    # send existing draft datafiles not yet in medusa
    dataset.datafiles.each do |datafile|
      datafile_target_key = "#{dataset.dirname}/dataset_files/#{datafile.binary_name}"

      # does a medusa ingest record already exist for this record?
      existing_ingest = MedusaIngest.find_by(target_key: datafile_target_key)

      MedusaIngest.send_datafile_to_medusa(datafile.web_id) unless existing_ingest
    end
    # END datafiles

    # START deposit agreement
    draft_exists = StorageManager.instance.draft_root.exist?(dataset.draft_agreement_key)
    medusa_exists = StorageManager.instance.medusa_root.exist?(dataset.medusa_agreement_key)

    if draft_exists && !medusa_exists
      medusa_ingest = MedusaIngest.new
      medusa_ingest.staging_key = dataset.draft_agreement_key
      medusa_ingest.target_key = dataset.medusa_agreement_key
      medusa_ingest.idb_class = "agreement"
      medusa_ingest.idb_identifier = dataset.key
      medusa_ingest.save
      medusa_ingest.send_medusa_ingest_message

    elsif draft_exists && medusa_exists
      draft_size = StorageManager.instance.draft_root.size(dataset.draft_agreement_key)
      medusa_size = StorageManager.instance.medusa_root.size(dataset.medusa_agreement_key)
      if draft_size == medusa_size
        StorageManager.instance.draft_root.delete_content(dataset.draft_agreement_key)
      else
        exception_string = "Agreement file exists in both draft and medusa storage systems, but the sizes are different. Dataset: #{dataset.key}."
        notification = DatabankMailer.error(exception_string)
        notification.deliver_now
      end
    elsif !draft_exists && !medusa_exists
      exception_string = "Deposit agreement not found for Dataset: #{dataset.key}."
      notification = DatabankMailer.error(exception_string)
      notification.deliver_now
    end
    # END deposit agreement

    # START serialization
    # always send a serialization
    serialization_json = dataset.recovery_serialization.to_json
    serialization_key = "#{dataset.dirname}/system/serialization.#{file_time}.json"
    StorageManager.instance.draft_root.write_string_to(serialization_key, serialization_json)
    SystemFile.create(dataset_id:   dataset.id,
                      storage_root: "draft",
                      storage_key:  serialization_key,
                      file_type:    "serialization")

    medusa_ingest = MedusaIngest.new
    medusa_ingest.staging_key = serialization_key
    medusa_ingest.target_key = serialization_key
    medusa_ingest.idb_class = "serialization"
    medusa_ingest.idb_identifier = dataset.key
    medusa_ingest.send_medusa_ingest_message
    medusa_ingest.save
    # END serialization

    # START changelog
    # always send a changelog
    changelog_json = dataset.full_changelog.to_json
    changelog_key = "#{dataset.dirname}/system/changelog.#{file_time}.json"
    StorageManager.instance.draft_root.write_string_to(changelog_key, changelog_json)
    SystemFile.create(dataset_id:   dataset.id,
                      storage_root: "draft",
                      storage_key:  changelog_key,
                      file_type:    "changelog")

    medusa_ingest = MedusaIngest.new
    medusa_ingest.staging_key = changelog_key
    medusa_ingest.target_key = changelog_key
    medusa_ingest.idb_class = "changelog"
    medusa_ingest.idb_identifier = dataset.key
    medusa_ingest.send_medusa_ingest_message
    if medusa_ingest.save
      "ingest record #{IDB_CONFIG[:root_url_text]}/medusa_ingests/#{medusa_ingest.id}"
    else
      "error recording ingest record"
    end
  end

  def self.send_datafile_to_medusa(datafile_web_id)
    datafile = Datafile.find_by(web_id: datafile_web_id)

    return nil unless datafile
    return nil if datafile.in_medusa
    return nil unless datafile.storage_root
    return nil unless datafile.storage_key
    return nil unless StorageManager.instance.draft_root.exist?(datafile.storage_key)

    datafile_target_key = "#{datafile.dataset.dirname}/dataset_files/#{datafile.binary_name}"

    medusa_ingest = MedusaIngest.new
    medusa_ingest.staging_key = datafile.storage_key
    medusa_ingest.target_key = datafile_target_key
    medusa_ingest.idb_class = "datafile"
    medusa_ingest.idb_identifier = datafile.web_id
    medusa_ingest.save
    medusa_ingest.send_medusa_ingest_message
  end

  def self.on_medusa_succeeded_message(response_hash)
    draft_root = StorageManager.instance.draft_root
    medusa_root = StorageManager.instance.medusa_root

    ingest = nil

    ingest_relation = MedusaIngest.where(staging_key: response_hash["staging_key"]).order(:updated_at)

    if ingest_relation.count == 1
      ingest = ingest_relation.first
    elsif ingest_relation.count > 1
      ingest = ingest_relation.first
      ingest_relation.where.not(id: ingest.id).destroy_all
    else
      notification = DatabankMailer.error("Ingest not found. response_hash['pass_through'] #{response_hash['pass_through']} #{response_hash.to_yaml}")
      notification.deliver_now
      return false
    end

    unless ingest&.staging_key && ingest.staging_key != ""
      notification = DatabankMailer.error("Ingest not found for ingest suceeded message from Medusa. #{response_hash.to_yaml}")
      notification.deliver_now
      return false
    end

    # update ingest record to reflect the response
    ingest.medusa_path = response_hash["medusa_key"]
    ingest.medusa_uuid = response_hash["uuid"]
    ingest.response_time = Time.now.utc.iso8601
    ingest.request_status = response_hash["status"]
    ingest.save!

    file_class = response_hash["pass_through"]["class"]

    if file_class == "datafile"

      datafile = Datafile.find_by(web_id: response_hash["pass_through"]["identifier"])
      unless datafile
        notification = DatabankMailer.error("Datafile not found for ingest suceeded message from Medusa. #{response_hash.to_yaml}")
        notification.deliver_now
        return false
      end

      # datafile found - do things with datafile and ingest response
      # this method returns a boolean and also updates the datafile and removed draft binary, if it exists
      unless datafile.in_medusa
        notification = DatabankMailer.error("Datafile ingest failure. #{response_hash.to_yaml}")
        notification.deliver_now
        return false
      end

      datafile.medusa_id = response_hash["uuid"]
      datafile.medusa_path = response_hash["medusa_key"]
      if datafile.peek_type == Databank::PeekType::NONE &&
          Datafile.peek_type_from_mime(datafile.mime_type, datafile.binary_size) == Databank::PeekType::LISTING
        datafile.initiate_processing_task
      end
      datafile.save

      datafile.dataset.medusa_dataset_dir = response_hash["parent_dir"]["url_path"]
      datafile.dataset.save

    else
      dataset = Dataset.find_by(key: response_hash["pass_through"]["identifier"])
      unless dataset
        notification = DatabankMailer.error("Dataset not found for Medusa message. #{response_hash.to_yaml}")
        notification.deliver_now
        return false
      end

      # dataset found - do things with dataset and ingest response
      exists_in_draft = draft_root.exist?(response_hash["staging_key"])

      exists_in_medusa = medusa_root.exist?(response_hash["medusa_key"])
      if exists_in_medusa
        if exists_in_draft
          draft_size = draft_root.size(response_hash["staging_key"])
          medusa_size = medusa_root.size(response_hash["medusa_key"])
          if draft_size == medusa_size
            draft_root.delete_content(response_hash["staging_key"])
            info_key = "#{response_hash['staging_key']}.info"
            draft_root.delete_contant(info_key) if draft_root.exist?(info_key)
          else
            notification = DatabankMailer.error("file exists in both draft and medusa, but not same size #{response_hash.to_yaml}")
            notification.deliver_now
          end
        end

        system_files = SystemFile.where(dataset_id: dataset.id, storage_key: response_hash["staging_key"])
        system_file = nil
        if system_files.count == 1
          system_file = system_files.first
        elsif system_files.count > 1
          notification = DatabankMailer.error("multiple system files found dataset_id: #{dataset.id}, storage_key: #{response_hash['staging_key']}.")
          notification.deliver_now
        end

        if system_file
          system_file.update_attribute("storage_root", "medusa")
        else
          notification = DatabankMailer.error("Record not found for Medusa message. #{response_hash.to_yaml}")
          notification.deliver_now
          false
        end

      else
        notification = DatabankMailer.error("File not found for Medusa message. #{response_hash.to_yaml}")
        notification.deliver_now
        false
      end
    end
  end

  def self.on_medusa_failed_message(response_hash)
    error_string = "Problem ingesting #{response_hash.to_yaml} into Medusa."

    ingest_relation = MedusaIngest.where(staging_path: response_hash["staging_path"])
    if ingest_relation.count.positive?
      ingest = ingest_relation.first
      ingest.request_status = response_hash["status"]
      ingest.error_text = response_hash["error"]
      ingest.response_time = Time.current.iso8601
      ingest.save
    else
      error_string += "\nand could not find file for medusa failure message: #{response_hash['staging_path']}"
    end

    notification = DatabankMailer.error(error_string)
    notification.deliver_now
  end

  def self.remove_draft_if_in_medusa
    draft_root = StorageManager.instance.draft_root
    medusa_root = StorageManager.instance.medusa_root

    MedusaIngest.all.find_each do |ingest|
      next unless ingest.staging_key.present? && ingest.target_key.present?

      # dataset found - do things with dataset and ingest response
      exists_in_draft = draft_root.exist?(ingest.staging_key)
      exists_in_medusa = medusa_root.exist?(ingest.target_key)
      if exists_in_medusa
        puts "exists in medusa"
        if exists_in_draft
          puts "exists in draft"
          draft_size = draft_root.size(ingest.staging_key)
          medusa_size = medusa_root.size(ingest.target_key)
          if draft_size == medusa_size
            draft_root.delete_content(ingest.staging_key)
            info_key = "#{ingest.staging_key}.info"
            draft_root.delete_content(info_key) if draft_root.exist?(info_key)
          else
            puts "draft and medusa sizes not equal for ingest: #{ingest.id}, draft_size: #{draft_size}, medusa_size: #{medusa_size}"
          end
        else
          puts "does not exist in draft"
        end
      else
        puts "does not exist in medusa"
      end
    end
  end

  def send_medusa_ingest_message
    if Application.server_envs.include?(Rails.env)
      if IDB_CONFIG[:rabbit_or_sqs] == "rabbit"
        AmqpHelper::Connector[:databank].send_message(MedusaIngest.outgoing_queue, medusa_ingest_message)
      else
        sqs = QueueManager.instance.sqs_client
        sqs.send_message(queue_url:                IDB_CONFIG[:queues][:databank_to_medusa_url],
                         message_body:             medusa_ingest_message.to_json)
      end
    end
  end

  def medusa_ingest_message
    {operation:    "ingest",
     staging_key:  staging_key,
     target_key:   target_key,
     pass_through: {class: idb_class, identifier: idb_identifier}}
  end
end
