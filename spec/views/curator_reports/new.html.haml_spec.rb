require 'rails_helper'

RSpec.describe "curator_reports/new", type: :view do
  before(:each) do
    assign(:curator_report, CuratorReport.new(
      requestor_name: "MyString",
      requestor_email: "MyString",
      report_type: "MyString",
      storage_root: "MyString",
      storage_key: "MyString",
      notes: "MyString"
    ))
  end

  it "renders new curator_report form" do
    render

    assert_select "form[action=?][method=?]", curator_reports_path, "post" do

      assert_select "input[name=?]", "curator_report[requestor_name]"

      assert_select "input[name=?]", "curator_report[requestor_email]"

      assert_select "input[name=?]", "curator_report[report_type]"

      assert_select "input[name=?]", "curator_report[storage_root]"

      assert_select "input[name=?]", "curator_report[storage_key]"

      assert_select "input[name=?]", "curator_report[notes]"
    end
  end
end
