;;; init-workspace-menu.el --- Mouse menus for everyday work -*- lexical-binding: t; -*-

(require 'easymenu)
(require 'init-python-workspace)

(defun my/sql--change-editing-mode (mode)
  "Apply MODE preserving file encoding, point, selection and modified state."
  (let ((coding buffer-file-coding-system)
        (modified (buffer-modified-p))
        (position (point))
        (mark-position (mark t))
        (active mark-active))
    (funcall mode)
    (setq buffer-file-coding-system coding)
    (goto-char (min position (point-max)))
    (when mark-position (set-mark mark-position))
    (setq mark-active active deactivate-mark nil)
    (set-buffer-modified-p modified)))

(defun my/sql-use-clutch ()
  "Use Clutch in this SQL file and offer connection, without executing SQL."
  (interactive)
  (unless (derived-mode-p 'sql-mode)
    (user-error "Open a SQL file first"))
  (unless (derived-mode-p 'clutch-mode)
    (require 'clutch)
    (my/sql--change-editing-mode #'clutch-mode))
  (unless (my/clutch-connected-p)
    (my/clutch-connect-file)))

(defun my/clutch-connect-file ()
  "Connect Clutch in this buffer, preserving the editor window and selection."
  (interactive)
  (unless (derived-mode-p 'clutch-mode)
    (user-error "Switch this SQL file to Clutch first"))
  (let ((position (point-marker)) (selected-mark (copy-marker (mark-marker)))
        (active mark-active))
    (unwind-protect
        (save-selected-window
          (call-interactively #'clutch-connect))
      (when (marker-buffer position)
        (with-current-buffer (marker-buffer position)
          (goto-char position)
          (when (marker-position selected-mark) (set-mark selected-mark))
          (setq mark-active active deactivate-mark nil)))
      (set-marker position nil) (set-marker selected-mark nil))))

(defun my/sql-use-standard-mode ()
  "Return to SQL mode, closing a Clutch connection through its normal command."
  (interactive)
  (unless (derived-mode-p 'clutch-mode)
    (user-error "This buffer is not in Clutch mode"))
  ;; Let Clutch handle session/transaction confirmation and derived results
  ;; before the major-mode change clears its buffer-local connection state.
  (when (bound-and-true-p clutch-connection)
    (call-interactively #'clutch-disconnect))
  (my/sql--change-editing-mode #'sql-mode))

(defun my/workspace-menu--sql (_)
  (easy-menu-create-menu
   "SQL"
   (append
    (when (derived-mode-p 'clutch-mode)
      (list (vector (my/clutch-status-label) #'ignore :active nil)
            ["Подключить этот файл…" my/clutch-connect-file :active (not (my/clutch-connected-p))]
            ["Сменить подключение…" my/clutch-connect-file :active (my/clutch-connected-p)]
            ["Отключиться" clutch-disconnect :active (my/clutch-connected-p)]
            "--"
            ["Выполнить выделение" clutch-execute-region
             :active (and (my/clutch-connected-p) (use-region-p))]
            ["Выполнить весь SQL" clutch-execute-buffer :active (my/clutch-connected-p)]))
    '(["Работать через Clutch…" my/sql-use-clutch
      :visible (and (derived-mode-p 'sql-mode) (not (derived-mode-p 'clutch-mode)))]
     ["Вернуться в обычный SQL-режим" my/sql-use-standard-mode
      :active (derived-mode-p 'clutch-mode)]
     ["Открыть iSQL…" sql-connect
      :visible (and (derived-mode-p 'sql-mode) (not (derived-mode-p 'clutch-mode)))]))))

(defun my/workspace-menu--source-p ()
  (derived-mode-p 'python-base-mode))

(defun my/workspace-menu--attached-p ()
  (and (or (my/workspace-menu--source-p)
           (derived-mode-p 'comint-mode))
       (python-workspace--live-p python-workspace--session)))

(defun my/workspace-menu--environments (_)
  "Build the environment submenu when opened, without launching Python."
  (let ((directory (python-workspace--directory)))
    (easy-menu-create-menu
     "Окружение Python"
     (append
      (mapcar
       (lambda (entry)
         (let ((python (cdr entry)))
           (vector (car entry)
                   (lambda () (interactive)
                     (python-workspace-start directory python python-workspace-backend))
                   :help python)))
       (python-workspace-environments directory))
      (list ["Другой интерпретатор…" python-workspace-select-interpreter t])))))

(defun my/workspace-menu--python (_)
  "Build the Python action menu in the buffer where the menu was opened."
  (let ((map (easy-menu-create-menu
              "Python Workspace"
              '(["Запустить / подключиться" python-workspace-start
                 :active (my/workspace-menu--source-p)]
                ["Другая рабочая папка…" python-workspace-start-in-directory
                 :active (my/workspace-menu--source-p)]
                "--"
                ["Выполнить ячейку" python-workspace-run-cell
                 :active (and (my/workspace-menu--source-p) (my/workspace-menu--attached-p))]
                ["Выполнить ячейку и перейти дальше" python-workspace-run-cell-and-step
                 :active (and (my/workspace-menu--source-p) (my/workspace-menu--attached-p))]
                ["Выполнить выделение" python-workspace-send-region
                 :active (and (my/workspace-menu--source-p) (my/workspace-menu--attached-p)
                              (use-region-p))]
                ["Выполнить весь буфер" python-workspace-run-file
                 :active (and (my/workspace-menu--source-p) (my/workspace-menu--attached-p))]
                "--"
                ["Редактор ↔ консоль" python-workspace-switch
                 :active (my/workspace-menu--attached-p)]
                ["Отключить режим в редакторе" python-workspace-mode
                 :active (and (my/workspace-menu--source-p) python-workspace-mode)]
                ["Остановить IPython…" python-workspace-stop
                 :active (my/workspace-menu--attached-p)]))))
    (define-key-after map [environment]
      '(menu-item "Окружение Python" nil
                  :enable (my/workspace-menu--source-p)
                  :filter my/workspace-menu--environments)
      (car (nth 2 map)))
    map))

(defvar my/workspace-menu-map
  (let ((map (make-sparse-keymap "Работа")))
    (define-key-after map [codex]
      '(menu-item "Запустить Codex IDE" codex-ide :enable (commandp 'codex-ide)))
    (define-key-after map [python]
      '(menu-item "Python Workspace" nil :filter my/workspace-menu--python))
    map))

(define-key-after my/workspace-menu-map [sql]
  '(menu-item "SQL" nil :visible (derived-mode-p 'sql-mode)
              :filter my/workspace-menu--sql))

(define-key-after global-map [menu-bar my-workspace]
  (cons "Работа" my/workspace-menu-map))

(defun my/workspace-context-menu (menu _click)
  "Append work commands without replacing standard context-menu entries."
  (when (derived-mode-p 'sql-mode)
    (define-key-after menu [my-sql-editing-mode]
      (if (derived-mode-p 'clutch-mode)
          '(menu-item "Вернуться в обычный SQL-режим" my/sql-use-standard-mode)
        '(menu-item "Работать через Clutch…" my/sql-use-clutch))))
  (define-key-after menu [my-workspace] (cons "Работа" my/workspace-menu-map))
  menu)

(add-hook 'context-menu-functions #'my/workspace-context-menu t)

(provide 'init-workspace-menu)
;;; init-workspace-menu.el ends here
