class VersionFile < ApplicationRecord
  belongs_to :dataset
  def source_datafile
    Datafile.find_by_id(self.datafile_id)
  end
end
