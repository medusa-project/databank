require "application_system_test_case"

class Guide::SubitemsTest < ApplicationSystemTestCase
  setup do
    @guide_subitem = guide_subitems(:one)
  end

  test "visiting the index" do
    visit guide_subitems_url
    assert_selector "h1", text: "Guide/Subitems"
  end

  test "creating a Subitem" do
    visit guide_subitems_url
    click_on "New Guide/Subitem"

    fill_in "Anchor", with: @guide_subitem.anchor
    fill_in "Body", with: @guide_subitem.body
    fill_in "Heading", with: @guide_subitem.heading
    fill_in "Item", with: @guide_subitem.item_id
    fill_in "Label", with: @guide_subitem.label
    fill_in "Ordinal", with: @guide_subitem.ordinal
    click_on "Create Subitem"

    assert_text "Subitem was successfully created"
    click_on "Back"
  end

  test "updating a Subitem" do
    visit guide_subitems_url
    click_on "Edit", match: :first

    fill_in "Anchor", with: @guide_subitem.anchor
    fill_in "Body", with: @guide_subitem.body
    fill_in "Heading", with: @guide_subitem.heading
    fill_in "Item", with: @guide_subitem.item_id
    fill_in "Label", with: @guide_subitem.label
    fill_in "Ordinal", with: @guide_subitem.ordinal
    click_on "Update Subitem"

    assert_text "Subitem was successfully updated"
    click_on "Back"
  end

  test "destroying a Subitem" do
    visit guide_subitems_url
    page.accept_confirm do
      click_on "Destroy", match: :first
    end

    assert_text "Subitem was successfully destroyed"
  end
end
