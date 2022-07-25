# frozen_string_literal: true

class IllinoisExpertsController < ApplicationController
  def index
    datasets_xml = Dataset.to_illinois_experts

    render(xml: {error: "error generating xml for datasets"}.to_xml) && return unless datasets_xml

    render xml: datasets_xml
  end

  def persons
    authorize! :manage, IllinoisExpertsClient

    render xml: {error: "missing email"}.to_xml && return unless params["email"]

    person_xml = IllinoisExpertsClient.persons(params["email"])

    if person_xml.nil?
      render(xml: {error: %Q[person not found in Illinois Experts, email: #{params["email"]}]}.to_xml) && return
    end

    render xml: person_xml
  end

  def example
    authorize! :manage, IllinoisExpertsClient

    example_xml = IllinoisExpertsClient.example

    render(xml: {error: "example not found"}.to_xml) && return unless example_xml

    render xml: example_xml
  end
end
