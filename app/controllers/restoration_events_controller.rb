# frozen_string_literal: true

class RestorationEventsController < ApplicationController
  # Responds to `GET /restoration_events`
  def index
    @events = RestorationEvent.all
  end
end