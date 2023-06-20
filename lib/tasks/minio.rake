# frozen_string_literal: true

namespace :minio do
  desc "ensure local buckets"
  task ensure_local_buckets: :environment do
    StorageManager.instance.ensure_local_buckets
  end
end
