class AddJobIdToDatafiles < ActiveRecord::Migration[4.2]
  def change
    add_column :datafiles, :job_id, :integer
  end
end
