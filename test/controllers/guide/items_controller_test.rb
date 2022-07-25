require "test_helper"

class Guide::ItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @guide_item = guide_items(:one)
  end

  test "should get index" do
    get guide_items_url
    assert_response :success
  end

  test "should get new" do
    get new_guide_item_url
    assert_response :success
  end

  test "should create guide_item" do
    assert_difference('Guide::Item.count') do
      post guide_items_url, params: { guide_item: { anchor: @guide_item.anchor, body: @guide_item.body, heading: @guide_item.heading, label: @guide_item.label, ordinal: @guide_item.ordinal, section_id: @guide_item.section_id } }
    end

    assert_redirected_to guide_item_url(Guide::Item.last)
  end

  test "should show guide_item" do
    get guide_item_url(@guide_item)
    assert_response :success
  end

  test "should get edit" do
    get edit_guide_item_url(@guide_item)
    assert_response :success
  end

  test "should update guide_item" do
    patch guide_item_url(@guide_item), params: { guide_item: { anchor: @guide_item.anchor, body: @guide_item.body, heading: @guide_item.heading, label: @guide_item.label, ordinal: @guide_item.ordinal, section_id: @guide_item.section_id } }
    assert_redirected_to guide_item_url(@guide_item)
  end

  test "should destroy guide_item" do
    assert_difference('Guide::Item.count', -1) do
      delete guide_item_url(@guide_item)
    end

    assert_redirected_to guide_items_url
  end
end
