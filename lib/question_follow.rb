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
