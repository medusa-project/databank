# frozen_string_literal: true

class Definition < ApplicationRecord
  def to_param
    term
  end
end
