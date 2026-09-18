class RemoveTallyFromDayFileDownloads < ActiveRecord::Migration[4.2]
  def change
    remove_column :day_file_downloads, :tally, :integer
  end
end
