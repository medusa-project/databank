# frozen_string_literal: true

class SitemapsController < ApplicationController

  layout :false
  before_action :init_sitemap

  # Responds to GET /sitemap.xml
  def index
    @datasets = Dataset.where(is_test: false).select(&:metadata_public?)
  end

  private

  def init_sitemap
    headers['Content-Type'] = 'application/xml'
  end

end