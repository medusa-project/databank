require 'rails_helper'

RSpec.describe Dataset::Filterable, type: :model do
  class FakeSearchDsl
    attr_reader :calls

    def initialize
      @calls = []
    end

    def all_of(&block)
      @calls << [:all_of, []]
      instance_eval(&block) if block
      self
    end

    def any_of(&block)
      @calls << [:any_of, []]
      instance_eval(&block) if block
      self
    end

    def with(*args, &block)
      @calls << [:with, args]
      instance_eval(&block) if block
      self
    end

    def without(*args, &block)
      @calls << [:without, args]
      instance_eval(&block) if block
      self
    end

    def keywords(*args)
      @calls << [:keywords, args]
      self
    end

    def order_by(*args)
      @calls << [:order_by, args]
      self
    end

    def facet(*args)
      @calls << [:facet, args]
      self
    end

    def paginate(*args)
      @calls << [:paginate, args]
      self
    end

    def method_missing(name, *args, &block)
      @calls << [name, args]
      instance_eval(&block) if block
      self
    end

    def respond_to_missing?(_name, _include_private = false)
      true
    end
  end

  def search_with_fake_dsl
    fake = FakeSearchDsl.new
    allow(Dataset).to receive(:search) do |&block|
      fake.instance_eval(&block)
      fake
    end
    fake
  end

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

    it 'uses default per_page=25 when per_page is zero' do
      params = { per_page: '0' }
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

  describe '.admin_list' do
    it 'uses identifier filter when q contains slash and defaults sort to updated_at desc' do
      fake = search_with_fake_dsl

      Dataset.admin_list(params: { q: '10.13012/B2IDB-ABC' }, per_page: 25)

      expect(fake.calls).to include([:with, [:identifier, '10.13012/B2IDB-ABC']])
      expect(fake.calls).to include([:order_by, [:updated_at, :desc]])
      expect(fake.calls.none? { |name, _args| name == :keywords }).to be true
    end

    it 'uses keywords when q has no slash and respects sort_released_asc' do
      fake = search_with_fake_dsl

      Dataset.admin_list(params: { q: 'climate', 'sort_by' => 'sort_released_asc' }, per_page: 25)

      expect(fake.calls).to include([:keywords, ['climate']])
      expect(fake.calls).to include([:order_by, [:release_datetime, :asc]])
    end

    it 'falls back to updated_at desc for unknown sort values' do
      fake = search_with_fake_dsl

      Dataset.admin_list(params: { q: 'climate', 'sort_by' => 'not-a-sort' }, per_page: 25)

      expect(fake.calls).to include([:order_by, [:updated_at, :desc]])
    end
  end

  describe '.depositor_list' do
    let(:user) { instance_double(User, email: 'depositor@example.org') }

    it 'adds editor filters and applies sort_ingested_asc when requested' do
      fake = search_with_fake_dsl

      Dataset.depositor_list(
        user: user,
        params: { 'editor' => 'editor@example.org', 'sort_by' => 'sort_ingested_asc', q: 'term' },
        per_page: 25
      )

      expect(fake.calls).to include([:with, [:editor_emails, 'editor@example.org']])
      expect(fake.calls).to include([:with, [:depositor_netid, 'editor@example.org']])
      expect(fake.calls).to include([:keywords, ['term']])
      expect(fake.calls).to include([:order_by, [:ingest_datetime, :asc]])
    end

    it 'uses identifier filter when query contains slash and sort_released_desc' do
      fake = search_with_fake_dsl

      Dataset.depositor_list(
        user: user,
        params: { q: '10.13012/B2IDB-DEPOSITOR', 'sort_by' => 'sort_released_desc' },
        per_page: 25
      )

      expect(fake.calls).to include([:with, [:identifier, '10.13012/B2IDB-DEPOSITOR']])
      expect(fake.calls).to include([:order_by, [:release_datetime, :desc]])
      expect(fake.calls.none? { |name, _args| name == :keywords }).to be true
    end
  end

  describe '.public_list' do
    it 'applies depositor filter values and sort_ingested_desc' do
      fake = search_with_fake_dsl

      Dataset.public_list(
        params: {
          'depositors' => ['alice@example.org', 'bob@example.org'],
          'sort_by' => 'sort_ingested_desc',
          q: 'public term'
        },
        per_page: 25
      )

      expect(fake.calls).to include([:with, [:depositor, 'alice@example.org']])
      expect(fake.calls).to include([:with, [:depositor, 'bob@example.org']])
      expect(fake.calls).to include([:keywords, ['public term']])
      expect(fake.calls).to include([:order_by, [:ingest_datetime, :desc]])
    end

    it 'uses identifier filter for slash query values' do
      fake = search_with_fake_dsl

      Dataset.public_list(params: { q: '10.13012/B2IDB-PUBLIC' }, per_page: 25)

      expect(fake.calls).to include([:with, [:identifier, '10.13012/B2IDB-PUBLIC']])
      expect(fake.calls.none? { |name, _args| name == :keywords }).to be true
    end

    it 'does not add depositor filters when depositors param is present but empty' do
      fake = search_with_fake_dsl

      Dataset.public_list(params: { 'depositors' => [] }, per_page: 25)

      expect(fake.calls.none? { |name, args| name == :with && args.first == :depositor }).to be true
    end

    it 'falls back to updated_at desc when sort_by is unknown' do
      fake = search_with_fake_dsl

      Dataset.public_list(params: { q: 'public term', 'sort_by' => 'unknown-sort' }, per_page: 25)

      expect(fake.calls).to include([:order_by, [:updated_at, :desc]])
    end
  end

  describe '.facet queries' do
    let(:user) { instance_double(User, email: 'depositor@example.org') }

    it 'admin_facets uses identifier query path when q has slash' do
      fake = search_with_fake_dsl

      Dataset.admin_facets(params: { q: '10.13012/B2IDB-FACET' })

      expect(fake.calls).to include([:with, [:identifier, '10.13012/B2IDB-FACET']])
      expect(fake.calls.none? { |name, _args| name == :keywords }).to be true
    end

    it 'depositor_facets uses keywords path when q has no slash' do
      fake = search_with_fake_dsl

      Dataset.depositor_facets(user: user, params: { q: 'depositor facet term' })

      expect(fake.calls).to include([:keywords, ['depositor facet term']])
      expect(fake.calls).to include([:facet, [:publication_year]])
    end

    it 'depositor_facets uses identifier filter when q includes slash' do
      fake = search_with_fake_dsl

      Dataset.depositor_facets(user: user, params: { q: '10.13012/B2IDB-DEP-FACET' })

      expect(fake.calls).to include([:with, [:identifier, '10.13012/B2IDB-DEP-FACET']])
      expect(fake.calls.none? { |name, _args| name == :keywords }).to be true
    end

    it 'depositor_my_facets includes visibility facet and user draft viewer filter' do
      fake = search_with_fake_dsl

      Dataset.depositor_my_facets(user: user, params: { q: 'my facet term' })

      expect(fake.calls).to include([:with, [:draft_viewer_emails, 'depositor@example.org']])
      expect(fake.calls).to include([:facet, [:visibility_code]])
      expect(fake.calls).to include([:keywords, ['my facet term']])
    end

    it 'public_facets includes public facets and supports slash identifier search' do
      fake = search_with_fake_dsl

      Dataset.public_facets(params: { q: '10.13012/B2IDB-PUBLIC-FACET' })

      expect(fake.calls).to include([:with, [:identifier, '10.13012/B2IDB-PUBLIC-FACET']])
      expect(fake.calls).to include([:facet, [:creator_names]])
      expect(fake.calls).to include([:facet, [:publication_year]])
    end
  end
end
