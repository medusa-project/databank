require 'rails_helper'

RSpec.describe "OrcidApi", type: :request do
  fixtures :users, :creators
  let(:user) { users(:researcher1) }

  before do
    log_in user
  end

  describe "fetch orcid identifier" do
    let(:creator) { creators(:creator10) }

    it "fetches the orcid identifier" do
      expected_identifier_result = { "num-found" => 1, "result" => [{ "orcid-identifier" => "0000-0002-0339-9809" }] }
      identifier_search_result = Creator.orcid_identifier(family_name: creator.family_name, given_names: creator.given_name)
      expect(identifier_search_result).to eq(expected_identifier_result)
    end
  end

  describe "fetch orcid person" do
    it "fetches the orcid person" do
      expected_person_record = {
        family_name: "Fallaw",
        given_names: "Colleen",
        affiliation: "University of Illinois at Urbana-Champaign"
      }
      person_search_result = Creator.orcid_person(orcid: "0000-0002-0339-9809")
      expect(person_search_result).to eq(expected_person_record)
    end
  end

end