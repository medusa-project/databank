require 'rails_helper'

RSpec.describe "DatasetDeposit", type: :request do
  fixtures :users, :datasets, :datafiles, :creators, :related_materials
  describe "POST /datasets" do
    let(:user) { users(:researcher1) }
    let(:dataset) { datasets(:draft1) }
    let(:protected_route_path) { dataset_path(dataset) }

    before do
      log_in user
    end

    it "creates a new dataset" do
      expect {
        post datasets_path, params: { dataset: { publisher: "University of Illinois Urbana-Champaign",
                                                 resource_type: "Dataset",
                                                 license: "CC01",
                                                 depositor_name: "researcher1",
                                                 depositor_email: "researcher1@mailinator.com",
                                                 corresponding_creator_name: "researcher1",
                                                 corresponding_creator_email: "researcher1@mailinator.com",
                                                 publication_state: "draft",
                                                 curator_hold: false,
                                                 embargo: "none",
                                                 is_test: false,
                                                 is_import: false,
                                                 have_permission: "yes",
                                                 removed_private: "na",
                                                 agree: "yes",
                                                 hold_state: "none",
                                                 medusa_dataset_dir: "",
                                                 dataset_version: "1",
                                                 suppress_changelog: false,
                                                 version_comment: "",
                                                 subject: "",
                                                 org_creators: false,
                                                 data_curation_network: false } }
      }.to change(Dataset, :count).by(1)

      @dataset = Dataset.order(created_at: :desc).limit(1).first
      expect(response).to redirect_to(edit_dataset_path(@dataset))

      # Check the dataset
      # has an id
      expect(@dataset.id).not_to be_nil
      # has a key
      expect(@dataset.key).not_to be_nil
    end
  end
end