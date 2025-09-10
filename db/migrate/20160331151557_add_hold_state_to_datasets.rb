class AddHoldStateToDatasets < ActiveRecord::Migration
  def change
    add_column :datasets, :hold_state, :string, default: "none"
  end
end
