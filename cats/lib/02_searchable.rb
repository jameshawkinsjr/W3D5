require_relative 'db_connection'
require_relative '01_sql_object'

module Searchable
  def where(params)
    raise "#{self} not in database" unless self.id
    update_cols = self.class.columns.map { |col| col.to_s + " = ? "}
    update_cols = update_cols.join(" AND ")
    # debugger
    DBConnection.instance.execute(<<-SQL, *params)
			SELECT
				*
			FROM
        #{self.class.table_name}
			WHERE
        #{update_cols}
		SQL
  end
end

class SQLObject
  require Searchable
end
