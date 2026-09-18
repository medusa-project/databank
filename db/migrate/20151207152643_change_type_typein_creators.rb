class ChangeTypeTypeinCreators < ActiveRecord::Migration[4.2]
  def change
    change_column :creators, :type, 'integer USING CAST(type as integer)'
  end
end
