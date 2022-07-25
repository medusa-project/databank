require "test_helper"

class Guide::SubitemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @guide_subitem = guide_subitems(:one)
  end

  test "should get index" do
    get guide_subitems_url
    assert_response :success
  end

  test "should get new" do
    get new_guide_subitem_url
    assert_response :success
  end

  test "should create guide_subitem" do
    assert_difference('Guide::Subitem.count') do
      post guide_subitems_url, params: { guide_subitem: { anchor: @guide_subitem.anchor, body: @guide_subitem.body, heading: @guide_subitem.heading, item_id: @guide_subitem.item_id, label: @guide_subitem.label, ordinal: @guide_subitem.ordinal } }
    end

    assert_redirected_to guide_subitem_url(Guide::Subitem.last)
  end

  test "should show guide_subitem" do
    get guide_subitem_url(@guide_subitem)
    assert_response :success
  end

  test "should get edit" do
    get edit_guide_subitem_url(@guide_subitem)
    assert_response :success
  end

  test "should update guide_subitem" do
    patch guide_subitem_url(@guide_subitem), params: { guide_subitem: { anchor: @guide_subitem.anchor, body: @guide_subitem.body, heading: @guide_subitem.heading, item_id: @guide_subitem.item_id, label: @guide_subitem.label, ordinal: @guide_subitem.ordinal } }
    assert_redirected_to guide_subitem_url(@guide_subitem)
  end

  test "should destroy guide_subitem" do
    assert_difference('Guide::Subitem.count', -1) do
      delete guide_subitem_url(@guide_subitem)
    end

    assert_redirected_to guide_subitems_url
  end
end
