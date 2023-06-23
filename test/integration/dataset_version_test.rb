# frozen_string_literal: true

require "test_helper"

##
# Tests that the dataset deposit process produces a correct dataset.
#
class DatasetVersionTest < ActionDispatch::IntegrationTest

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
    @dataset = Dataset.new
  end
end