# frozen_string_literal: true

require "test_helper"

##
# Tests that the Creator class can fetch an orcid identifier record and orcid person record.
#
class OrcidApiTest < ActionDispatch::IntegrationTest

  setup do
    @user = user_identities :researcher1
    log_in_as(@user)
  end

  test "fetch orcid identifier" do
    create_creator
    expected_identifier_result = {"num-found" => 1, "result" => [{"orcid-identifier"=>"0000-0002-0339-9809"}]}
    identifier_search_result = Creator.orcid_identifier(family_name: @creator.family_name,
                                                        given_names: @creator.given_name)
    assert_equal(identifier_search_result, expected_identifier_result)
  end

  test "fetch orcid person" do
    expected_person_record = {family_name: "Fallaw",
                              given_names: "Colleen",
                              affiliation: "University of Illinois at Urbana-Champaign"}
    person_search_result = Creator.orcid_person(orcid: "0000-0002-0339-9809")
    assert_equal(expected_person_record, person_search_result)
  end

  private

  def create_creator
    @creator = Creator.new(family_name: "Fallaw", given_name: "Colleen")
  end
end
