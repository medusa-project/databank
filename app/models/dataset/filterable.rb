# frozen_string_literal: true

##
# Supports searching and filtering datasets
# for different user roles
#
# This module is included in the Dataset model
#
# The filtered_list method is the main entry point
# for searching and filtering datasets
#
# The method takes a user role, a user object, and a params hash
#
# The user role is one of the Databank::UserRole constants
#
# The user object is the current user
#
# The params hash is the search parameters
#
# The method returns a list of datasets
#
# The method uses the Dataset.search method from the Sunspot gem
# to search the Solr index
# This module is included in the Dataset model.

module Dataset::Filterable
  extend ActiveSupport::Concern

  class_methods do
    def filtered_list(user_role: Databank::UserRole::GUEST, user: nil, params: {})
      per_page = if params.has_key?(:per_page) && params[:per_page].to_i > 0 && params[:per_page].to_i <= 100
                   params[:per_page].to_i
                 else
                   25
                 end
      case user_role
      when Databank::UserRole::ADMIN
        list = admin_list(params: params, per_page: per_page)
        facets = admin_facets(params: params)
        list = list_with_facet(list: list, search_get_facets: facets, facet: :visibility_code)
        list = list_with_facet(list: list, search_get_facets: facets, facet: :depositor)
      when Databank::UserRole::DEPOSITOR
        raise ArgumentError.new("net_id required for depositor role") if user.nil?

        list = depositor_list(user: user, params: params, per_page: per_page)
        facets = depositor_facets(user: user, params: params)
        list = list_with_facet(list: list, search_get_facets: facets, facet: :visibility_code)
      else
        list = public_list(params: params, per_page: per_page)
        facets = public_facets(params: params)
      end
      [:subject_text, :publication_year, :license_code, :funder_codes].each do |facet|
        list = list_with_facet(list: list, search_get_facets: facets, facet: facet)
      end
      list
    end

    def admin_list(params: {}, per_page: 25)
      Dataset.search do
        without(:depositor, "error")

        if params.has_key?("license_codes")
          any_of do
            params["license_codes"].each do |license_code|
              with :license_code, license_code
            end
          end
        end

        if params.has_key?("subjects")
          any_of do
            params["subjects"].each do |subject|
              with :subject_text, subject
            end
          end
        end

        if params.has_key?("depositors")
          any_of do
            params["depositors"].each do |depositor_netid|
              with :depositor_netid, depositor_netid
            end
          end
        end

        if params.has_key?("funder_codes")
          any_of do
            params["funder_codes"].each do |funder_code|
              with :funder_codes, funder_code
            end
          end
        end

        if params.has_key?("visibility_codes")
          any_of do
            params["visibility_codes"].each do |visibility_code|
              with :visibility_code, visibility_code
            end
          end
        end

        if params.has_key?("publication_years")
          any_of do
            params["publication_years"].each do |publication_year|
              with :publication_year, publication_year
            end
          end
        end

        if params[:q] && params[:q].include?('/')
          with :identifier, params[:q]
        else
          keywords(params[:q])
        end

        if params.has_key?("sort_by")
          case params["sort_by"]
          when "sort_updated_asc"
            order_by :updated_at, :asc
          when "sort_released_asc"
            order_by :release_datetime, :asc
          when "sort_released_desc"
            order_by :release_datetime, :desc
          when "sort_ingested_asc"
            order_by :ingest_datetime, :asc
          when "sort_ingested_desc"
            order_by :ingest_datetime, :desc
          else
            order_by :updated_at, :desc
          end
        else
          order_by :updated_at, :desc
        end

        facet(:license_code)
        facet(:funder_codes)
        facet(:depositor)
        facet(:subject_text)
        facet(:visibility_code)
        facet(:hold_state)
        facet(:datafile_extensions)
        facet(:publication_year)

        paginate(page: params[:page] || 1, per_page: per_page)
      end
    end

    def depositor_list(user:, params:, per_page:)
      Dataset.search do
        all_of do
          without(:depositor, "error")
          without(:hold_state, Databank::PublicationState::TempSuppress::VERSION)
          with :is_test, false
          any_of do
            all_of do
              with :draft_viewer_emails, user.email
              with :publication_state, Databank::PublicationState::DRAFT
            end
            all_of do
              with :draft_viewer_emails, user.email
              with :publication_state, Databank::PublicationState::TempSuppress::VERSION
            end
            all_of do
              with :draft_viewer_emails, user.email
              with :publication_state, Databank::PublicationState::Embargo::METADATA
            end
            any_of do
              with :publication_state, Databank::PublicationState::RELEASED
              with :publication_state, Databank::PublicationState::Embargo::FILE
              with :publication_state, Databank::PublicationState::TempSuppress::FILE
              with :publication_state, Databank::PublicationState::PermSuppress::FILE
            end
          end
          if params.has_key?("depositors")
            any_of do
              params["depositors"].each do |depositor_netid|
                with :depositor_netid, depositor_netid
              end
            end
          end
          if params.has_key?("editor")
            any_of do
              with :editor_emails, params["editor"]
              with :depositor_netid, params["editor"]
            end
          end
          if params.has_key?("subjects")
            any_of do
              params["subjects"].each do |subject|
                with :subject_text, subject
              end
            end
          end
          if params.has_key?("license_codes")
            any_of do
              params["license_codes"].each do |license_code|
                with :license_code, license_code
              end
            end
          end
          if params.has_key?("funder_codes")
            any_of do
              params["funder_codes"].each do |funder_code|
                with :funder_codes, funder_code
              end
            end
          end
          if params.has_key?("visibility_codes")
            any_of do
              params["visibility_codes"].each do |visibility_code|
                with :visibility_code, visibility_code
              end
            end
          end
          if params.has_key?("publication_years")
            any_of do
              params["publication_years"].each do |publication_year|
                with :publication_year, publication_year
              end
            end
          end
        end

        if params[:q] && params[:q].include?('/')
          with :identifier, params[:q]
        else
          keywords(params[:q])
        end

        if params.has_key?("sort_by")
          case params["sort_by"]
          when "sort_updated_asc"
            order_by :updated_at, :asc
          when "sort_released_asc"
            order_by :release_datetime, :asc
          when "sort_released_desc"
            order_by :release_datetime, :desc
          when "sort_ingested_asc"
            order_by :ingest_datetime, :asc
          when "sort_ingested_desc"
            order_by :ingest_datetime, :desc
          else
            order_by :updated_at, :desc
          end
        else
          order_by :updated_at, :desc
        end
        facet(:license_code)
        facet(:funder_codes)
        facet(:subject_text)
        facet(:depositor)
        facet(:visibility_code)
        facet(:hold_state)
        facet(:datafile_extensions)
        facet(:publication_year)

        paginate(page: params[:page] || 1, per_page: per_page)
      end
    end

    def public_list(params: {}, per_page: 25)
      Dataset.search do
        all_of do
          without(:depositor, "error")
          with(:is_most_recent_version, true)
          with(:is_test, false)
          without :hold_state, Databank::PublicationState::TempSuppress::METADATA
          without :publication_state, Databank::PublicationState::TempSuppress::VERSION
          any_of do
            with :publication_state, Databank::PublicationState::RELEASED
            with :publication_state, Databank::PublicationState::Embargo::FILE
            with :publication_state, Databank::PublicationState::TempSuppress::FILE
          end

          if params.has_key?("depositors") && params["depositors"].present?
            any_of do
              params["depositors"].each do |depositor|
                with :depositor, depositor
              end
            end
          end

          if params.has_key?("subjects") && params["subjects"].present?
            any_of do
              params["subjects"].each do |subject|
                with :subject_text, subject
              end
            end
          end

          if params.has_key?("publication_years") && params["publication_years"].present?
            any_of do
              params["publication_years"].each do |publication_year|
                with :publication_year, publication_year
              end
            end
          end

          if params.has_key?("license_codes") && params["license_codes"].present?
            any_of do
              params["license_codes"].each do |license_code|
                with :license_code, license_code
              end
            end
          end

          if params.has_key?("funder_codes") && params["funder_codes"].present?
            any_of do
              params["funder_codes"].each do |funder_code|
                with :funder_codes, funder_code
              end
            end
          end
        end

        if params[:q] && params[:q].include?('/')
          with :identifier, params[:q]
        else
          keywords(params[:q])
        end

        if params.has_key?("sort_by")
          case params["sort_by"]
          when "sort_updated_asc"
            order_by :updated_at, :asc
          when "sort_released_asc"
            order_by :release_datetime, :asc
          when "sort_released_desc"
            order_by :release_datetime, :desc
          when "sort_ingested_asc"
            order_by :ingest_datetime, :asc
          when "sort_ingested_desc"
            order_by :ingest_datetime, :desc
          else
            order_by :updated_at, :desc
          end
        else
          order_by :updated_at, :desc
        end
        facet(:license_code)
        facet(:funder_codes)
        facet(:creator_names)
        facet(:subject_text)
        facet(:depositor)
        facet(:visibility_code)
        facet(:hold_state)
        facet(:datafile_extensions)
        facet(:publication_year)

        paginate(page: params[:page] || 1, per_page: per_page)
      end
    end

    def admin_facets(params:)
      Dataset.search do
        without(:depositor, "error")
        with(:is_most_recent_version, true)
        if params[:q] && params[:q].include?('/')
          with :identifier, params[:q]
        else
          keywords(params[:q])
        end
        facet(:license_code)
        facet(:funder_codes)
        facet(:depositor)
        facet(:subject_text)
        facet(:visibility_code)
        facet(:hold_state)
        facet(:datafile_extensions)
        facet(:publication_year)
      end
    end

    def depositor_facets(user:, params:)
      Dataset.search do
        all_of do
          without(:depositor, "error")
          without(:hold_state, Databank::PublicationState::TempSuppress::VERSION)
          with :is_test, false
          any_of do
            all_of do
              with :draft_viewer_emails, user.email
              with :publication_state, Databank::PublicationState::DRAFT
            end
            all_of do
              with :draft_viewer_emails, user.email
              with :publication_state, Databank::PublicationState::TempSuppress::VERSION
            end
            all_of do
              with :draft_viewer_emails, user.email
              with :publication_state, Databank::PublicationState::Embargo::METADATA
            end
            any_of do
              with :publication_state, Databank::PublicationState::RELEASED
              with :publication_state, Databank::PublicationState::Embargo::FILE
              with :publication_state, Databank::PublicationState::TempSuppress::FILE
              with :publication_state, Databank::PublicationState::PermSuppress::FILE
            end
          end
        end
        if params[:q] && params[:q].include?('/')
          with :identifier, params[:q]
        else
          keywords(params[:q])
        end
        facet(:license_code)
        facet(:funder_codes)
        facet(:creator_names)
        facet(:subject_text)
        facet(:depositor)
        facet(:visibility_code)
        facet(:hold_state)
        facet(:datafile_extensions)
        facet(:publication_year)
      end
    end

    def depositor_my_facets(user:, params:)
      Dataset.search do
        all_of do
          without(:depositor, "error")
          without(:hold_state, Databank::PublicationState::TempSuppress::VERSION)
          with :is_test, false
          any_of do
            all_of do
              with :draft_viewer_emails, user.email
              with :publication_state, Databank::PublicationState::DRAFT
            end
            all_of do
              with :draft_viewer_emails, user.email
              with :publication_state, Databank::PublicationState::TempSuppress::VERSION
            end
            all_of do
              with :draft_viewer_emails, user.email
              with :publication_state, Databank::PublicationState::Embargo::METADATA
            end
            any_of do
              with :publication_state, Databank::PublicationState::RELEASED
              with :publication_state, Databank::PublicationState::Embargo::FILE
              with :publication_state, Databank::PublicationState::TempSuppress::FILE
              with :publication_state, Databank::PublicationState::PermSuppress::FILE
            end
          end
        end
        if params[:q] && params[:q].include?('/')
          with :identifier, params[:q]
        else
          keywords(params[:q])
        end
        facet(:visibility_code)
      end
    end

    def public_facets(params:)
      Dataset.search do
        all_of do
          without(:depositor, "error")
          with(:is_most_recent_version, true)
          with :is_test, false
          without :hold_state, Databank::PublicationState::TempSuppress::METADATA
          without :publication_state, Databank::PublicationState::TempSuppress::VERSION
          any_of do
            with :publication_state, Databank::PublicationState::RELEASED
            with :publication_state, Databank::PublicationState::Embargo::FILE
            with :publication_state, Databank::PublicationState::TempSuppress::FILE
            with :publication_state, Databank::PublicationState::PermSuppress::FILE
          end
        end
        if params[:q] && params[:q].include?('/')
          with :identifier, params[:q]
        else
          keywords(params[:q])
        end
        facet(:license_code)
        facet(:funder_codes)
        facet(:creator_names)
        facet(:subject_text)
        facet(:depositor)
        facet(:visibility_code)
        facet(:hold_state)
        facet(:datafile_extensions)
        facet(:publication_year)
      end
    end

    def list_with_facet(list:, search_get_facets:, facet:)
      search_get_facets.facet(facet).rows.each do |outer_row|
        has_this_row = false
        list.facet(facet).rows.each do |inner_row|
          has_this_row = true if inner_row.value == outer_row.value
        end
        list.facet(facet).rows << Placeholder_FacetRow.new(outer_row.value, 0) unless has_this_row
      end
      list
    end
  end
end