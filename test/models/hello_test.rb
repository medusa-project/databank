# frozen_string_literal: true

# hello_test.rb
require "test_helper"
require_relative "../../app/models/hello"

class HelloTest < ActiveSupport::TestCase
  test "hello world" do
    assert_equal "world", Hello.world, "Hello.world should return a string called 'world'"
  end
end
