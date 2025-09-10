class AddSentAtToExtractorTask < ActiveRecord::Migration[6.1]
  def change
    add_column :extractor_tasks, :sent_at, :datetime
  end
end
