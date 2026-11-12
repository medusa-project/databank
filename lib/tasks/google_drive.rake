# frozen_string_literal: true

namespace :google_drive do
  desc "Expire abandoned Google Drive imports and erase temporary authorization credentials"
  task cleanup: :environment do
    GoogleDriveImport.cleanup_expired!
  end
end
