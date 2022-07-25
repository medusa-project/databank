class AddCodeToFunders < ActiveRecord::Migration
  def change
    add_column :funders, :code, :string
  end
end
