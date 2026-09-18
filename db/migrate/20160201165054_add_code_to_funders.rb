class AddCodeToFunders < ActiveRecord::Migration[4.2]
  def change
    add_column :funders, :code, :string
  end
end
