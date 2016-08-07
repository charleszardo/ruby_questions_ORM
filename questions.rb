require 'sqlite3'
require 'singleton'

class QuestionDBConnection < SQLite3::Database
  include Singleton

  def initialize
    super('questions.db')
    self.type_translation = true
    self.results_as_hash = true
  end
end

class ModelBase
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
end

class User < ModelBase
  attr_accessor :fname, :lname
  attr_reader :id

  def self.find_by_name(fname, lname)
    user = QuestionDBConnection.instance.execute(<<-SQL, fname, lname)
      SELECT
        *
      FROM
        users
      WHERE
        fname = ? AND lname = ?
    SQL

    return nil unless user.length > 0

    User.new(user.first)
  end

  def initialize(options)
    @id = options['id']
    @fname = options['fname']
    @lname = options['lname']
  end

  def authored_questions
    Question.find_by_author_id(@id)
  end

  def authored_replies
    Reply.find_by_user_id(@id)
  end

  def followed_questions
    QuestionFollow.followed_questions_for_user_id(@id)
  end

  def liked_questions
    QuestionLike.liked_questions_for_user_id(@id)
  end

  def average_karma
    karma = QuestionDBConnection.instance.execute(<<-SQL, @id)
      SELECT
        CAST(COUNT(question_likes.id) AS FLOAT) / COUNT(DISTINCT(questions.id)) as avg_karma
      FROM
        questions
      LEFT OUTER JOIN
        question_likes
      ON
        questions.id = question_likes.question_id
      WHERE
        questions.author_id = ?
    SQL

    karma.first["avg_karma"]
  end
end

class Question < ModelBase
  attr_accessor :title, :body
  attr_reader :id, :author_id

  def self.find_by_author_id(author_id)
    questions = QuestionDBConnection.instance.execute(<<-SQL, author_id)
      SELECT
        *
      FROM
        questions
      WHERE
        author_id = ?
    SQL

    return nil unless questions.length > 0

    questions.map { |question| Question.new(question) }
  end

  def self.most_followed(n)
    QuestionFollow.most_followed_questions(n)
  end

  def self.most_liked(n)
    QuestionLike.most_liked_questions(n)
  end

  def initialize(options)
    @id = options['id']
    @title = options['title']
    @body = options['body']
    @author_id = options['author_id']
  end

  def author
    User.find_by_id(@author_id)
  end

  def replies
    Reply.find_by_question_id(@id)
  end

  def followers
    QuestionFollow.followers_for_question_id(@id)
  end

  def likers
    QuestionLike.likers_for_question_id(@id)
  end

  def num_likes
    QuestionLike.num_likes_for_question_id(@id)
  end
end

class QuestionFollow < ModelBase

  def self.followers_for_question_id(question_id)
    users = QuestionDBConnection.instance.execute(<<-SQL, question_id)
      SELECT
        *
      FROM
        users
      JOIN
        question_follows
      ON
        users.id = question_follows.user_id
      WHERE
        question_follows.question_id = ?
    SQL

    return nil unless users.length > 0

    users.map { |user| User.new(user) }
  end

  def self.followed_questions_for_user_id(user_id)
    questions = QuestionDBConnection.instance.execute(<<-SQL, user_id)
      SELECT
        questions.*
      FROM
        question_follows
      JOIN
        questions
      ON
        questions.id = question_follows.question_id
      WHERE
        question_follows.user_id = ?
    SQL

    return nil unless questions.length > 0

    questions.map { |question| Question.new(question) }
  end

  def self.most_followed_questions(n)
    question_ids = QuestionDBConnection.instance.execute(<<-SQL, n)
      SELECT
        questions.id
      FROM
        questions
      JOIN
        question_follows
      ON
        questions.id = question_follows.question_id
      GROUP BY
        questions.id
      ORDER BY
        COUNT(question_follows.id) DESC
      LIMIT
        ?
    SQL

    return nil unless question_ids.length > 0

    question_ids.map { |id_obj| Question.find_by_id(id_obj['id']) }
  end

  def initialize(options)
    @id = options['id']
    @user_id = options['user_id']
    @question_id = options['question_id']
  end
end

class Reply < ModelBase
  attr_accessor :body
  attr_reader :id, :question_id, :parent_reply_id

  def self.get_model_name
    "replies"
  end

  def self.find_by_user_id(user_id)
    replies = QuestionDBConnection.instance.execute(<<-SQL, user_id)
      SELECT
        *
      FROM
        replies
      WHERE
        user_id = ?
    SQL

    return nil unless replies.length > 0

    replies.map { |reply| Reply.new(reply) }
  end

  def self.find_by_question_id(question_id)
    replies = QuestionDBConnection.instance.execute(<<-SQL, question_id)
      SELECT
        *
      FROM
        replies
      WHERE
        question_id = ?
    SQL

    return nil unless replies.length > 0

    replies.map { |reply| Reply.new(reply) }
  end

  def initialize(options)
    @id = options['id']
    @body = options['body']
    @question_id = options['question_id']
    @parent_reply_id = options['parent_reply_id']
    @user_id = options['user_id']
  end

  def author
    User.find_by_id(@user_id)
  end

  def question
    Question.find_by_id(@question_id)
  end

  def parent_reply
    Reply.find_by_id(@parent_reply_id)
  end

  def child_replies
    replies = QuestionDBConnection.instance.execute(<<-SQL)
      SELECT
        *
      FROM
        replies
      WHERE
        parent_reply_id = #{@id}
    SQL

    return nil unless replies.length > 0

    replies.map { |reply| Reply.new(reply) }
  end
end

class QuestionLike < ModelBase
  def self.likers_for_question_id(question_id)
    likers = QuestionDBConnection.instance.execute(<<-SQL, question_id)
      SELECT
        users.*
      FROM
        users
      JOIN
        question_likes
      ON
        users.id = question_likes.user_id
      WHERE
        question_likes.question_id = ?
    SQL

    return nil unless likers.length > 0

    likers.map { |liker| User.new(liker) }
  end

  def self.num_likes_for_question_id(question_id)
    likes = QuestionDBConnection.instance.execute(<<-SQL, question_id)
      SELECT
        COUNT(id) AS num
      FROM
        question_likes
      WHERE
        question_id = ?
    SQL

    return likes.first["num"]
  end

  def self.liked_questions_for_user_id(user_id)
    questions = QuestionDBConnection.instance.execute(<<-SQL, user_id)
      SELECT
        questions.*
      FROM
        questions
      JOIN
        question_likes
      ON
        questions.id = question_likes.question_id
      WHERE
        question_likes.user_id = ?
    SQL

    return nil unless questions.length > 0

    questions.map { |question| Question.new(question)}
  end

  def self.most_liked_questions(n)
    questions = QuestionDBConnection.instance.execute(<<-SQL, n)
      SELECT
        questions.*
      FROM
        questions
      JOIN
        question_likes
      ON
        questions.id = question_likes.question_id
      GROUP BY
        questions.id
      LIMIT
        ?
    SQL

    return nil unless questions.length > 0

    questions.map { |question| Question.new(question)}
  end

  attr_reader :question_id, :user_id

  def initialize(options)
    @id = options['id']
    @question_id = options['question_id']
    @user_id = options['user_id']
  end
end

p User.where("fname='user1'")
