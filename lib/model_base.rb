class ModelBase
  def self.method_missing(sym, *args, &block)
    method_name = sym.to_s.split("_")
    if method_name[0..1].join(" ") == "find by"
      col_names = self.get_column_names_from_mm(method_name)
      where_hash = self.build_where_hash(col_names, args)
      self.where(where_hash)
    else
      super(sym, args, &block)
    end
  end

  def self.get_column_names_from_mm(method_name)
    # self.method_missing helper function
    column_names = []

    method_name[2..-1].map do |word|
      if word == 'and'
        # do nothing
      elsif word == 'id'
        column_names.last += "_id"
      else
        column_names << word
      end
    end

    column_names
  end

  def self.build_where_hash(col_names, vals)
    where_hash = {}

    col_names.each_with_index do |name, idx|
      where_hash[name] = vals[idx]
    end

    where_hash
  end

  def self.get_model_name
    model_name = self.name.split(/(?=[A-Z])/).map { |word| word.downcase }
    model_name.join("_") + "s"
  end

  def self.all
    model_name = self.get_model_name

    data = QuestionDBConnection.instance.execute(<<-SQL)
      SELECT
        *
      FROM
        #{model_name}
    SQL

    data.map { |datum| self.new(datum) }
  end

  def self.find_by_id(id)
    model_name = self.get_model_name

    item = QuestionDBConnection.instance.execute(<<-SQL, id)
      SELECT
        *
      FROM
        #{model_name}
      WHERE
        id = ?
    SQL

    return nil unless item.length > 0

    self.new(item.first)
  end

  def self.build_where_clause(cols_vals)
    cvs = cols_vals.map do |cv|
      "#{cv[0]}='#{cv[1]}'"
    end

    cvs.join(" AND ")
  end

  def self.where(options)
    model_name = self.get_model_name

    if options.class == Hash
      where_clause = self.build_where_clause(options)
    elsif options.class == String
      where_clause = options
    else
      p "invalid input"
      return
    end

    query = <<-SQL
      SELECT
        *
      FROM
        #{model_name}
      WHERE
        #{where_clause}
    SQL

    results = QuestionDBConnection.instance.execute(query)

    results.map do |result|
      self.new(result)
    end
  end

  def get_column_names
    vars = self.instance_variables.map { |var| var[1..-1]}
    vars.shift
    vars
  end

  def format_columns_for_insert(columns)
    "(#{columns.join(",")})"
  end

  def format_values_for_update(_columns)
    columns = _columns.map do |col|
      "#{col}='#{self.send(col)}'"
    end

    columns.join(",")
  end

  def get_instance_variable_values
    vars = self.instance_variables.map { |var| var[1..-1]}
    vars.shift
    vars.map {|var| self.send(var)}
  end

  def get_values_string
    vars = self.instance_variables.map { |var| var[1..-1]}
    vars.shift
    question_marks = Array.new(vars.length) { "?" }.join(",")
    "(#{question_marks})"
  end

  def save
    model_name = self.class.get_model_name
    columns = get_column_names

    @id.nil? ? create(columns, model_name) : update(columns, model_name)
  end

  def create(_columns, model_name)
    vars = get_instance_variable_values
    values = get_values_string
    columns = format_columns_for_insert(_columns)

    QuestionDBConnection.instance.execute(<<-SQL, *vars)
    INSERT INTO
      #{model_name} #{columns}
    VALUES
      #{values}
    SQL

    @id = QuestionDBConnection.instance.last_insert_row_id
  end

  def update(_columns, model_name)
    set_vals = format_values_for_update(_columns)

    query = <<-SQL
    UPDATE
      #{model_name}
    SET
      #{set_vals}
    WHERE
      #{model_name}.id = ?
    SQL

    QuestionDBConnection.instance.execute(query, @id)
  end

  def delete
    model_name = self.class.get_model_name
    QuestionDBConnection.instance.execute(<<-SQL, @id)
      DELETE FROM
        #{model_name}
      WHERE
        id = @id
    SQL
  end
end
