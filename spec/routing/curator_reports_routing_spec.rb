require "rails_helper"

RSpec.describe CuratorReportsController, type: :routing do
  describe "routing" do
    it "routes to #index" do
      expect(get: "/curator_reports").to route_to("curator_reports#index")
    end

    it "routes to #new" do
      expect(get: "/curator_reports/new").to route_to("curator_reports#new")
    end

    it "routes to #show" do
      expect(get: "/curator_reports/1").to route_to("curator_reports#show", id: "1")
    end

    it "routes to #edit" do
      expect(get: "/curator_reports/1/edit").to route_to("curator_reports#edit", id: "1")
    end


    it "routes to #create" do
      expect(post: "/curator_reports").to route_to("curator_reports#create")
    end

    it "routes to #update via PUT" do
      expect(put: "/curator_reports/1").to route_to("curator_reports#update", id: "1")
    end

    it "routes to #update via PATCH" do
      expect(patch: "/curator_reports/1").to route_to("curator_reports#update", id: "1")
    end

    it "routes to #destroy" do
      expect(delete: "/curator_reports/1").to route_to("curator_reports#destroy", id: "1")
    end
  end
end
