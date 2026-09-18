class RemoveAdminIndex < ActiveRecord::Migration[4.2]
  def change
    remove_index(:admin, name: "index_admin_on_singleton_guard")
  end
end
