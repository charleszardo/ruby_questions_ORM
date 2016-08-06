# Questions ORM

Simple Ruby ORM.  Interacts with database that has the following tables: users, questions, question_likes, question_follows, and replies.

### Run Locally

- This application uses SQLite3.  If you don't have SQLite3 on your machine, begin by installing it.
- Create database by running `cat import_db.sql | sqlite3 questions.db`
- Run `bundle install` to install the sqlite3 gem in the application.
