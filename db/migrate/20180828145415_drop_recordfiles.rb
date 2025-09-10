class DropRecordfiles < ActiveRecord::Migration
  def change
    drop_table :recordfiles
  end
end
