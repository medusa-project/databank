class DropRecordfiles < ActiveRecord::Migration[4.2]
  def change
    drop_table :recordfiles
  end
end
