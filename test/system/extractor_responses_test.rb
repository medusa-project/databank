require "application_system_test_case"

class ExtractorResponsesTest < ApplicationSystemTestCase
  setup do
    @extractor_response = extractor_responses(:one)
  end

  test "visiting the index" do
    visit extractor_responses_url
    assert_selector "h1", text: "Extractor Responses"
  end

  test "creating a Extractor response" do
    visit extractor_responses_url
    click_on "New Extractor Response"

    fill_in "Extractor task", with: @extractor_response.extractor_task_id
    fill_in "Peek text", with: @extractor_response.peek_text
    fill_in "Peek type", with: @extractor_response.peek_type
    fill_in "Status", with: @extractor_response.status
    fill_in "Web", with: @extractor_response.web_id
    click_on "Create Extractor response"

    assert_text "Extractor response was successfully created"
    click_on "Back"
  end

  test "updating a Extractor response" do
    visit extractor_responses_url
    click_on "Edit", match: :first

    fill_in "Extractor task", with: @extractor_response.extractor_task_id
    fill_in "Peek text", with: @extractor_response.peek_text
    fill_in "Peek type", with: @extractor_response.peek_type
    fill_in "Status", with: @extractor_response.status
    fill_in "Web", with: @extractor_response.web_id
    click_on "Update Extractor response"

    assert_text "Extractor response was successfully updated"
    click_on "Back"
  end

  test "destroying a Extractor response" do
    visit extractor_responses_url
    page.accept_confirm do
      click_on "Destroy", match: :first
    end

    assert_text "Extractor response was successfully destroyed"
  end
end
