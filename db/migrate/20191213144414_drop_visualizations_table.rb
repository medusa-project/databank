class DropVisualizationsTable < ActiveRecord::Migration[5.2]
  def change
    drop_table :visualizations
  end
end
