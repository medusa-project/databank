class AddHoldStateToDatasets < ActiveRecord::Migration[4.2]
  def change
    add_column :datasets, :hold_state, :string, default: "none"
  end
end
