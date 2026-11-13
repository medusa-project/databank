# frozen_string_literal: true

module GoogleDrive
  class Error < CloudImports::Error; end
  class RetryableError < Error; end
end
