# frozen_string_literal: trueQ

require "erb"

include ActiveRecord::Tasks

root_dir = File.expand_path("../../dummy", __FILE__)

DatabaseTasks.env = ENV["RAILS_ENV"]
DatabaseTasks.root = root_dir
DatabaseTasks.database_configuration = YAML.load(ERB.new(File.read("#{root_dir}/config/database.yml")).result)
DatabaseTasks.db_dir = "#{root_dir}/db"
DatabaseTasks.migrations_paths = "#{root_dir}/db/migrate"

task :environment do
  ActiveRecord::Base.configurations = DatabaseTasks.database_configuration
  ActiveRecord::Base.establish_connection DatabaseTasks.env.to_sym
end

load "active_record/railties/databases.rake"
