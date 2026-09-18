class AddTaskIdToDatafiles < ActiveRecord::Migration[4.2]
  def change
    add_column :datafiles, :task_id, :integer, limit: 8
  end
end
