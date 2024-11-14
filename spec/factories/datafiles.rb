# spec/factories/datafiles.rb
# Precondition: File objects stored in minio as populated by testing:store_seed_datafiles task, run by bin/setup_local
FactoryBot.define do
  factory :datafile do
    description { "Sample description" }
    web_id { SecureRandom.hex(3) } # Generates a 6-character hex string
    dataset
    binary_name { "sample.txt" }
    binary_size { nil }
    upload_file_size { nil }
    upload_status { nil }
    mime_type { "text/plain" }
    storage_root { "draft" }
    storage_key { "7d41357d5f2f232a22ab1cad67c6f34b" }
    medusa_id { SecureRandom.uuid }
    medusa_path { nil }
    box_filename { nil }
    box_filesize_display { nil }
    peek_type { "none" }
    peek_text { nil }
    task_id { nil}
    job_id { nil }
  end
end
