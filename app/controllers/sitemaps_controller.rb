# app/controllers/sitemaps_controller.rb

class SitemapsController < ApplicationController

  layout :false
  before_action :init_sitemap

  def index
    @datasets = Dataset.where(is_test: false).select(&:metadata_public?)
  end

  private

  def init_sitemap
    headers['Content-Type'] = 'application/xml'
  end

end