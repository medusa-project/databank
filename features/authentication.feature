Feature: Authentication
  In order to control access to Illinois Data Bank
  As anyone
  I want to provide an authentication mechanism

  Scenario: Log out
    Given I am logged in as an "admin"
    When I go to the site home
    And I click on "Log out" in the global navigation bar
    And I should be on the site home page

  Scenario: Depositor can deposit
    Given I am logged in as an "depositor"
    When I go to the site home
    And I click on "Deposit Dataset" in the global navigation bar
    And I am on the pre-deposit considerations page
    And I continue
    Then I should be on the new datasets page


