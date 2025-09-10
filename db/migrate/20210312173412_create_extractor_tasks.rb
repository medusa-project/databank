class CreateExtractorTasks < ActiveRecord::Migration[6.0]
  def change
    create_table :extractor_tasks do |t|
      t.string :web_id
      t.datetime :response_at
      t.string :response

      t.timestamps
    end
  end
end
