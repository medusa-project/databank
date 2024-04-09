# frozen_string_literal: true

require "test_helper"

##
# Tests that the dataset deposit process produces a correct dataset.
#
class DatasetDepositTest < ActionDispatch::IntegrationTest

  setup do
    @user = user_identities :researcher1
    log_in_as(@user)
  end

  test "hello dataset deposit" do
    create_dataset
    assert_nil @dataset.title
  end

  private

  def create_dataset
    assert_difference "Dataset.count" do
      post datasets_path, params: { dataset: { publisher: "University of Illinois at Urbana-Champaign",
                                               resource_type: "Dataset",
                                               license: "CC01",
                                               depositor_name: "researcher1",
                                               depositor_email: "researcher1@mailinator.com",
                                               corresponding_creator_name: "researcher1",
                                               corresponding_creator_email: "researcher1@mailinator.com",
                                               publication_state: "draft",
                                               curator_hold: false,
                                               embargo: "none",
                                               is_test: false,
                                               is_import: false,
                                               have_permission: "yes",
                                               removed_private: "na",
                                               agree: "yes",
                                               hold_state: "none",
                                               medusa_dataset_dir: "",
                                               dataset_version: "1",
                                               suppress_changelog: false,
                                               version_comment: "",
                                               subject: "",
                                               org_creators: false,
                                               data_curation_network: false } }
    end
    @dataset = Dataset.order(created_at: :desc).limit(1).first
    assert_redirected_to edit_dataset_path(@dataset)

    # Check the dataset
    # has an id
    assert_not_nil @dataset.id
    # has a key
    assert_not_nil @dataset.key

  end
end
