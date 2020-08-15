# frozen_string_literal: true

module PgVersionHelper
  def self.postgres_10?
    version >= 100000 && version < 110000
  end

  def self.postgres_11_plus?
    version >= 110000
  end

  def self.version
    @version ||= ActiveRecord::Base.connection.postgresql_version
  end
end
