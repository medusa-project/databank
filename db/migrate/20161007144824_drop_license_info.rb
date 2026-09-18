class DropLicenseInfo < ActiveRecord::Migration[4.2]
  def change
    drop_table :license_infos
  end
end
