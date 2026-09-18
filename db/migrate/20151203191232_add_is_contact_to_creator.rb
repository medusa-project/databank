class AddIsContactToCreator < ActiveRecord::Migration[4.2]
  def change
    add_column :creators, :is_contact, :boolean, null: false, default: false
  end
end
