class UpdateExtractorResponseColumnName < ActiveRecord::Migration[6.1]
  def change
    rename_column :extractor_tasks, :response, :raw_response
  end
end
