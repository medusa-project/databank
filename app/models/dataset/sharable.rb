# frozen_string_literal: true

##
# This module supports the sharing of unpublished datasets using a share code.
# It is included in the Dataset model.

module Dataset::Sharable
  extend ActiveSupport::Concern

  ##
  # Sharing link
  # This method returns the sharing link for the dataset
  # It returns the sharing link if there is a current share code
  # Otherwise, it returns "N/A no current sharing link"
  # @return [String] the sharing link for the dataset
  def sharing_link
    return "N/A no current sharing link" unless current_share_code

    "#{IDB_CONFIG[:root_url_text]}/datasets/#{key}?code=#{current_share_code}"
  end

  ##
  # Current share code
  # This method returns the current share code for the dataset
  # It destroys the share code if it is older than one year
  # It returns nil if there is no share code
  # @return [String] the current share code for the dataset
  def current_share_code
    share_code.destroy if share_code && share_code.created_at < 1.year.ago

    return nil unless share_code

    share_code.code
  end

end
