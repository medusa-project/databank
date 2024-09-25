# frozen_string_literal: true

class HelpController < ApplicationController
  # Responds to `GET /help`
  # redirects to guides, since the help content has been migrated to guides
  def index; end
end
