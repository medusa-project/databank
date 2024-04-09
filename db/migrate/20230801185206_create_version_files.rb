class CreateVersionFiles < ActiveRecord::Migration[7.0]
  def change
    create_table :version_files do |t|
      t.references :dataset, null: false, foreign_key: true
      t.integer :datafile_id
      t.boolean :selected

      t.timestamps
    end
  end
end
