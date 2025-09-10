class RemoveTallyFromDayFileDownloads < ActiveRecord::Migration
  def change
    remove_column :day_file_downloads, :tally, :integer
  end
end
