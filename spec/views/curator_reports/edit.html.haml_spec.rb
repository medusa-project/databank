require 'rails_helper'

RSpec.describe "curator_reports/edit", type: :view do
  let(:curator_report) {
    CuratorReport.create!(
      requestor_name: "MyString",
      requestor_email: "test@example.com",
      report_type: "MyString",
      storage_root: "MyString",
      storage_key: "MyString",
      notes: "MyString"
    )
  }

  before(:each) do
    assign(:curator_report, curator_report)
  end

  it "renders the edit curator_report form" do
    render

    assert_select "form[action=?][method=?]", curator_report_path(curator_report), "post" do

      assert_select "input[name=?]", "curator_report[requestor_name]"

      assert_select "input[name=?]", "curator_report[requestor_email]"

      assert_select "input[name=?]", "curator_report[report_type]"

      assert_select "input[name=?]", "curator_report[storage_root]"

      assert_select "input[name=?]", "curator_report[storage_key]"

      assert_select "input[name=?]", "curator_report[notes]"
    end
  end
end
