require 'rails_helper'

RSpec.describe 'Dataset creator/contributor switch', type: :request do
  fixtures :users, :datasets, :creators

  let(:user) { users(:researcher1) }
  let(:dataset) { datasets(:draft1) }

  before do
    log_in user
  end

  it 'preserves creator mode when switch conversion fails' do
    expect_any_instance_of(Dataset).to receive(:ind_creators_to_contributors!).and_raise(StandardError, 'forced conversion error')

    patch dataset_path(dataset),
          params: {
            dataset: {
              title: dataset.title,
              license: dataset.license,
              org_creators: true
            }
          },
          headers: { 'ACCEPT' => 'text/html' }

    expect(response).not_to have_http_status(:internal_server_error)
    expect(dataset.reload.org_creators).to be(false)
  end

  it 'does not lose creator rows when switch conversion fails' do
    expect_any_instance_of(Dataset).to receive(:ind_creators_to_contributors!).and_raise(StandardError, 'forced conversion error')
    original_creator_ids = dataset.creators.pluck(:id)

    patch dataset_path(dataset),
          params: {
            dataset: {
              title: dataset.title,
              license: dataset.license,
              org_creators: 'true'
            }
          },
          as: :json

    expect(response).not_to have_http_status(:internal_server_error)
    expect(dataset.reload.org_creators).to be(false)
    expect(dataset.creators.pluck(:id)).to eq(original_creator_ids)
  end
end
