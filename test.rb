x = User.all.last
x.authored_questions
x.authored_replies
x.followed_questions
x.liked_questions
x.average_karma

x = Question.all.last
x.author
x.replies
x.followers
x.likers
x.num_likes

QuestionFollow.followers_for_question_id(1)
QuestionFollow.followed_questions_for_user_id(1)
QuestionFollow.most_followed_questions(1)

x = Reply.all.last
x.author
x.question
x.parent_reply
x.child_replies
Reply.find_by_question_id(1)
Reply.find_by_user_id(1)

QuestionLike.likers_for_question_id(1)
QuestionLike.num_likes_for_question_id(1)
QuestionLike.liked_questions_for_user_id(1)
QuestionLike.most_liked_questions(1)
