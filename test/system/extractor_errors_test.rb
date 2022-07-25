require "application_system_test_case"

class ExtractorErrorsTest < ApplicationSystemTestCase
  setup do
    @extractor_error = extractor_errors(:one)
  end

  test "visiting the index" do
    visit extractor_errors_url
    assert_selector "h1", text: "Extractor Errors"
  end

  test "creating a Extractor error" do
    visit extractor_errors_url
    click_on "New Extractor Error"

    fill_in "Error type", with: @extractor_error.error_type
    fill_in "Extractor response", with: @extractor_error.extractor_response_id
    fill_in "Report", with: @extractor_error.report
    click_on "Create Extractor error"

    assert_text "Extractor error was successfully created"
    click_on "Back"
  end

  test "updating a Extractor error" do
    visit extractor_errors_url
    click_on "Edit", match: :first

    fill_in "Error type", with: @extractor_error.error_type
    fill_in "Extractor response", with: @extractor_error.extractor_response_id
    fill_in "Report", with: @extractor_error.report
    click_on "Update Extractor error"

    assert_text "Extractor error was successfully updated"
    click_on "Back"
  end

  test "destroying a Extractor error" do
    visit extractor_errors_url
    page.accept_confirm do
      click_on "Destroy", match: :first
    end

    assert_text "Extractor error was successfully destroyed"
  end
end
