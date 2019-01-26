require_relative 'db_connection'
require 'active_support/inflector'
require 'byebug'

# NB: the attr_accessor we wrote in phase 0 is NOT used in the rest
# of this project. It was only a warm up.

class SQLObject
  def self.columns
    @data ? @data : @data = DBConnection.execute2(<<-SQL)
      SELECT
        *
      FROM
        #{self.table_name}
      SQL
    @data[0].map { |datum| datum.to_sym}
  end

  def self.finalize!
    columns.each do |column|
      define_method(column) do
        self.attributes[column]
      end
      define_method("#{column}=") do |val|
        self.attributes[column] = val
      end
    end
  end

  def self.table_name=(table_name)
    @table_name = table_name
  end

  def self.table_name
    @table_name || self.name.tableize
  end

  def self.all
    results = DBConnection.execute(<<-SQL)
    SELECT
      *
    FROM
      #{table_name}
    SQL
    results.map { |datum| self.new(datum)}
  end

  def self.parse_all(results)
    all = []
    results.each do |result|
      all << self.new(result)
    end
    all
  end

  def self.find(id)
    result = DBConnection.execute(<<-SQL, id)
    SELECT
      *
    FROM
      #{self.table_name}
    WHERE
      id = ?
    SQL
    result.map { |datum| self.new(datum)}.first
  end

  def initialize(params = {})
    params.each do |key, value|
      key = key.to_sym
      # debugger
      if self.class.columns.include?(key) == false
        raise "unknown attribute '#{key}'"
      else
        send("#{key}=", value)
      end
    end
  end

  def attributes
    @attributes || @attributes = {}
  end

  def attribute_values
    self.class.columns.map { |col| self.send(col) }
  end

  def insert
    raise "#{self} already in database" if self.id
    cols, qs, args = get_cols_qs_args
    # debugger
    DBConnection.instance.execute(<<-SQL, *args)
      INSERT INTO
        '#{self.class.table_name}' (#{cols})
      VALUES
        (#{qs})
    SQL
    self.id = DBConnection.last_insert_row_id
  end

  def get_cols_qs_args
    cols = self.class.columns.join(", ")
    args = attribute_values
    qs = ["?"]*self.class.columns.length
    [cols, qs.join(", "), args]
  end

  def update
    raise "#{self} not in database" unless self.id
    update_cols = self.class.columns.map { |col| col.to_s + " = ?"}
    update_cols = update_cols.join(", ")
    args = attribute_values
    # debugger
    DBConnection.instance.execute(<<-SQL, *args, id)
			UPDATE
				#{self.class.table_name}
			SET
				#{update_cols}
			WHERE
        id = ?
		SQL
  end

  def save
    self.id ? update : insert
  end
end
