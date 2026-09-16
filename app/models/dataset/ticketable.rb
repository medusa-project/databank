# frozen_string_literal: true

## Provides functionality for creating TeamDynamix tickets associated with a dataset.
module Dataset::Ticketable
  extend ActiveSupport::Concern

  def ticket_review_request(msg:, requestor_uid: TdxClient::NOREPLY_REQUESTOR_UID, form_id: TdxClient::FORM_ID)
    existing_ticket = find_existing_ticket
    if existing_ticket
      update_ticket(ticket_id: ticket_id_from(existing_ticket) || ticket_id,
                    requestor_uid: requestor_uid,
                    form_id: form_id,
                    msg: msg)
    else
      create_ticket(requestor_uid: requestor_uid, form_id: form_id, msg: msg)
    end
  end

  def create_ticket(requestor_uid: TdxClient::NOREPLY_REQUESTOR_UID, form_id: TdxClient::FORM_ID, msg:)
    title = "[Dataset] #{key}"
    description = "Dataset: #{databank_url}\n\nMessage: #{msg}"
    response = TdxClient.instance.create_ticket(
      title:         title,
      description:   description,
      requestor_uid: requestor_uid,
      form_id:       form_id
    )

    ticket_id = ticket_id_from(response)
    raise "TeamDynamix ticket creation response did not include an ID" if ticket_id.blank?

    update!(ticket_id: ticket_id)

    response
  end

  def ticket_url
    return nil if ticket_id.blank?

    "#{IDB_CONFIG[:tdx][:ticket_url_base]}#{ticket_id}"
  end

  private

  def update_ticket(ticket_id:, requestor_uid: TdxClient::NOREPLY_REQUESTOR_UID, form_id: TdxClient::FORM_ID, msg:)
    title = "[Dataset] #{key}"
    description = "Dataset: #{databank_url}\n\nMessage: #{msg}"
    TdxClient.instance.update_ticket(
      ticket_id:     ticket_id,
      title:         title,
      description:   description,
      requestor_uid: requestor_uid,
      form_id:       form_id
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
    return ticket.id if ticket.respond_to?(:id)
  end
end
