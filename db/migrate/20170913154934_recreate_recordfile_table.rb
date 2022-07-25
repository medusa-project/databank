class RecreateRecordfileTable < ActiveRecord::Migration
  # Somehow there is a schema that does not have this table. I think it happened during a tricky revert-and-branch
  # So, since this feature has not been implemented in production yet, I am just going to drop the table if it exists
  # and then create the table all over again.
  # Hopefully, this will fix the schema.rb file. (Because trying ot fix it manually lead to unresponsive spinning.)

  def change

    drop_table :recordfiles if (table_exists? :recordfiles)

    create_table :recordfiles do |t|
      t.integer :dataset_id
      t.string :binary
      t.string :web_id
      t.string :medusa_id
      t.string :medusa_path
      t.string :binary_name
      t.integer :binary_size

      t.timestamps null: false
    end
  end
end
