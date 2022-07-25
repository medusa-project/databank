class RestorationEventsController < ApplicationController
  def index
    @events = RestorationEvent.all
  end
end