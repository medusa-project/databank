class RenameLicenseToLicenseInfo < ActiveRecord::Migration
  def change
    rename_table :licenses, :license_infos
  end

  def self.down
    rename_table :license_infos, :licenses
  end
end
