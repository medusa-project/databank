# frozen_string_literal: true

##
# NestedItem model
# @note: This model is used to store the nested items of the datafile for archive files such as zip, tar, etc.
# @note: This model is associated with the Datafile model
class NestedItem < ApplicationRecord
  belongs_to :datafile
end
