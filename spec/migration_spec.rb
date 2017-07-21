require "spec_helper"

RSpec.describe ActiveRecord::Migration do
  describe "#create_master_partition" do
    it "connection responds to method" do
      expect(ActiveRecord::Base.connection).to respond_to(:create_master_partition)
    end
  end

  describe "#create_child_partition" do
    it "connection responds to method" do
      expect(ActiveRecord::Base.connection).to respond_to(:create_child_partition)
    end
  end
end
