;;; init-clutch-workspace.el --- Clutch console with a database navigator -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'seq)
(require 'outline)
(require 'subr-x)
(require 'easymenu)

(declare-function treemacs-get-local-window "treemacs-scope" ())
(declare-function treemacs-select-window "treemacs" (&optional arg))
(autoload 'my/clutch-connected-p "init-sql")
(declare-function clutch-query-console "clutch-query" (target))
(declare-function clutch-query-sqlite-file "clutch-query" (file))
(declare-function clutch-db-sqlite-conn-handle "clutch-db-sqlite" (conn))
(declare-function clutch--await-background-request "clutch-connection" (conn))
(declare-function clutch--refuse-while-running "clutch-connection" (conn))
(declare-function clutch--execute "clutch-query" (sql &optional result-context region))
(declare-function clutch-db-backend-key "clutch-backend" (conn))
(declare-function clutch-db-build-paged-sql "clutch-backend"
                  (conn base-sql page-num page-size &optional order-by page-offset))
(declare-function clutch-db-pg--exec "clutch-db-pg" (conn sql))
(declare-function clutch-db-pg--metadata-rows "clutch-db-pg" (result))
(declare-function clutch--browseable-object-entries "clutch-object" (conn &optional refresh))
(declare-function clutch--object-browse-query "clutch-object" (conn entry))
(declare-function clutch-object-describe "clutch-object" (&optional entry))
(defvar clutch-connection-alist)
(defvar clutch-connection)
(defvar clutch--last-result-buffer)
(defvar clutch--source-window)

(cl-defstruct (my/clutch-workspace (:constructor my/clutch-workspace--create))
  console editor previous-buffer sidebar files files-header results placeholder context)

(defvar-local my/clutch-workspace--navigator nil)
(defvar-local my/clutch-workspace--console nil)
(defvar-local my/clutch-workspace--listed-connection nil)

(defun my/clutch-workspace--live-connection (console)
  "Return the live connection owned by CONSOLE."
  (unless (and (buffer-live-p console)
               (with-current-buffer console (my/clutch-connected-p)))
    (user-error "Откройте подключение через «Работа → Clutch»"))
  (buffer-local-value 'clutch-connection console))

(defun my/clutch-workspace--objects (connection)
  "Return table and view entries for CONNECTION."
  (clutch--refuse-while-running connection)
  (clutch--await-background-request connection)
  (clutch--refuse-while-running connection)
  (pcase (clutch-db-backend-key connection)
    ('pg
     ;; The PostgreSQL picker only lists the current schema. Use its
     ;; metadata path so opening the navigator doesn't start a transaction.
     (mapcar
      (lambda (row)
        (list :schema (nth 0 row) :name (nth 1 row) :type (nth 2 row)))
      (clutch-db-pg--metadata-rows
       (clutch-db-pg--exec
        connection
        "SELECT table_schema, table_name,
                 CASE table_type WHEN 'VIEW' THEN 'VIEW' ELSE 'TABLE' END
          FROM information_schema.tables
          WHERE table_schema <> 'information_schema'
            AND left(table_schema, 3) <> 'pg_'
          ORDER BY table_schema, table_name"))))
    ('sqlite
     ;; Clutch's SQLite table listing omits views.
     (mapcar (lambda (row)
               (list :schema "main" :name (car row) :type (cadr row)))
             (sqlite-select (clutch-db-sqlite-conn-handle connection)
                            "SELECT name, upper(type) FROM main.sqlite_schema
                             WHERE type IN ('table', 'view')
                               AND name NOT GLOB 'sqlite_*'")))
    (_
     (seq-filter (lambda (entry) (member (plist-get entry :type) '("TABLE" "VIEW")))
                 (clutch--browseable-object-entries connection t)))))

(defun my/clutch-workspace--schema (entry)
  "Return the navigator group for ENTRY."
  (or (plist-get entry :schema) (plist-get entry :source-schema) "Объекты"))

(defun my/clutch-workspace--entry-at-point ()
  "Return the navigator entry on the current line."
  (get-text-property (line-beginning-position) 'my/clutch-workspace-entry))

(defun my/clutch-workspace-refresh ()
  "Refresh tables and views in the current navigator."
  (interactive)
  (let* ((connection (my/clutch-workspace--live-connection my/clutch-workspace--console))
         (entries (with-current-buffer my/clutch-workspace--console
                    (my/clutch-workspace--objects connection)))
         (groups (seq-group-by #'my/clutch-workspace--schema entries))
         (previous (my/clutch-workspace--entry-at-point))
         (inhibit-read-only t)
         previous-position first-position)
    (unless (eq connection (my/clutch-workspace--live-connection my/clutch-workspace--console))
      (user-error "Подключение сменилось. Нажмите g, чтобы обновить список"))
    (erase-buffer)
    (setq my/clutch-workspace--listed-connection connection)
    (if (null groups)
        (insert "Нет доступных таблиц и представлений.\n")
      (dolist (group (seq-sort-by #'car #'string< groups))
        (insert (propertize (car group) 'face 'font-lock-keyword-face) "\n")
        (dolist (entry (seq-sort-by (lambda (item) (plist-get item :name))
                                    #'string< (cdr group)))
          (let* ((name (plist-get entry :name))
                 (view (equal (plist-get entry :type) "VIEW"))
                 (label (concat "  " name (when view " (вид)"))))
            (unless first-position (setq first-position (point)))
            (when (equal previous entry) (setq previous-position (point)))
            (insert (propertize (concat label "\n")
                                'my/clutch-workspace-entry entry
                                'mouse-face 'highlight
                                'help-echo (concat name " — щелчок: строки, d: колонки")))))
        (insert "\n")))
    (goto-char (or previous-position first-position (point-min)))))

(defun my/clutch-workspace--act (action)
  "Run ACTION for the entry at point in its owning SQL console."
  (let* ((console my/clutch-workspace--console)
         (connection (my/clutch-workspace--live-connection console))
         (entry (or (my/clutch-workspace--entry-at-point)
                    (user-error "Выберите таблицу или представление")))
         (state (my/clutch-workspace--current))
         (editor (and state (my/clutch-workspace-editor state))))
    (unless (eq connection my/clutch-workspace--listed-connection)
      (user-error "Подключение сменилось. Нажмите g, чтобы обновить список"))
    (clutch--refuse-while-running connection)
    (clutch--await-background-request connection)
    (clutch--refuse-while-running connection)
    (unless (eq connection (my/clutch-workspace--live-connection console))
      (user-error "Подключение сменилось. Нажмите g, чтобы обновить список"))
    (unless (and state (eq console (my/clutch-workspace-console state)))
      (user-error "Откройте подключение через «Работа → Clutch»"))
    (setq editor (or (get-buffer-window console)
                     (and (window-live-p editor) editor)
                     (window-main-window)))
    (unless (eq (window-buffer editor) console)
      (with-selected-window editor
        (switch-to-buffer console)))
    (unless (and (eq (my/clutch-workspace-context state) 'console)
                 (eq (my/clutch-workspace-editor state) editor))
      (my/clutch-workspace--activate-editor state editor))
    (with-selected-window editor
      (funcall action connection entry))))

(defun my/clutch-workspace-preview ()
  "Show up to 100 rows of the selected object in Clutch results."
  (interactive)
  (my/clutch-workspace--act
   (lambda (connection entry)
     (clutch--execute
      (clutch-db-build-paged-sql
       connection (clutch--object-browse-query connection entry) 0 100)))))

(defun my/clutch-workspace-preview-mouse (event)
  "Preview the database object clicked in EVENT."
  (interactive "e")
  (mouse-set-point event)
  (my/clutch-workspace-visit))

(defun my/clutch-workspace-visit ()
  "Preview the object at point or fold the current schema."
  (interactive)
  (cond
   ((my/clutch-workspace--entry-at-point) (my/clutch-workspace-preview))
   ((outline-on-heading-p) (outline-toggle-children))))

(defun my/clutch-workspace-describe ()
  "Show columns and types for the selected object."
  (interactive)
  (my/clutch-workspace--act
   (lambda (_connection entry)
     (let* ((state (my/clutch-workspace--current))
            (display-buffer-overriding-action
             (list (lambda (buffer _alist)
                     (my/clutch-workspace--put-result state buffer)))))
       (clutch-object-describe entry)))))

(defvar my/clutch-workspace-navigator-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "RET") #'my/clutch-workspace-visit)
    (define-key map (kbd "TAB") #'my/clutch-workspace-visit)
    (define-key map [mouse-1] #'my/clutch-workspace-preview-mouse)
    (define-key map [mouse-2] #'my/clutch-workspace-preview-mouse)
    (define-key map (kbd "d") #'my/clutch-workspace-describe)
    (define-key map (kbd "g") #'my/clutch-workspace-refresh)
    map))

(define-derived-mode my/clutch-workspace-navigator-mode special-mode "Clutch DB"
  "Navigate tables and views for a Clutch SQL console."
  (setq-local truncate-lines t
              outline-regexp "[^ \t\n]"
              header-line-format '(:eval (my/clutch-workspace--tabs 'objects))))

(easy-menu-define my/clutch-workspace-navigator-menu
  my/clutch-workspace-navigator-mode-map "Database navigator actions."
  '("Таблицы"
    ["Показать первые 100 строк" my/clutch-workspace-preview
     :active (my/clutch-workspace--entry-at-point)]
    ["Показать колонки и типы" my/clutch-workspace-describe
     :active (my/clutch-workspace--entry-at-point)]
    ["Обновить список" my/clutch-workspace-refresh t]))

(defun my/clutch-workspace--current (&optional frame)
  "Return the Clutch workspace for FRAME."
  (frame-parameter frame 'my/clutch-workspace))

(defun my/clutch-workspace--tab (label tab active)
  "Format a clickable tab with LABEL for TAB, highlighting ACTIVE."
  (let ((map (make-sparse-keymap)))
    (define-key map [header-line mouse-1]
      (lambda (event)
        (interactive "e")
        (with-selected-window (posn-window (event-start event))
          (when-let* ((state (my/clutch-workspace--current)))
            (my/clutch-workspace--show-tab state tab)))))
    (propertize (format " %s " label)
                'face (if active 'mode-line-emphasis 'shadow)
                'mouse-face 'highlight 'local-map map)))

(defun my/clutch-workspace--tabs (active)
  "Format the sidebar tabs with ACTIVE selected."
  (list (my/clutch-workspace--tab "Файлы" 'files (eq active 'files))
        " │ "
        (my/clutch-workspace--tab "Объекты базы" 'objects (eq active 'objects))))

(defun my/clutch-workspace--restore-header (state)
  "Restore the original header of STATE's Treemacs buffer."
  (when (buffer-live-p (my/clutch-workspace-files state))
    (with-current-buffer (my/clutch-workspace-files state)
      (let ((header (my/clutch-workspace-files-header state)))
        (if (car header)
            (setq header-line-format (cdr header))
          (kill-local-variable 'header-line-format))))))

(defun my/clutch-workspace--show-tab (state tab)
  "Display TAB in STATE's Treemacs window."
  (let ((sidebar (or (treemacs-get-local-window)
                     (my/clutch-workspace-sidebar state))))
    (unless (window-live-p sidebar)
      (save-selected-window
        (treemacs-select-window)
        (setq sidebar (treemacs-get-local-window))))
    (setf (my/clutch-workspace-sidebar state) sidebar)
    (unless (window-live-p sidebar)
      (user-error "Окно Treemacs недоступно"))
    (let ((visible (window-buffer sidebar)))
      (when (and (with-current-buffer visible (derived-mode-p 'treemacs-mode))
                 (not (eq visible (my/clutch-workspace-files state))))
        (my/clutch-workspace--restore-header state)
        (setf (my/clutch-workspace-files state) visible)
        (with-current-buffer visible
          (setf (my/clutch-workspace-files-header state)
                (cons (local-variable-p 'header-line-format) header-line-format))
          (setq-local header-line-format
                      '(:eval (my/clutch-workspace--tabs 'files)))))
      (let* ((console (my/clutch-workspace-console state))
             (target (if (eq tab 'files)
                         (my/clutch-workspace-files state)
                       (and (buffer-live-p console)
                            (buffer-local-value 'my/clutch-workspace--navigator console)))))
        (when (and (buffer-live-p target) (not (eq visible target)))
          (let ((dedicated (window-dedicated-p sidebar)))
            (unwind-protect
                (progn
                  (set-window-dedicated-p sidebar nil)
                  (set-window-buffer sidebar target t))
              (set-window-dedicated-p sidebar dedicated))))))))

(defun my/clutch-workspace--treemacs-command (&rest _)
  "Expose the files tab before an explicit Treemacs command."
  (when-let* ((state (my/clutch-workspace--current))
              (sidebar (my/clutch-workspace-sidebar state)))
    (when (and (window-live-p sidebar)
               (not (treemacs-get-local-window)))
      (my/clutch-workspace--show-tab state 'files))))

(defun my/clutch-workspace--result-window (state)
  "Return STATE's result window while it shows a workspace buffer."
  (let ((window (my/clutch-workspace-results state)))
    (when (and (window-live-p window)
               (with-current-buffer (window-buffer window)
                 (or (eq (current-buffer) (my/clutch-workspace-placeholder state))
                     (derived-mode-p 'clutch-result-mode 'clutch-describe-mode))))
      window)))

(defun my/clutch-workspace--hide-results (state)
  "Hide STATE's result pane if it still displays a workspace buffer."
  (when-let* ((window (my/clutch-workspace--result-window state)))
    (unless (one-window-p t (window-frame window))
      (delete-window window)))
  (setf (my/clutch-workspace-results state) nil))

(defun my/clutch-workspace--put-result (state buffer)
  "Display BUFFER just below STATE's SQL editor and return its window."
  (let* ((editor (my/clutch-workspace-editor state))
         (window (or (my/clutch-workspace--result-window state)
                     (and (window-live-p editor)
                          (ignore-error error
                            (split-window editor
                                          (- (max window-min-height
                                                  (/ (window-total-height editor) 3)))
                                          'below))))))
    (when window
      (setf (my/clutch-workspace-results state) window)
      (set-window-buffer window buffer)
      window)))

(defun my/clutch-workspace--activate-editor (state editor)
  "Show STATE's objects and results for the SQL console in EDITOR."
  (unless (eq (my/clutch-workspace-editor state) editor)
    (my/clutch-workspace--hide-results state))
  (setf (my/clutch-workspace-editor state) editor
        (my/clutch-workspace-context state) 'console)
  (my/clutch-workspace--show-tab state 'objects)
  (let* ((console (my/clutch-workspace-console state))
         (result (buffer-local-value 'clutch--last-result-buffer console)))
    (my/clutch-workspace--put-result
     state (if (and (buffer-live-p result)
                    (eq (buffer-local-value 'clutch-connection result)
                        (buffer-local-value 'clutch-connection console)))
               result
             (my/clutch-workspace-placeholder state)))))

(defun my/clutch-workspace--show-result (original buffer)
  "Send Clutch's BUFFER to the workspace pane when it belongs there."
  (let* ((source (or (and (window-live-p clutch--source-window)
                          (window-buffer clutch--source-window))
                     (current-buffer)))
         (frame (if (window-live-p clutch--source-window)
                    (window-frame clutch--source-window)
                  (selected-frame)))
         (state (my/clutch-workspace--current frame)))
    (cond
     ((and state (eq source (my/clutch-workspace-console state)))
      (let ((editor (my/clutch-workspace-editor state)))
        (when (and (eq (my/clutch-workspace-context state) 'console)
                   (window-live-p editor)
                   (eq (window-buffer editor) source))
          (my/clutch-workspace--put-result state buffer))))
     ;; A delayed reply for a console hidden by file navigation should not
     ;; open a pane over the file. Clutch retains the rendered result.
     ((and (buffer-local-value 'my/clutch-workspace--navigator source)
           (not (get-buffer-window source frame))))
     (t (funcall original buffer)))))

(defun my/clutch-workspace--sync ()
  "Follow changes between the SQL console and other editor buffers."
  (when-let* ((state (my/clutch-workspace--current)))
    (let ((console (my/clutch-workspace-console state))
          (window (selected-window)))
      (cond
       ((not (and (buffer-live-p console)
                  (with-current-buffer console
                    (and (derived-mode-p 'clutch-mode) clutch-connection))))
        (my/clutch-workspace-close))
       ((eq (window-buffer window) console)
        (unless (and (eq (my/clutch-workspace-context state) 'console)
                     (eq (my/clutch-workspace-editor state) window))
          (my/clutch-workspace--activate-editor state window)))
       ((and (not (window-minibuffer-p window))
             (not (eq window (my/clutch-workspace-sidebar state)))
             (not (eq window (my/clutch-workspace--result-window state)))
             (not (with-current-buffer (window-buffer window)
                    (derived-mode-p 'treemacs-mode 'clutch-result-mode
                                    'clutch-describe-mode 'clutch-record-mode
                                    'clutch-plan-mode)))
             (not (eq (my/clutch-workspace-context state) 'files)))
        (setf (my/clutch-workspace-context state) 'files)
        (my/clutch-workspace--show-tab state 'files)
        (my/clutch-workspace--hide-results state))))))

(defun my/clutch-workspace-close ()
  "Return to Treemacs and close the results pane."
  (interactive)
  (when-let* ((state (my/clutch-workspace--current)))
    (set-frame-parameter nil 'my/clutch-workspace nil)
    (my/clutch-workspace--hide-results state)
    (when (window-live-p (my/clutch-workspace-sidebar state))
      (my/clutch-workspace--show-tab state 'files))
    (my/clutch-workspace--restore-header state)
    (let ((editor (my/clutch-workspace-editor state))
          (previous (my/clutch-workspace-previous-buffer state)))
      (when (and (window-live-p editor)
                 (eq (window-buffer editor) (my/clutch-workspace-console state)))
        (set-window-buffer editor
                           (if (buffer-live-p previous) previous (other-buffer)))))
    (kill-buffer (my/clutch-workspace-placeholder state))))

(defun my/clutch-workspace--kill-navigator ()
  "Close workspaces using the current console and kill its navigator."
  (let ((console (current-buffer))
        (navigator my/clutch-workspace--navigator))
    (dolist (frame (frame-list))
      (when-let* ((state (my/clutch-workspace--current frame)))
        (when (eq console (my/clutch-workspace-console state))
          (with-selected-frame frame (my/clutch-workspace-close)))))
    (when (buffer-live-p navigator)
      (kill-buffer navigator))))

(defun my/clutch-workspace-open (name)
  "Open a workspace for the saved Clutch connection NAME."
  (interactive
   (list (completing-read "Подключение Clutch: " clutch-connection-alist nil t)))
  (my/clutch-workspace--open #'clutch-query-console name name))

(defun my/clutch-workspace-open-sqlite (file)
  "Open SQLite FILE in the Clutch workspace."
  (let ((file (file-truename file)))
    (unless (file-regular-p file)
      (user-error "Файл базы данных недоступен: %s" file))
    (my/clutch-workspace--open #'clutch-query-sqlite-file file
                               (abbreviate-file-name file))))

(defun my/clutch-workspace--open (open-console target name)
  "Open TARGET with OPEN-CONSOLE and display its workspace under NAME."
  (require 'clutch)
  (require 'treemacs)
  (let* ((state (my/clutch-workspace--current))
         (workspace-editor (and state (my/clutch-workspace-editor state)))
         (editor (if (or (eq (selected-window) (treemacs-get-local-window))
                         (window-parameter nil 'window-side)
                         (and state (eq (selected-window)
                                        (my/clutch-workspace-results state))))
                     (or (and (window-live-p workspace-editor) workspace-editor)
                         (get-largest-window)
                         (user-error "Нет доступного окна для SQL-консоли"))
                   (selected-window)))
         (previous (window-buffer editor)))
    (select-window editor)
    (funcall open-console target)
    (setq editor (selected-window))
    (unless (my/clutch-connected-p)
      (user-error "Clutch не подключён"))
    (let ((console (current-buffer)))
      (unless (buffer-live-p my/clutch-workspace--navigator)
        (setq-local my/clutch-workspace--navigator
                    (generate-new-buffer (format "*Clutch: таблицы — %s*" name)))
        (add-hook 'kill-buffer-hook #'my/clutch-workspace--kill-navigator nil t)
        (add-hook 'change-major-mode-hook #'my/clutch-workspace--kill-navigator nil t)
        (with-current-buffer my/clutch-workspace--navigator
          (my/clutch-workspace-navigator-mode)
          (setq-local my/clutch-workspace--console console)))
      (with-current-buffer my/clutch-workspace--navigator
        (my/clutch-workspace-refresh))
      (unless state
        (let ((placeholder (generate-new-buffer " *Clutch: результаты*")))
          (with-current-buffer placeholder
            (insert "Здесь появятся результаты запросов и просмотра таблиц.\n")
            (special-mode))
          (setq state (my/clutch-workspace--create
                       :previous-buffer (unless (eq previous console) previous)
                       :placeholder placeholder))
          (set-frame-parameter nil 'my/clutch-workspace state)))
      (setf (my/clutch-workspace-console state) console)
      (my/clutch-workspace--activate-editor state editor))))

(add-hook 'post-command-hook #'my/clutch-workspace--sync)
(with-eval-after-load 'treemacs
  (advice-add 'treemacs :before #'my/clutch-workspace--treemacs-command)
  (advice-add 'treemacs-select-window :before #'my/clutch-workspace--treemacs-command))
(with-eval-after-load 'clutch-result
  (advice-add 'clutch-result--show-buffer :around #'my/clutch-workspace--show-result))

(provide 'init-clutch-workspace)
;;; init-clutch-workspace.el ends here
