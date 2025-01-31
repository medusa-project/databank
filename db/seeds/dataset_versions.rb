ds1 = Dataset.create!("title": "The Google Fonts: a preliminary analysis",
                      "publisher": "University of Illinois Urbana-Champaign",
                      "publication_year": "2023",
                      "description": "This dataset was created to answer the following question:  Is the Databank working properly as datasets and datafiles are propagated for testing.",
                      "license": "CCBY4",
                      "keywords": "font; nonsense; test",
                      "depositor_name": "Colleen Fallaw",
                      "depositor_email": "mfall3@illinois.edu",
                      corresponding_creator_name: "Colleen Fallaw",
                      corresponding_creator_email: "mfall3@illinois.edu",
                      embargo: "none",
                      is_test: true,
                      is_import: true,
                      identifier: "testidb-123_v1",
                      publication_state: "released",
                      release_date: Date.current,
                      have_permission: "yes",
                      removed_private: "yes",
                      agree: "yes",
                      hold_state: "none",
                      dataset_version: "1",
                      version_comment: "test version 1"
)
Creator.create!(
                   dataset_id: ds1.id,
                   family_name: "Fallaw",
                   given_name: "Colleen",
                   type_of: 0,
                   row_order: nil,
                   email: "mfall3@illinois.edu",
                   is_contact: true,
                   row_position: nil,
                   identifier_scheme: nil
)