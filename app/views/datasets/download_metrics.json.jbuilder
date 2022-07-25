json.dataset_downloads do

  json.doi @dataset, :identifier
  json.dataset_total_downloads @dataset, :total_downloads
  json.dataset_download_tallies @dataset.dataset_download_tallies, :download_date, :tally

  json.files @dataset.complete_datafiles do |datafile|
    json.filename datafile.bytestream_name
    json.file_total_downloads datafile.total_downloads
    json.file_download_tallies datafile.file_download_tallies, :download_date, :tally
  end

end