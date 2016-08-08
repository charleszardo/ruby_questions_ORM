require_relative 'main'

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
