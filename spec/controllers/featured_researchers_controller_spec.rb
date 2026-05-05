require 'rails_helper'

RSpec.describe FeaturedResearchersController, type: :controller do
  let(:admin) { create(:user, :admin) }

  describe 'GET #index' do
    let!(:active_researcher) { FeaturedResearcher.create!(name: 'Active Researcher', is_active: true) }
    let!(:inactive_researcher) { FeaturedResearcher.create!(name: 'Inactive Researcher', is_active: false) }

    it 'assigns all featured researchers for admins' do
      sign_in admin

      get :index

      expect(response).to be_successful
      expect(assigns(:featured_researchers)).to match_array([active_researcher, inactive_researcher])
      expect(assigns(:title)).to eq('Featured Researchers')
    end

    it 'assigns only active featured researchers for public users' do
      relation = instance_double(ActiveRecord::Relation)
      allow(FeaturedResearcher).to receive(:where).with(is_active: true).and_return(relation)
      allow(relation).to receive(:order).with('RANDOM()').and_return([active_researcher])
      allow(controller).to receive(:current_user).and_return(nil)

      get :index

      expect(response).to be_successful
      expect(assigns(:featured_researchers)).to eq([active_researcher])
      expect(assigns(:title)).to eq('Featured Researchers')
    end
  end

  describe 'GET #show' do
    it 'uses the researcher name as the title when present' do
      researcher = FeaturedResearcher.create!(name: 'Dana Researcher')

      get :show, params: { id: researcher.id }

      expect(response).to be_successful
      expect(assigns(:title)).to eq('Dana Researcher')
    end

    it 'falls back to a generic title when name is blank' do
      researcher = FeaturedResearcher.create!(name: '')

      get :show, params: { id: researcher.id }

      expect(response).to be_successful
      expect(assigns(:title)).to eq('Featured Researcher')
    end
  end

  describe 'GET #preview' do
    it 'falls back to a generic title when name is blank' do
      sign_in admin
      researcher = FeaturedResearcher.create!(name: '')

      get :preview, params: { id: researcher.id }

      expect(response).to be_successful
      expect(assigns(:title)).to eq('Featured Researcher')
    end
  end

  describe 'GET #new' do
    it 'returns success and assigns the new page title for admins' do
      sign_in admin

      get :new

      expect(response).to be_successful
      expect(assigns(:featured_researcher)).to be_a_new(FeaturedResearcher)
      expect(assigns(:title)).to eq('New Featured Researcher')
    end
  end

  describe 'GET #edit' do
    before do
      sign_in admin
    end

    it 'uses the researcher name in the edit title when present' do
      researcher = FeaturedResearcher.create!(name: 'Dana Researcher')

      get :edit, params: { id: researcher.id }

      expect(response).to be_successful
      expect(assigns(:title)).to eq('Edit Dana Researcher')
    end

    it 'falls back to the researcher id when the name is blank' do
      researcher = FeaturedResearcher.create!(name: '')

      get :edit, params: { id: researcher.id }

      expect(response).to be_successful
      expect(assigns(:title)).to eq("Edit Featured Researcher #{researcher.id}")
    end
  end

  describe 'POST #create' do
    before do
      sign_in admin
    end

    it 'creates a featured researcher and redirects to preview' do
      expect {
        post :create, params: {
          featured_researcher: {
            name: 'Created Researcher',
            question: 'What changed?',
            is_active: true
          }
        }
      }.to change(FeaturedResearcher, :count).by(1)

      expect(response).to redirect_to(preview_featured_researcher_path(FeaturedResearcher.last))
    end

    it 'renders new when save fails' do
      allow_any_instance_of(FeaturedResearcher).to receive(:save).and_return(false)

      post :create, params: {
        featured_researcher: {
          name: 'Created Researcher',
          question: 'What changed?',
          is_active: true
        }
      }

      expect(response).to render_template(:new)
    end
  end

  describe 'PUT #update' do
    let!(:researcher) { FeaturedResearcher.create!(name: 'Before Update', question: 'Old question') }

    before do
      sign_in admin
    end

    it 'updates the featured researcher and renders preview' do
      put :update, params: {
        id: researcher.id,
        featured_researcher: {
          name: 'After Update',
          question: 'New question'
        }
      }

      expect(response).to render_template(:preview)
      expect(researcher.reload.name).to eq('After Update')
    end

    it 'renders edit when update fails' do
      allow_any_instance_of(FeaturedResearcher).to receive(:update).and_return(false)

      put :update, params: {
        id: researcher.id,
        featured_researcher: {
          name: 'After Update'
        }
      }

      expect(response).to render_template(:edit)
    end
  end

  describe 'DELETE #destroy' do
    before do
      sign_in admin
    end

    it 'destroys the featured researcher and redirects to index' do
      researcher = FeaturedResearcher.create!(name: 'Destroy Me')

      expect {
        delete :destroy, params: { id: researcher.id }
      }.to change(FeaturedResearcher, :count).by(-1)

      expect(response).to redirect_to(featured_researchers_url)
    end
  end
end