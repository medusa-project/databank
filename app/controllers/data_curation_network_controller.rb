# frozen_string_literal: true

class DataCurationNetworkController < ApplicationController
  def index; end

  def accounts
    @accounts = Invitee.where(role: Databank::UserRole::NETWORK_REVIEWER)
    authorize! :manage, Invitee
  end

  def my_account
    unless current_user&.email
      redirect_to("/data_curation_network", notice: "Log in to curate datasets or manage your account.") && return
    end
    @identity = Identity.find_by(email: current_user.email)
    redirect_to("/data_curation_network", notice: "Unable to verify identity.") unless @identity
  end

  def add_account
    authorize! :manage, Invitee
    @invitee = Invitee.new
    @invitee.expires_at = Time.current + 3.months
    @invitee.role = Databank::UserRole::NETWORK_REVIEWER
    @role_arr = []
    @role_arr.push(Databank::UserRole::NETWORK_REVIEWER)
    render "data_curation_network/account/add"
  end

  def edit_account
    set_invitee
    unless @invitee
      redirect_to("/data_curation_network", notice: "error: unable to validate account identifier") && return
    end
    authorize! :manage, @invitee
    render "data_curation_network/account/edit"
  end

  def register; end

  def login; end

  def after_registration; end

  def datasets
    nondraft_states = [Databank::PublicationState::RELEASED,
                       Databank::PublicationState::Embargo::FILE,
                       Databank::PublicationState::Embargo::METADATA]
    @drafts = Dataset.where(data_curation_network: true).where(publication_state: Databank::PublicationState::DRAFT)
    @nondrafts = Dataset.where(data_curation_network: true).where(publication_state: nondraft_states)
  end

  private

  def set_invitee
    @invitee = Invitee.find(params[:id])
    @invitee ||= Invitee.find(params[:invitee_id])
    if @invitee.nil? && current_user&.role == Databank::UserRole::NETWORK_REVIEWER
      @invitee = Invitee.find_by(email: current_user.email)
    end
    nil unless @invitee
  end
end
