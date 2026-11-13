# frozen_string_literal: true

class CloudImports::TransferSlot
  LOCK_KEY = 4_727_301_847

  def self.synchronize
    connection = ActiveRecord::Base.connection
    return false unless connection.select_value("SELECT pg_try_advisory_lock(#{LOCK_KEY})")

    begin
      yield
      true
    ensure
      connection.select_value("SELECT pg_advisory_unlock(#{LOCK_KEY})")
    end
  end
end
