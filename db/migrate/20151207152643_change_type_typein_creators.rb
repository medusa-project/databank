class ChangeTypeTypeinCreators < ActiveRecord::Migration
  def change
    change_column :creators, :type, 'integer USING CAST(type as integer)'
  end
end
