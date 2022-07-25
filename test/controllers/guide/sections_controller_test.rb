require "test_helper"

class Guide::SectionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @guide_section = guide_sections(:one)
  end

  test "should get index" do
    get guide_sections_url
    assert_response :success
  end

  test "should get new" do
    get new_guide_section_url
    assert_response :success
  end

  test "should create guide_section" do
    assert_difference('Guide::Section.count') do
      post guide_sections_url, params: { guide_section: { anchor: @guide_section.anchor, label: @guide_section.label, ordinal: @guide_section.ordinal } }
    end

    assert_redirected_to guide_section_url(Guide::Section.last)
  end

  test "should show guide_section" do
    get guide_section_url(@guide_section)
    assert_response :success
  end

  test "should get edit" do
    get edit_guide_section_url(@guide_section)
    assert_response :success
  end

  test "should update guide_section" do
    patch guide_section_url(@guide_section), params: { guide_section: { anchor: @guide_section.anchor, label: @guide_section.label, ordinal: @guide_section.ordinal } }
    assert_redirected_to guide_section_url(@guide_section)
  end

  test "should destroy guide_section" do
    assert_difference('Guide::Section.count', -1) do
      delete guide_section_url(@guide_section)
    end

    assert_redirected_to guide_sections_url
  end
end
