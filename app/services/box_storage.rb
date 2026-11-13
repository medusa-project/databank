# frozen_string_literal: true

module BoxStorage
  class Error < CloudImports::Error; end
  class RetryableError < Error; end
end
