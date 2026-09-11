# frozen_string_literal: true

## Provides functionality for creating TeamDynamix tickets associated with a dataset.
module Dataset::Ticketable
  extend ActiveSupport::Concern

  def ticket_review_request(msg:)
    existing_ticket = find_existing_ticket
    if existing_ticket
      update_ticket(ticket_id: existing_ticket.id, requestor_uid: requestor_uid, form_id: form_id, msg: msg)
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

    ticket_id = response["ID"] || response["id"]
    update!(ticket_id: ticket_id) if ticket_id.present?

    response
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
    # if there is no existing ticket, return nil
    nil
  end
end
