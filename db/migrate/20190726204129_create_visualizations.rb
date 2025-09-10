class CreateVisualizations < ActiveRecord::Migration[5.2]
  def change
    create_table :visualizations do |t|
      t.string :dataset_key
      t.string :datafile_web_id
      t.text :data
      t.text :options
      t.string :chart_class

      t.timestamps
    end
  end
end
