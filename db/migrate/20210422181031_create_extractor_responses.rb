class CreateExtractorResponses < ActiveRecord::Migration[6.1]
  def change
    create_table :extractor_responses do |t|
      t.integer :extractor_task_id
      t.string :web_id
      t.string :status
      t.string :peek_type
      t.string :peek_text

      t.timestamps
    end
  end
end
