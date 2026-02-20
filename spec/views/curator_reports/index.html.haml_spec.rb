require 'rails_helper'

RSpec.describe "curator_reports/index", type: :view do
  before(:each) do
    assign(:curator_reports, [
      CuratorReport.create!(
        requestor_name: "Requestor Name",
        requestor_email: "test@example.com",
        report_type: "Report Type",
        storage_root: "Storage Root",
        storage_key: "Storage Key",
        notes: "Notes"
      ),
      CuratorReport.create!(
        requestor_name: "Requestor Name",
        requestor_email: "test@example.com",
        report_type: "Report Type",
        storage_root: "Storage Root",
        storage_key: "Storage Key",
        notes: "Notes"
      )
    ])
  end

  it "renders a list of curator_reports" do
    render
    # The partial uses .col-md-3 and .col-md-12 for fields, so match those
    assert_select ".col-md-3", text: /Requestor name:/, count: 2
    assert_select ".col-md-3", text: /Requestor email:/, count: 2
    assert_select ".col-md-3", text: /Report type:/, count: 2
    assert_select ".col-md-3", text: /Storage root\/key:/, count: 2
    assert_select ".col-md-12", text: /Notes:/, count: 2
  end
end
