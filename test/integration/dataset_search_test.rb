# frozen_string_literal: true

require "test_helper"

class DatasetSearchTest < ActionDispatch::IntegrationTest

  test "default listing for guest" do
    get datasets_path
    assert_response :success
  end

  test "default listing for depositor" do
    @user = user_identities :researcher1
    log_in_as(@user)
    get datasets_path
    assert_response :success
  end
end
