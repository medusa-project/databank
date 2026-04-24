require 'rails_helper'

RSpec.feature "User Login", type: :feature do
  after do
    OmniAuth.config.mock_auth[:developer] = nil
  end

  scenario "User logs in with valid credentials" do
    OmniAuth.config.mock_auth[:developer] = OmniAuth::AuthHash.new(
      provider: 'developer',
      uid: 'researcher1@mailinator.com',
      info: {
        email: 'researcher1@mailinator.com',
        name: 'Researcher1',
        role: 'depositor'
      }
    )

    # 1. Visit the login page
    visit login_path

    # 2. Interact with the form
    expect(page).to have_field('email')
    expect(page).to have_field('name')
    expect(page).to have_select('role', options: ['Please select', 'Depositor', 'Curator', 'Guest', 'No Deposit'])
    fill_in 'email', with: 'researcher1@mailinator.com'
    fill_in 'name', with: 'Researcher1'
    select 'Depositor', from: 'role'
    click_button 'Sign in'

    # 3. Assert the expected outcome
    expect(page).to have_content 'Log out'
    expect(current_path).to eq root_path
  end

  scenario "User cannot log in with an incorrect email" do
    OmniAuth.config.mock_auth[:developer] = :invalid_credentials

    visit '/login'

    fill_in 'email', with: 'unknown_user@mailinator.com'
    fill_in 'name', with: 'Researcher1'
    select 'Depositor', from: 'role'
    click_button 'Sign in'

    expect(page).to have_no_content 'Log out'
  end

  scenario "User cannot log in with missing required fields" do
    OmniAuth.config.mock_auth[:developer] = :invalid_credentials

    visit '/login'

    fill_in 'email', with: ''
    fill_in 'name', with: ''
    click_button 'Sign in'

    expect(page).to have_no_content 'Log out'
  end

  scenario "User cannot log in with SQL injection input" do
    OmniAuth.config.mock_auth[:developer] = :invalid_credentials

    visit '/login'

    fill_in 'email', with: "' OR '1'='1"
    fill_in 'name', with: 'Researcher1'
    select 'Depositor', from: 'role'
    click_button 'Sign in'

    expect(page).to have_no_content 'Log out'
  end

  scenario "User cannot log in with XSS input" do
    OmniAuth.config.mock_auth[:developer] = :invalid_credentials

    visit '/login'

    fill_in 'email', with: '<script>alert("xss")</script>'
    fill_in 'name', with: '<img src=x onerror=alert(1)>'
    select 'Depositor', from: 'role'
    click_button 'Sign in'

    expect(page).to have_no_content 'Log out'
  end
end
