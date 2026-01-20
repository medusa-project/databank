# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2026_01_20_174126) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "audits", id: :serial, force: :cascade do |t|
    t.integer "auditable_id"
    t.string "auditable_type"
    t.integer "associated_id"
    t.string "associated_type"
    t.integer "user_id"
    t.string "user_type"
    t.string "username"
    t.string "action"
    t.text "audited_changes"
    t.integer "version", default: 0
    t.string "comment"
    t.string "remote_address"
    t.string "request_uuid"
    t.datetime "created_at"
    t.index ["associated_type", "associated_id"], name: "associated_index"
    t.index ["auditable_type", "auditable_id"], name: "auditable_index"
    t.index ["created_at"], name: "index_audits_on_created_at"
    t.index ["request_uuid"], name: "index_audits_on_request_uuid"
    t.index ["user_id", "user_type"], name: "user_index"
  end

  create_table "contributors", id: :serial, force: :cascade do |t|
    t.integer "dataset_id"
    t.string "family_name"
    t.string "given_name"
    t.string "institution_name"
    t.string "identifier"
    t.integer "type_of"
    t.integer "row_order"
    t.string "email"
    t.integer "row_position"
    t.string "identifier_scheme"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "creators", id: :serial, force: :cascade do |t|
    t.integer "dataset_id"
    t.string "family_name"
    t.string "given_name"
    t.string "institution_name"
    t.string "identifier"
    t.integer "type_of"
    t.integer "row_order"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "email"
    t.boolean "is_contact", default: false, null: false
    t.integer "row_position"
    t.string "identifier_scheme"
  end

  create_table "databank_tasks", id: :serial, force: :cascade do |t|
    t.integer "task_id"
    t.text "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "datafiles", id: :serial, force: :cascade do |t|
    t.string "description"
    t.string "binary"
    t.string "web_id"
    t.integer "dataset_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "job_id"
    t.string "box_filename"
    t.string "box_filesize_display"
    t.string "medusa_id"
    t.string "medusa_path"
    t.string "binary_name"
    t.bigint "binary_size"
    t.bigint "upload_file_size"
    t.string "upload_status"
    t.string "peek_type"
    t.text "peek_text"
    t.string "storage_root"
    t.string "storage_prefix"
    t.string "storage_key"
    t.string "mime_type"
    t.bigint "task_id"
    t.boolean "in_globus"
  end

  create_table "dataset_download_tallies", id: :serial, force: :cascade do |t|
    t.string "dataset_key"
    t.string "doi"
    t.date "download_date"
    t.integer "tally"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["dataset_key"], name: "index_dataset_download_tallies_on_dataset_key"
  end

  create_table "datasets", id: :serial, force: :cascade do |t|
    t.string "key", null: false
    t.string "title"
    t.string "creator_text"
    t.string "identifier"
    t.string "publisher"
    t.string "description"
    t.string "license"
    t.string "depositor_name"
    t.string "depositor_email"
    t.boolean "complete"
    t.string "corresponding_creator_name"
    t.string "corresponding_creator_email"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "keywords"
    t.string "publication_state", default: "draft"
    t.boolean "curator_hold", default: false
    t.date "release_date"
    t.string "embargo"
    t.boolean "is_test", default: false
    t.boolean "is_import", default: false
    t.date "tombstone_date"
    t.string "have_permission", default: "no"
    t.string "removed_private", default: "no"
    t.string "agree", default: "no"
    t.string "hold_state", default: "none"
    t.string "medusa_dataset_dir"
    t.string "dataset_version", default: "1"
    t.boolean "suppress_changelog", default: false
    t.text "version_comment"
    t.string "subject"
    t.boolean "org_creators", default: false
    t.boolean "data_curation_network", default: false, null: false
    t.datetime "nested_updated_at"
    t.string "external_files_link"
    t.text "external_files_note"
    t.boolean "all_medusa"
    t.boolean "all_globus"
    t.index ["key"], name: "index_datasets_on_key", unique: true
  end

  create_table "day_file_downloads", id: :serial, force: :cascade do |t|
    t.string "ip_address"
    t.string "file_web_id"
    t.string "filename"
    t.string "dataset_key"
    t.string "doi"
    t.date "download_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "definitions", id: :serial, force: :cascade do |t|
    t.string "term"
    t.string "meaning"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "delayed_jobs", id: :serial, force: :cascade do |t|
    t.integer "priority", default: 0, null: false
    t.integer "attempts", default: 0, null: false
    t.text "handler", null: false
    t.text "last_error"
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string "locked_by"
    t.string "queue"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "progress_stage"
    t.integer "progress_current", default: 0
    t.integer "progress_max", default: 0
    t.index ["priority", "run_at"], name: "delayed_jobs_priority"
  end

  create_table "extractor_errors", force: :cascade do |t|
    t.integer "extractor_response_id"
    t.string "error_type"
    t.string "report"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "extractor_responses", force: :cascade do |t|
    t.integer "extractor_task_id"
    t.string "web_id"
    t.string "status"
    t.string "peek_type"
    t.string "peek_text"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "extractor_tasks", force: :cascade do |t|
    t.string "web_id"
    t.datetime "response_at"
    t.string "raw_response"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "sent_at"
  end

  create_table "featured_researchers", id: :serial, force: :cascade do |t|
    t.string "name"
    t.string "question"
    t.text "bio"
    t.text "testimonial"
    t.string "binary"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "photo_url"
    t.string "dataset_url"
    t.string "article_url"
    t.boolean "is_active"
  end

  create_table "file_download_tallies", id: :serial, force: :cascade do |t|
    t.string "file_web_id"
    t.string "filename"
    t.string "dataset_key"
    t.string "doi"
    t.date "download_date"
    t.integer "tally"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["dataset_key"], name: "index_file_download_tallies_on_dataset_key"
    t.index ["file_web_id"], name: "index_file_download_tallies_on_file_web_id"
  end

  create_table "funders", id: :serial, force: :cascade do |t|
    t.string "name"
    t.string "identifier"
    t.string "identifier_scheme"
    t.string "grant"
    t.integer "dataset_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "code"
  end

  create_table "guide_items", force: :cascade do |t|
    t.integer "section_id"
    t.string "anchor"
    t.string "label"
    t.integer "ordinal"
    t.string "heading"
    t.string "body"
    t.boolean "public", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "guide_sections", force: :cascade do |t|
    t.string "anchor"
    t.string "label"
    t.integer "ordinal"
    t.boolean "public", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "heading"
    t.string "body"
  end

  create_table "guide_subitems", force: :cascade do |t|
    t.integer "item_id"
    t.string "anchor"
    t.string "label"
    t.integer "ordinal"
    t.string "heading"
    t.string "body"
    t.boolean "public", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "identities", id: :serial, force: :cascade do |t|
    t.string "name"
    t.string "email"
    t.string "password_digest"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "activation_digest"
    t.boolean "activated", default: false
    t.datetime "activated_at"
    t.string "reset_digest"
    t.integer "invitee_id"
    t.datetime "reset_sent_at"
  end

  create_table "ingest_responses", id: :serial, force: :cascade do |t|
    t.text "as_text"
    t.string "status"
    t.datetime "response_time"
    t.string "staging_key"
    t.string "medusa_key"
    t.string "uuid"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "invitees", id: :serial, force: :cascade do |t|
    t.string "email"
    t.string "role"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "expires_at"
  end

  create_table "medusa_ingests", id: :serial, force: :cascade do |t|
    t.string "idb_class"
    t.string "idb_identifier"
    t.string "staging_path"
    t.string "request_status"
    t.string "medusa_path"
    t.string "medusa_uuid"
    t.datetime "response_time"
    t.string "error_text"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "medusa_dataset_dir"
    t.string "staging_key"
    t.string "target_key"
  end

  create_table "nested_items", id: :serial, force: :cascade do |t|
    t.integer "datafile_id"
    t.integer "parent_id"
    t.string "item_name"
    t.string "media_type"
    t.bigint "size"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "item_path"
    t.boolean "is_directory"
  end

  create_table "notes", force: :cascade do |t|
    t.bigint "dataset_id"
    t.string "body"
    t.string "author"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "related_materials", id: :serial, force: :cascade do |t|
    t.string "material_type"
    t.string "availability"
    t.string "link"
    t.string "uri"
    t.string "uri_type"
    t.text "citation"
    t.integer "dataset_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "selected_type"
    t.string "datacite_list"
    t.text "note"
    t.boolean "feature"
  end

  create_table "restoration_events", id: :serial, force: :cascade do |t|
    t.text "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "restoration_id_maps", id: :serial, force: :cascade do |t|
    t.string "id_class"
    t.integer "old_id"
    t.integer "new_id"
    t.integer "restoration_event_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "review_requests", id: :serial, force: :cascade do |t|
    t.string "dataset_key"
    t.datetime "requested_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "modified", default: false
  end

  create_table "robots", id: :serial, force: :cascade do |t|
    t.string "source"
    t.string "address"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "sessions", force: :cascade do |t|
    t.string "session_id", null: false
    t.text "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["session_id"], name: "index_sessions_on_session_id", unique: true
    t.index ["updated_at"], name: "index_sessions_on_updated_at"
  end

  create_table "share_codes", force: :cascade do |t|
    t.string "code"
    t.integer "dataset_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "system_files", id: :serial, force: :cascade do |t|
    t.integer "dataset_id"
    t.string "storage_root"
    t.string "storage_key"
    t.string "file_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "tokens", id: :serial, force: :cascade do |t|
    t.string "dataset_key"
    t.string "identifier"
    t.datetime "expires"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "user_abilities", id: :serial, force: :cascade do |t|
    t.string "ability"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "user_provider"
    t.string "user_uid"
    t.string "resource_type"
    t.integer "resource_id"
  end

  create_table "users", id: :serial, force: :cascade do |t|
    t.string "provider"
    t.string "uid"
    t.string "name"
    t.string "email"
    t.string "role"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "username"
  end

  create_table "version_files", force: :cascade do |t|
    t.bigint "dataset_id", null: false
    t.integer "datafile_id"
    t.boolean "selected"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "initiated", default: false
    t.index ["datafile_id"], name: "index_version_files_on_datafile_id", unique: true
    t.index ["dataset_id"], name: "index_version_files_on_dataset_id"
  end

  add_foreign_key "dataset_download_tallies", "datasets", column: "dataset_key", primary_key: "key"
  add_foreign_key "version_files", "datasets"
end
