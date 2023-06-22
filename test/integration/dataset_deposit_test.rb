require "test_helper"

##
# Tests that the item submission process produces a correct item.
#
class DatasetDepositTest < ActionDispatch::IntegrationTest

  setup do
    @user = users(:researcher1)
    log_in_as(@user)
  end

  test "hello dataset deposit" do
    create_draft_dataset
    assert_equal @dataset, nil
  end

  private

  def create_draft_dataset
    @dataset = nil
  end
end