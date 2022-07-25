class AddJobIdToDatafiles < ActiveRecord::Migration
  def change
    add_column :datafiles, :job_id, :integer
  end
end
