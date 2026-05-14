FactoryBot.define do
  factory :file_download_tally do
    file_web_id { SecureRandom.hex(3) }
    filename { 'example.csv' }
    dataset_key { 'TESTIDB-1234567' }
    doi { '10.13012/B2IDB-1234567_V1' }
    download_date { Date.current }
    tally { 1 }
  end
end