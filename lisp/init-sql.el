;;; init-sql.el --- SQL -*- lexical-binding: t; -*-

(require 'sql)

(add-to-list 'process-coding-system-alist
             '("psql\\(\\.exe\\)?\\'"
               . (utf-8-unix . utf-8-unix)))

;;; PostgreSQL process environment

(defun my/sql-postgres-with-password
    (original product options &optional buffer-name)
  "Start PostgreSQL with UTF-8 and English messages."
  (let ((process-environment
         (append
          (when (and (stringp sql-password)
                     (not (string-empty-p sql-password)))
            (list (concat "PGPASSWORD=" sql-password)))
          '("LC_ALL=C"
            "LC_MESSAGES=C"
            "LANG=C"
            "LANGUAGE=C"
            "PGCLIENTENCODING=UTF8")
          process-environment)))
    (funcall original product options buffer-name)))

(advice-add 'sql-comint-postgres
            :around #'my/sql-postgres-with-password)

(defun my/sql-setup ()
  "Configure SQL editing."

  ;; Spaces instead of tabs.
  (setq-local indent-tabs-mode nil)
  (setq-local tab-width 4))

(add-hook 'sql-mode-hook #'my/sql-setup)

;; Do not automatically start a PostgreSQL language
;; server for every SQL file: some files may use
;; ClickHouse or SQLite.
(setq sql-product 'postgres)

(load (expand-file-name "sql-connections.el"
                        user-emacs-directory)
      t)
;;; Database connections in SQL context menu

(defun my/sql-context-connections (menu _click)
  "Add saved database connections to SQL context menu."
  (when (and buffer-file-name
             (not (derived-mode-p 'clutch-mode))
             (string-match-p "\\.sql\\'" buffer-file-name)
             sql-connection-alist)
    (let ((submenu (make-sparse-keymap "Connections"))
          (index 0))
      (dolist (connection (reverse sql-connection-alist))
        (let ((name (car connection)))
          (define-key
            submenu
            (vector (intern (format "sql-connection-%d" index)))
            (cons name
                  (lambda ()
                    (interactive)
                    (sql-connect name)))))
        (setq index (1+ index)))
      (define-key menu [my-sql-connections]
        (cons "Открыть iSQL…" submenu))))
  menu)

(defun my/sql-setup-context-menu ()
  "Enable database connection menu in SQL buffers."
  (add-hook 'context-menu-functions
            #'my/sql-context-connections nil t))

(add-hook 'sql-mode-hook #'my/sql-setup-context-menu)

;;; Share PostgreSQL connections with Clutch

(setq clutch-connection-alist
      (delq nil
            (mapcar
             (lambda (entry)
               (let* ((name (car entry))
                      (params (cdr entry))
                      (product (let ((value (cadr (assq 'sql-product params))))
                                 (if (and (consp value) (eq (car value) 'quote))
                                     (cadr value)
                                   value)))
                      (host (cadr (assq 'sql-server params)))
                      (port (or (cadr (assq 'sql-port params)) 5432))
                      (user (cadr (assq 'sql-user params)))
                      (database (cadr (assq 'sql-database params)))
                      (password (cadr (assq 'sql-password params))))
                 (when (eq product 'postgres)
                   (cons name
                         (list :backend 'pg
                               :host host
                               :port (if (stringp port)
                                         (string-to-number port)
                                       port)
                               :user user
                               :database database
                               :password password
			       :sslmode 'require)))))
             sql-connection-alist)))

;;; Clutch context menu
(defun my/clutch-connected-p ()
  "Return whether this buffer has a live Clutch connection, without connecting."
  (and (bound-and-true-p clutch-connection)
       (fboundp 'clutch--connection-alive-p)
       (clutch--connection-alive-p clutch-connection)))

(defun my/clutch-status-label ()
  "Describe cached Clutch status without fetching database metadata."
  (if (not (my/clutch-connected-p))
      "Clutch: не подключён"
    (let ((label (and (boundp 'clutch--connection-render-state)
                      (plist-get clutch--connection-render-state :connection-label))))
      (if (and (stringp label) (not (string-empty-p label)))
          (concat "Clutch: " label)
        "Clutch: подключён"))))

(defun my/clutch-browse-objects ()
  "Browse Clutch objects with completions shown immediately."
  (interactive)
  (minibuffer-with-setup-hook
      #'minibuffer-completion-help
    (call-interactively #'clutch-object-browse)))

(defun my/clutch-context-menu (menu _click)
  "Add Clutch commands to the context menu."
  (define-key menu [my-clutch-status]
    (list 'menu-item (my/clutch-status-label) #'ignore :enable nil))
  (define-key menu [my-clutch-execute-region]
    '(menu-item "Выполнить выделение" clutch-execute-region
                :enable (and (my/clutch-connected-p) (use-region-p))))
  (define-key menu [my-clutch-execute-buffer]
    '(menu-item "Выполнить весь SQL" clutch-execute-buffer
                :enable (my/clutch-connected-p)))
  (define-key menu [my-clutch-connect]
    '(menu-item "Подключить этот файл…" my/clutch-connect-file
                :enable (not (my/clutch-connected-p))))
  (define-key menu [my-clutch-change-connection]
    '(menu-item "Сменить подключение…" my/clutch-connect-file
                :enable (my/clutch-connected-p)))
  (define-key menu [my-clutch-disconnect]
    '(menu-item "Отключиться" clutch-disconnect :enable (my/clutch-connected-p)))
  (define-key menu [my-clutch-switch-schema]
    '(menu-item "Переключить схему..." clutch-switch-schema
                :enable (my/clutch-connected-p)))
  (define-key menu [my-clutch-object-browse]
  '(menu-item "Показать объекты БД..."
              my/clutch-browse-objects :enable (my/clutch-connected-p)))
  menu)

(defun my/clutch-setup-context-menu ()
  "Enable context menu commands in Clutch console."
  (add-hook 'context-menu-functions
            #'my/clutch-context-menu nil t))

(with-eval-after-load 'clutch
  (add-hook 'clutch-mode-hook
            #'my/clutch-setup-context-menu))

;;; Clutch result context menu

(defun my/clutch-result-context-menu (menu _click)
  "Add Clutch result commands to the context menu."
  (define-key menu [my-clutch-open-record]
    '(menu-item "Просмотреть запись вертикально"
                clutch-result-open-record))
  menu)

(defun my/clutch-result-setup-context-menu ()
  "Enable context menu commands in Clutch results."
  (add-hook 'context-menu-functions
            #'my/clutch-result-context-menu nil t))

(with-eval-after-load 'clutch
  (add-hook 'clutch-result-mode-hook
            #'my/clutch-result-setup-context-menu))

;;; Clutch record context menu

(defun my/clutch-record-context-menu (menu _click)
  "Add navigation commands to the Clutch record context menu."
  (define-key menu [my-clutch-record-next]
    '(menu-item "Следующая запись" clutch-record-next-row))
  (define-key menu [my-clutch-record-prev]
    '(menu-item "Предыдущая запись" clutch-record-prev-row))
  menu)

(defun my/clutch-record-setup-context-menu ()
  "Enable context menu in Clutch Record View."
  (add-hook 'context-menu-functions
            #'my/clutch-record-context-menu nil t))

(with-eval-after-load 'clutch
  (add-hook 'clutch-record-mode-hook
            #'my/clutch-record-setup-context-menu))

(provide 'init-sql)
