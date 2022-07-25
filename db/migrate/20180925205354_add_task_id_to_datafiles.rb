class AddTaskIdToDatafiles < ActiveRecord::Migration
  def change
    add_column :datafiles, :task_id, :integer, limit: 8
  end
end
