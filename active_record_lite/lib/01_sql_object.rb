require_relative 'db_connection'
require 'active_support/inflector'
require 'byebug'
# NB: the attr_accessor we wrote in phase 0 is NOT used in the rest
# of this project. It was only a warm up.

class SQLObject
  def self.columns
    return @columns if @columns
    @columns = DBConnection.execute2(<<-SQL)
              SELECT
                *
              FROM
              '#{self.table_name}'
            SQL

    @columns = @columns.first.map(&:to_sym) unless @columns.first.is_a?(Symbol)
    return @columns
  end

  def self.finalize!
    self.columns.each do |column|
      define_method(column) do
        self.attributes[column]
      end

      define_method("#{column}=") do |value|
        self.attributes[column] = value
      end
    end
  end

  def self.table_name=(table_name)
    @table_name = table_name
  end

  def self.table_name
    @table_name || @table_name = self.to_s.tableize
  end

  def self.all
    table = DBConnection.execute(<<-SQL)
              SELECT *
              FROM "#{self.table_name}"
            SQL

    self.parse_all(table)
  end

  def self.parse_all(results)
    results.map { |row| self.new(row) }
  end

  def self.find(id)
    find = DBConnection.execute(<<-SQL, id)
            SELECT *
            FROM "#{self.table_name}"
            WHERE id = ?
          SQL
    return nil if find.empty?
    self.new(find.first)
  end

  def initialize(params = {})
    params.each do |param, value|
      param = param.to_sym

      if self.class.columns.include?(param)
        self.send("#{param}=", value)
      else
        raise "unknown attribute '#{param}'"
      end
    end
  end

  def attributes
    @attributes ||= Hash.new
  end

  def attribute_values
    values = []

    self.attributes.each do |k,v|
      values << v
    end

    values
  end

  def insert
    col_names = self.class.columns.drop(1).join(', ')
    params = (['?'] * self.attribute_values.length).join(',')

    DBConnection.execute(<<-SQL, *attribute_values)
      INSERT INTO #{self.class.table_name} (#{col_names})
      VALUES (#{params})
    SQL

    self.id = DBConnection.last_insert_row_id
  end

  def update
    set_row = self.class.columns.drop(1).map {|col| "#{col} = ?"}.join(',')

    DBConnection.execute(<<-SQL, *attribute_values.drop(1))
      UPDATE #{self.class.table_name}
      SET #{set_row}
      WHERE id = #{self.id}
    SQL
  end

  def save
    if id
      update
    else
      insert
    end
  end
end
