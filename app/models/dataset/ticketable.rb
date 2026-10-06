# frozen_string_literal: true

## Provides functionality for creating TeamDynamix tickets associated with a dataset.
module Dataset::Ticketable
  extend ActiveSupport::Concern

  def consult_ticket_attributes
    [
      { "ID": TdxClient::CONSULT_ATTRIBUTE_ID,
        "Value": key,
        "ValueText": key}
    ]
  end

  def current_contacts
    TdxClient.instance.contacts(ticket_id: ticket_id)
  end

  def depositor_uid
    TdxClient.instance.person_uid_from_email(email: depositor_email)
  end

  def add_contact(email:)
    handle_missing_ticket if ticket_id.blank?

    person_id = TdxClient.instance.person_uid_from_email(email: email)
    if person_id.blank?
      handle_missing_person(email: email)
      return
    end

    TdxClient.instance.add_contact(ticket_id: ticket_id, person_uid: person_id)
  end

  def remove_contact(email:)
    handle_missing_ticket if ticket_id.blank?

    person_id = TdxClient.instance.person_uid_from_email(email: email)
    if person_id.blank?
      handle_missing_person(email: email)
      return
    end

    TdxClient.instance.remove_contact(ticket_id: ticket_id, person_uid: person_id)
  end

  def ticket_review_request(requestor_email:, msg:)
    existing_ticket = find_existing_ticket
    if existing_ticket
      TdxClient.instance.add_comment(ticket_id: existing_ticket["ID"], comment: msg, notify: ["#{requestor_email}"])
    else
      create_consult_ticket(msg: msg, attributes: consult_ticket_attributes)
    end
  end

  def create_ticket_for_legacy
    raise "Ticket already exists for this dataset" if ticket_id.present?

    message = "Review requested by: #{depositor_name}, #{depositor_email}" \
      "\n\nTicket created for dataset pre-existing in the system before " \
      "implementation of TeamDynamix ticketing. Requestor presumed to be depositor, " \
      "but might be any author or otherauthorized editor. "

    create_consult_ticket(attributes: consult_ticket_attributes, msg: message)
  rescue StandardError => e
    Rails.logger.error("Failed to create legacy ticket: #{e.message}")
    nil
  end

  def create_non_consult_ticket(msg:)
    create_dataset_ticket(msg: msg, form_id: TdxClient::FORM_ID, requestor_uid: depositor_uid, error_label: "non-consult")
  end

  def create_consult_ticket(requestor_email: depositor_email, msg:, attributes: consult_ticket_attributes)
    requestor_uid = TdxClient.instance.person_uid_from_email(email: requestor_email)

    create_dataset_ticket(
      msg:         msg,
      form_id:     TdxClient::CONSULT_FORM_ID,
      requestor_uid: requestor_uid,
      attributes:  attributes,
      error_label: "consult"
    )
  end

  def ticket_url
    return nil if ticket_id.blank?

    "#{TICKET_CONFIG[:ticket_url_base]}#{ticket_id}"
  end

  def update_ticket(ticket_id:, msg:)
    title = "[Dataset] #{key}"
    description = "Dataset: #{databank_url}\n\nMessage: #{msg}"
    TdxClient.instance.update_ticket(
      ticket_id:   ticket_id,
      title:       title,
      description: description
    )
  end

  def find_existing_ticket
    if ticket_id.present?
      TdxClient.instance.find_ticket_by_id(ticket_id)
    else
      TdxClient.instance.find_ticket_by_title("[Dataset] #{key}")
    end
  end

  def ticket_id_from(ticket)
    return ticket["ID"] || ticket["id"] if ticket.is_a?(Hash)
    return ticket.ID if ticket.respond_to?(:ID)

    ticket.id if ticket.respond_to?(:id)
  end

  def add_comment(change:)
    TdxClient.instance.add_comment(ticket_id: ticket_id, comment: change) if ticket_id.present?
  end

  def handle_prepub_metadata_change(change_type:, details:)
    raise "Pre-publication change handling occurred outside of prepub state" unless in_pre_publication_review?

    create_consult_ticket if ticket_id.blank?
    handle_missing_ticket if ticket_id.blank?
    change = "Change of type #{change_type} occurred: #{details}."
    add_comment(change: change)
  end

  def handle_prepub_file_change(datafile:, change_type:)
    raise "Pre-publication change handling occurred outside of prepub state" unless in_pre_publication_review?

    create_consult_ticket if ticket_id.blank?
    handle_missing_ticket if ticket_id.blank?
    change = "Datafile #{change_type}" \
             "web_id #{datafile.web_id}, name: #{datafile.binary_name}."
    add_comment(change: change)
  end

  def handle_missing_person(email:)
    add_comment(change: "No person found with email: #{email}")
  end

  def handle_missing_ticket(note: "No ticket found for this dataset")
    # use DatabankMailer to notify about the missing ticket
    DatabankMailer.missing_ticket(dataset_key: key, note: note).deliver_now
  end

  private

  def create_dataset_ticket(msg:, form_id:, requestor_uid:, attributes: nil, error_label:)
    ticket_options = {
      title:       "[Dataset] #{key}",
      description: "Dataset: #{databank_url}\n\nMessage: #{msg}",
      form_id:     form_id,
      attributes:  attributes
    }
    ticket_options[:requestor_uid] = requestor_uid unless requestor_uid.nil?

    ticket_id = TdxClient.instance.create_ticket(**ticket_options)

    return nil if ticket_id.nil?

    raise "TeamDynamix ticket creation response did not include an ID" if ticket_id.blank?

    update!(ticket_id: ticket_id)
    ticket_id
  rescue StandardError => e
    handle_missing_ticket(note: "Failed to create #{error_label} TeamDynamix ticket for dataset #{key}: #{e.message}")
    nil
  end
end
