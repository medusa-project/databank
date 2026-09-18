class AddEmailToCreator < ActiveRecord::Migration[4.2]
  def change
    add_column :creators, :email, :string
  end
end
