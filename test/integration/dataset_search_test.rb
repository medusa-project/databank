# frozen_string_literal: true

require "set"
require "test_helper"

class DatasetSearchTest < ActionDispatch::IntegrationTest

  setup do
    ensure_creator_editors
  end

  test "default listing for guest" do
    get datasets_path
    assert_response :success
    @search = Dataset.filtered_list(user_role: nil, user: nil, params: {})
    actual_identifiers = @search.results.map(&:identifier)
    expected_identifiers = Dataset.select(&:metadata_public?).pluck(:identifier)
    assert expected_identifiers & actual_identifiers == expected_identifiers
  end

  test "default listing for depositor" do
    Dataset.all.each(&:ensure_creator_editors)
    @user = user_identities :researcher1
    log_in_as(@user)
    get datasets_path
    assert_response :success
    @search = Dataset.filtered_list(user_role: Databank::UserRole::DEPOSITOR, user: @user, params: {})
    expected_keys = @user.datasets_user_can_view(user: @user).map(&:key)
    actual_keys = @search.results.map(&:key)
    # puts "expected_keys: #{expected_keys.to_yaml}"
    # puts "actual_keys: #{actual_keys.to_yaml}"
    assert expected_keys & actual_keys == expected_keys
  end

end
