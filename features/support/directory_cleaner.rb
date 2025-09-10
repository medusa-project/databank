require 'fileutils'
#before each test make sure that the strorage roots are empty
Before do
  StorageManager.instance.draft_root.delete_all_content
  StorageManager.instance.medusa_root.delete_all_content
end