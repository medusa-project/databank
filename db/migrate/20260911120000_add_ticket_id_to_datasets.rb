class AddTicketIdToDatasets < ActiveRecord::Migration[7.2]
  def change
    add_column :datasets, :ticket_id, :integer, null: true
  end
end
