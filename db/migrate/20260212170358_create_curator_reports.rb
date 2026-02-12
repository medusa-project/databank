class CreateCuratorReports < ActiveRecord::Migration[7.2]
  def change
    create_table :curator_reports do |t|
      t.string :requestor_name
      t.string :requestor_email
      t.string :report_type
      t.string :storage_root
      t.string :storage_key
      t.string :notes

      t.timestamps
    end
  end
end
