require "application_system_test_case"

class DatasetsTest < ApplicationSystemTestCase
  test "visiting the index" do
    visit datasets_url

    assert_selector "h1", text: "Users"
  end
end