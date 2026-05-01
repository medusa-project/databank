require 'rails_helper'

RSpec.describe Dataset::Filterable, type: :model do
  before do
    stub_const('Placeholder_FacetRow', Struct.new(:value, :count))
  end

  describe '.filtered_list' do
    let(:list) { double('search_list') }
    let(:facets) { double('search_facets') }
    let(:user) { instance_double(User, email: 'depositor@example.org') }

    before do
      allow(Dataset).to receive(:list_with_facet) do |list:, search_get_facets:, facet:|
        list
      end
    end

    it 'uses admin list/facets and applies all expected facet merges' do
      params = { per_page: '50' }
      allow(Dataset).to receive(:admin_list).with(params: params, per_page: 50).and_return(list)
      allow(Dataset).to receive(:admin_facets).with(params: params).and_return(facets)

      result = Dataset.filtered_list(user_role: Databank::UserRole::ADMIN, user: user, params: params)

      expect(result).to eq(list)
      expect(Dataset).to have_received(:list_with_facet).with(list: list, search_get_facets: facets, facet: :visibility_code)
      expect(Dataset).to have_received(:list_with_facet).with(list: list, search_get_facets: facets, facet: :depositor)
      expect(Dataset).to have_received(:list_with_facet).with(list: list, search_get_facets: facets, facet: :subject_text)
      expect(Dataset).to have_received(:list_with_facet).with(list: list, search_get_facets: facets, facet: :publication_year)
      expect(Dataset).to have_received(:list_with_facet).with(list: list, search_get_facets: facets, facet: :license_code)
      expect(Dataset).to have_received(:list_with_facet).with(list: list, search_get_facets: facets, facet: :funder_codes)
    end

    it 'uses default per_page=25 when invalid per_page is passed' do
      params = { per_page: '1000' }
      allow(Dataset).to receive(:public_list).and_return(list)
      allow(Dataset).to receive(:public_facets).and_return(facets)

      Dataset.filtered_list(user_role: Databank::UserRole::GUEST, params: params)

      expect(Dataset).to have_received(:public_list).with(params: params, per_page: 25)
    end

    it 'raises for depositor role when user is missing' do
      expect {
        Dataset.filtered_list(user_role: Databank::UserRole::DEPOSITOR, user: nil, params: {})
      }.to raise_error(ArgumentError, 'net_id required for depositor role')
    end

    it 'uses depositor list/facets and merges depositor-visible facets' do
      params = { per_page: '10' }
      allow(Dataset).to receive(:depositor_list).with(user: user, params: params, per_page: 10).and_return(list)
      allow(Dataset).to receive(:depositor_facets).with(user: user, params: params).and_return(facets)

      result = Dataset.filtered_list(user_role: Databank::UserRole::DEPOSITOR, user: user, params: params)

      expect(result).to eq(list)
      expect(Dataset).to have_received(:list_with_facet).with(list: list, search_get_facets: facets, facet: :visibility_code)
      expect(Dataset).to have_received(:list_with_facet).with(list: list, search_get_facets: facets, facet: :subject_text)
      expect(Dataset).to have_received(:list_with_facet).with(list: list, search_get_facets: facets, facet: :publication_year)
      expect(Dataset).to have_received(:list_with_facet).with(list: list, search_get_facets: facets, facet: :license_code)
      expect(Dataset).to have_received(:list_with_facet).with(list: list, search_get_facets: facets, facet: :funder_codes)
    end

    it 'uses public list/facets for guest role and merges common facets' do
      params = {}
      allow(Dataset).to receive(:public_list).with(params: params, per_page: 25).and_return(list)
      allow(Dataset).to receive(:public_facets).with(params: params).and_return(facets)

      result = Dataset.filtered_list(user_role: Databank::UserRole::GUEST, params: params)

      expect(result).to eq(list)
      expect(Dataset).to have_received(:list_with_facet).with(list: list, search_get_facets: facets, facet: :subject_text)
      expect(Dataset).to have_received(:list_with_facet).with(list: list, search_get_facets: facets, facet: :publication_year)
      expect(Dataset).to have_received(:list_with_facet).with(list: list, search_get_facets: facets, facet: :license_code)
      expect(Dataset).to have_received(:list_with_facet).with(list: list, search_get_facets: facets, facet: :funder_codes)
    end
  end

  describe '.list_with_facet' do
    Row = Struct.new(:value, :count)
    Facet = Struct.new(:rows)

    it 'appends missing facet rows with zero count' do
      list = double('list')
      search_get_facets = double('search_get_facets')
      list_facet = Facet.new([Row.new('license-a', 5)])
      search_facet = Facet.new([Row.new('license-a', 11), Row.new('license-b', 2)])

      allow(list).to receive(:facet).with(:license_code).and_return(list_facet)
      allow(search_get_facets).to receive(:facet).with(:license_code).and_return(search_facet)

      result = Dataset.list_with_facet(list: list, search_get_facets: search_get_facets, facet: :license_code)

      expect(result).to eq(list)
      values = list_facet.rows.map(&:value)
      counts = list_facet.rows.each_with_object({}) { |row, hash| hash[row.value] = row.count }
      expect(values).to include('license-a', 'license-b')
      expect(counts['license-b']).to eq(0)
    end

    it 'does not duplicate rows that already exist' do
      list = double('list')
      search_get_facets = double('search_get_facets')
      list_facet = Facet.new([Row.new('subject-a', 3)])
      search_facet = Facet.new([Row.new('subject-a', 8)])

      allow(list).to receive(:facet).with(:subject_text).and_return(list_facet)
      allow(search_get_facets).to receive(:facet).with(:subject_text).and_return(search_facet)

      Dataset.list_with_facet(list: list, search_get_facets: search_get_facets, facet: :subject_text)

      expect(list_facet.rows.count { |row| row.value == 'subject-a' }).to eq(1)
    end
  end
end
