require "application_system_test_case"

class ExtractorTasksTest < ApplicationSystemTestCase
  setup do
    @extractor_task = extractor_tasks(:one)
  end

  test "visiting the index" do
    visit extractor_tasks_url
    assert_selector "h1", text: "Extractor Tasks"
  end

  test "creating a Extractor task" do
    visit extractor_tasks_url
    click_on "New Extractor Task"

    fill_in "Response", with: @extractor_task.response
    fill_in "Response at", with: @extractor_task.response_at
    fill_in "Web", with: @extractor_task.web_id
    click_on "Create Extractor task"

    assert_text "Extractor task was successfully created"
    click_on "Back"
  end

  test "updating a Extractor task" do
    visit extractor_tasks_url
    click_on "Edit", match: :first

    fill_in "Response", with: @extractor_task.response
    fill_in "Response at", with: @extractor_task.response_at
    fill_in "Web", with: @extractor_task.web_id
    click_on "Update Extractor task"

    assert_text "Extractor task was successfully updated"
    click_on "Back"
  end

  test "destroying a Extractor task" do
    visit extractor_tasks_url
    page.accept_confirm do
      click_on "Destroy", match: :first
    end

    assert_text "Extractor task was successfully destroyed"
  end
end
