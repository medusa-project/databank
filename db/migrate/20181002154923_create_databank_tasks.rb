class CreateDatabankTasks < ActiveRecord::Migration
  def change
    create_table :databank_tasks do |t|
      t.integer :task_id
      t.text :status

      t.timestamps null: false
    end
  end
end
