# frozen_string_literal: true

## Provides functionality for creating TeamDynamix tickets associated with a dataset.
module Dataset::Ticketable
  extend ActiveSupport::Concern

  def ticket_review_request(msg:)
    existing_ticket = find_existing_ticket
    if existing_ticket
      update_ticket(ticket_id: ticket_id, msg: msg)
    else
      create_ticket(msg: msg)
    end
  end

  def create_ticket(msg:)
    title = "[Dataset] #{key}"
    description = "Dataset: #{databank_url}\n\nMessage: #{msg}"
    response = TdxClient.instance.create_ticket(
      title:       title,
      description: description
    )

    ticket_id = ticket_id_from(response)
    return nil if ticket_id.blank? && response.nil?

    raise "TeamDynamix ticket creation response did not include an ID" if ticket_id.blank?

    update!(ticket_id: ticket_id)

    response
  end

  def ticket_url
    return nil if ticket_id.blank?

    "#{IDB_CONFIG[:tdx][:ticket_url_base]}#{ticket_id}"
  end

  def record_change(change:)
    TdxClient.instance.add_comment(ticket_id: ticket_id, comment: change) if ticket_id.present?
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
    return ticket.id if ticket.respond_to?(:id)
  end
end
