require 'rails_helper'

RSpec.describe "curator_reports/show", type: :view do
  before(:each) do
    assign(:curator_report, CuratorReport.create!(
      requestor_name: "Requestor Name",
      requestor_email: "test@example.com",
      report_type: "Report Type",
      storage_root: "Storage Root",
      storage_key: "Storage Key",
      notes: "Notes"
    ))
  end

  it "renders attributes in <p>" do
    render
    expect(rendered).to match(/Requestor Name/)
    expect(rendered).to match(/test@example.com/)
    expect(rendered).to match(/Report Type/)
    expect(rendered).to match(/Storage Root/)
    expect(rendered).to match(/Storage Key/)
    expect(rendered).to match(/Notes/)
  end
end
