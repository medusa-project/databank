class DropLicenseInfo < ActiveRecord::Migration
  def change
    drop_table :license_infos
  end
end
