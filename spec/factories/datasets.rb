# spec/factories/datasets.rb
FactoryBot.define do
  factory :dataset do
    title { "Measurements" }
    depositor_name { "Rowan Doe" }
    depositor_email { "rowan.doe@mailinator.com" }
    publication_state { "draft" }
    key { "TESTIDB-#{SecureRandom.hex(7)}" }
    publisher { "University of Illinois Urbana-Champaign" }
    description { "Heights, Weights, and Counts" }
    license { "CC01" }
    corresponding_creator_name { "Rowan Doe" }
    corresponding_creator_email { "rowan.doe@mailinator.com" }
    curator_hold { false }
    embargo { "none" }
    is_test { false }
    is_import { false }
    have_permission { "yes" }
    removed_private { "na" }
    agree { "yes" }
    hold_state { "none" }
    medusa_dataset_dir { "" }
    dataset_version { "1" }
    suppress_changelog { false }
    version_comment { "" }
    subject { "" }
    org_creators { false }
    data_curation_network { false }
  end
end
