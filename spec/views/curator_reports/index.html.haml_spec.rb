require 'rails_helper'

RSpec.describe "curator_reports/index", type: :view do
  before(:each) do
    assign(:curator_reports, [
      CuratorReport.create!(
        requestor_name: "Requestor Name",
        requestor_email: "Requestor Email",
        report_type: "Report Type",
        storage_root: "Storage Root",
        storage_key: "Storage Key",
        notes: "Notes"
      ),
      CuratorReport.create!(
        requestor_name: "Requestor Name",
        requestor_email: "Requestor Email",
        report_type: "Report Type",
        storage_root: "Storage Root",
        storage_key: "Storage Key",
        notes: "Notes"
      )
    ])
  end

  it "renders a list of curator_reports" do
    render
    cell_selector = 'div>p'
    assert_select cell_selector, text: Regexp.new("Requestor Name".to_s), count: 2
    assert_select cell_selector, text: Regexp.new("Requestor Email".to_s), count: 2
    assert_select cell_selector, text: Regexp.new("Report Type".to_s), count: 2
    assert_select cell_selector, text: Regexp.new("Storage Root".to_s), count: 2
    assert_select cell_selector, text: Regexp.new("Storage Key".to_s), count: 2
    assert_select cell_selector, text: Regexp.new("Notes".to_s), count: 2
  end
end
