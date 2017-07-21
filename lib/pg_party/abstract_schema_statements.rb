module PgParty
  module AbstractSchemaStatements
    def create_master_partition(*args)
      raise NotImplementedError, "#create_master_partition is not implemented"
    end

    def create_child_partition(*args)
      raise NotImplementedError, "#create_child_partition is not implemented"
    end
  end
end
