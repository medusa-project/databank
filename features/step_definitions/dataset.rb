When("I publish a draft dataset") do
  dataset = FactoryBot.create(:dataset)
  FactoryBot.create(:creator, {dataset_id: dataset.id})
  datafile = FactoryBot.create(:datafile, {dataset_id: dataset.id})
  StorageManager.instance.draft_root.write_string_to(datafile.storage_key, "test")
  dataset = Dataset.find_by(id: dataset.id) # to populate nested collections
  dataset.publish(User.system_user)
end
