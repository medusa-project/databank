class CreateLicenses < ActiveRecord::Migration
  def change
    create_table :licenses do |t|
      t.string :code
      t.string :name
      t.string :external_info_url
      t.string :full_text_url
      t.string :idb_help_url

      t.timestamps null: false
    end
  end
end
