# frozen_string_literal: true

##
# Robot model
# ---------------
# Represents a robot that can be excluded from download counts.
# ---------------
# Attributes
# ---------------
# name: string, required
# description: text, optional

class Robot < ApplicationRecord
  def self.blank_stare_xml
    root_string = %(<error>invalid format request</error>)
    doc = Nokogiri::XML::Document.parse(root_string)
    doc.to_xml
  end
end
