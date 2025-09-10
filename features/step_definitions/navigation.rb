When("I go to the site home") do
  visit '/'
end

When("I click on {string} in the global navigation bar") do |name|
  within('#global-navigation') {click_link name}
end

When("I should be on the site home page") do
  current_path.should == root_path
end

And("I am on the pre-deposit considerations page") do
  current_path.should == "/datasets/pre_deposit"
end

Then("I should be on the new datasets page") do
  current_path.should == "/datasets/new"
end

And("I go to the search page") do
  visit '/datasets'
end

Then("I should see a search box") do
  page.should have_selector(".q")
end

And("I should not see {string}") do |string|
  page.should have_no_content(string)
end

Then("I should see {string}") do |string|
  page.should have_content(string)
end

When("I continue") do
  click_on "Continue"
end