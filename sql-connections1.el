;;; sql-connections.el --- Database connections -*- lexical-binding: t; -*-

(setq sql-connection-alist
      '(("ra1"
         (sql-product 'postgres)
         (sql-server "bi2.datacollectfps.win")
         (sql-port 5432)
         (sql-user "analytics2")
         (sql-password "xxxxxxxxx")
         (sql-database "analytics")))
      '(("lw"
         (sql-product 'postgres)
         (sql-server "ep-blue-hat-b1zmxxp7-pooler.c-5.eu-central-1.aws.neon.tech")
         (sql-port 5432)
         (sql-user "quiz-let-wine-role")
         (sql-password "xxxxxxxxxxxx")
         (sql-database "quiz.let.wine")))
      )

(provide 'sql-connections)
