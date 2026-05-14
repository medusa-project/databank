require 'rails_helper'

RSpec.describe 'Guide controllers', type: :controller do
  let(:admin) { create(:user, :admin) }

  before do
    sign_in admin
  end

  describe Guide::SectionsController do
    it 'GET #index returns sections ordered by ordinal' do
      section2 = create(:guide_section, ordinal: 2)
      section1 = create(:guide_section, ordinal: 1)

      get :index

      expect(response).to be_successful
      expect(assigns(:guide_sections).map(&:id)).to eq([section1.id, section2.id])
    end

    it 'GET #guides for non-manager includes only public sections' do
      public_section = create(:guide_section, public: true, ordinal: 1)
      create(:guide_section, public: false, ordinal: 2)
      allow(controller).to receive(:can?).with(:manage, Guide::Section).and_return(false)

      get :guides

      expect(response).to be_successful
      expect(assigns(:guide_sections)).to contain_exactly(public_section)
      expect(assigns(:title)).to eq('Guides')
    end

    it 'POST #reorder updates ordinals and redirects to index' do
      section1 = create(:guide_section, ordinal: 1)
      section2 = create(:guide_section, ordinal: 2)

      post :reorder, params: { "ordinal_#{section1.id}" => '7', "ordinal_#{section2.id}" => '3' }

      expect(response).to redirect_to(action: 'index')
      expect(section1.reload.ordinal).to eq(7)
      expect(section2.reload.ordinal).to eq(3)
    end
  end

  describe Guide::ItemsController do
    it 'GET #new leaves section_id at default when guide_subitem_section_id is passed' do
      section = create(:guide_section)

      get :new, params: { guide_subitem_section_id: section.id }

      expect(response).to be_successful
      expect(assigns(:guide_item).section_id).to eq(0)
    end

    it 'POST #reorder updates item ordinals and redirects to parent section' do
      section = create(:guide_section)
      item1 = create(:guide_item, section_id: section.id, ordinal: 1)
      item2 = create(:guide_item, section_id: section.id, ordinal: 2)

      post :reorder,
           params: { parent_id: section.id, "ordinal_#{item1.id}" => '8', "ordinal_#{item2.id}" => '4' }

      expect(response).to redirect_to("/guide/sections/#{section.id}")
      expect(item1.reload.ordinal).to eq(8)
      expect(item2.reload.ordinal).to eq(4)
    end
  end

  describe Guide::SubitemsController do
    it 'GET #new prefills item_id when guide_subitem_item_id is passed' do
      item = create(:guide_item)

      get :new, params: { guide_subitem_item_id: item.id }

      expect(response).to be_successful
      expect(assigns(:guide_subitem).item_id).to eq(item.id)
    end

    it 'POST #reorder updates subitem ordinals and redirects to parent item' do
      item = create(:guide_item)
      subitem1 = create(:guide_subitem, item_id: item.id, ordinal: 1)
      subitem2 = create(:guide_subitem, item_id: item.id, ordinal: 2)

      post :reorder,
           params: { parent_id: item.id, "ordinal_#{subitem1.id}" => '5', "ordinal_#{subitem2.id}" => '6' }

      expect(response).to redirect_to("/guide/items/#{item.id}")
      expect(subitem1.reload.ordinal).to eq(5)
      expect(subitem2.reload.ordinal).to eq(6)
    end
  end
end
