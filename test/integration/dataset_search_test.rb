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
    @search = Dataset.filtered_list(user_role: nil, user_netid: nil, params: {})
    actual_identifiers = @search.results.map(&:identifier)
    expected_identifiers = Dataset.select(&:metadata_public?).pluck(:identifier)
    assert expected_identifiers & actual_identifiers == expected_identifiers
  end

  test "default listing for depositor" do
    @user = user_identities :researcher1
    log_in_as(@user)
    get datasets_path
    assert_response :success
    public_keys = Dataset.select(&:metadata_public?).pluck(:key)
    public_set = Set.new(public_keys)

    # forbidden_hold_states = [Databank::PublicationState::TempSuppress::VERSION, Databank::PublicationState::PermSuppress::METADATA]
    # depositor_keys = Dataset.where(depositor_email: @user.email).where.not(hold_state: forbidden_hold_states).pluck(:key)
    # creator_datasets = Creator.where(email: @user.email).pluck(:dataset_id)
    # creator_keys = Dataset.where(id: creator_datasets).where.not(hold_state: forbidden_hold_states).pluck(:key)
    # expected_keys = (public_keys + depositor_keys + creator_keys).uniq
    @search = Dataset.filtered_list(user_role: Databank::UserRole::DEPOSITOR, user: @user, params: {})
    actual_keys = @search.results.map(&:key)
    actual_set = Set.new(actual_keys)
    # puts "expected_identifiers"
    # puts expected_identifiers
    # puts "actual_identifiers"
    # puts actual_identifiers
    assert_true public_set.subset?(actual_set)
  end

end
