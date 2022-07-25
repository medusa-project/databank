require "application_system_test_case"

class Guide::SectionsTest < ApplicationSystemTestCase
  setup do
    @guide_section = guide_sections(:one)
  end

  test "visiting the index" do
    visit guide_sections_url
    assert_selector "h1", text: "Guide/Sections"
  end

  test "creating a Section" do
    visit guide_sections_url
    click_on "New Guide/Section"

    fill_in "Anchor", with: @guide_section.anchor
    fill_in "Label", with: @guide_section.label
    fill_in "Ordinal", with: @guide_section.ordinal
    click_on "Create Section"

    assert_text "Section was successfully created"
    click_on "Back"
  end

  test "updating a Section" do
    visit guide_sections_url
    click_on "Edit", match: :first

    fill_in "Anchor", with: @guide_section.anchor
    fill_in "Label", with: @guide_section.label
    fill_in "Ordinal", with: @guide_section.ordinal
    click_on "Update Section"

    assert_text "Section was successfully updated"
    click_on "Back"
  end

  test "destroying a Section" do
    visit guide_sections_url
    page.accept_confirm do
      click_on "Destroy", match: :first
    end

    assert_text "Section was successfully destroyed"
  end
end
