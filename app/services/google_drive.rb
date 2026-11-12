# frozen_string_literal: true

module GoogleDrive
  class Error < StandardError; end
  class RetryableError < Error; end
end
