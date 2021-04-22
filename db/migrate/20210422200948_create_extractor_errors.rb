class CreateExtractorErrors < ActiveRecord::Migration[6.1]
  def change
    create_table :extractor_errors do |t|
      t.integer :extractor_response_id
      t.string :error_type
      t.string :report

      t.timestamps
    end
  end
end
