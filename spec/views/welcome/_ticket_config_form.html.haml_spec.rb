require 'rails_helper'

RSpec.describe 'welcome/_ticket_config_form', type: :view do
  it 'renders the configured assignees with only the current assignee selected' do
    assignees = [
      { netid: 'curator1', name: 'Curator One', email: 'curator1@example.org' },
      { netid: 'curator2', name: 'Curator Two', email: 'curator2@example.org' }
    ]
    allow(TdxClient).to receive(:assignees).and_return(assignees)
    allow(TdxClient).to receive(:current_assignee).and_return(assignees.last)

    render partial: 'welcome/ticket_config_form'

    page = Nokogiri::HTML(rendered)
    options = page.css('#ticket_config_current_assignee_netid option')
    expect(options.map { |option| option['value'] }).to eq(%w[curator1 curator2])
    expect(options.select { |option| option.key?('selected') }.map { |option| option['value'] }).to eq(['curator2'])
    expect(options.last.text.strip).to eq('Curator Two (curator2)')
    group = page.at_css('#ticket_config_current_assignee_netid').parent
    expect(group['class']).to eq('input-group')
    expect(group.at_css('.input-group-btn button[type="submit"]').text.strip).to eq('Update')
  end
end
