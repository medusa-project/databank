class AddIsContactToCreator < ActiveRecord::Migration
  def change
    add_column :creators, :is_contact, :boolean, null: false, default: false
  end
end
