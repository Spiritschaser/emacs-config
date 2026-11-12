;;; init-python-workspace.el --- Persistent IPython workspace -*- lexical-binding: t; -*-

;; Stage B: code-cells + dREPL, with python.el as an explicit fallback.
;; No automatic notebook conversion, execution, or synchronization on save.

(require 'cl-lib)
(require 'python)
(require 'project)
(require 'comint-mime)
(require 'code-cells)

(defgroup python-workspace nil "Persistent IPython workspace." :group 'python)
(defcustom python-workspace-backend 'drepl
  "REPL for new sessions.  Existing sessions retain their backend."
  :type '(choice (const drepl) (const python)))
(defcustom python-workspace-startup-timeout 20
  "Maximum seconds to wait for startup; evaluation itself is asynchronous."
  :type 'number)
(defconst python-workspace--setup-file
  (expand-file-name "python-workspace-setup.py"
                    (file-name-directory (or load-file-name buffer-file-name))))
(cl-defstruct (python-workspace--session (:constructor python-workspace--new))
  directory python backend buffer editor)
(defvar python-workspace--sessions nil)
(defvar-local python-workspace--session nil)
(defvar-local python-workspace--saved-locals nil)
(defvar-local python-workspace--owned-cells nil)
(defvar python-workspace--python-choice nil)
(defvar python-workspace--environment-choices nil
  "Directory to (PYTHON . BACKEND) choices for this Emacs session.")

;; The package adds this destructive conversion through its autoloads too.
;; Normal .ipynb opening must remain a JSON/text operation until stage C.
(setq auto-mode-alist
      (cl-remove-if (lambda (entry)
                      (eq (cdr entry) 'code-cells-convert-ipynb))
                    auto-mode-alist))

(defun python-workspace--live-p (session)
  (and session (buffer-live-p (python-workspace--session-buffer session))
       (comint-check-proc (python-workspace--session-buffer session))))

(defun python-workspace--wait (buffer predicate)
  "Wait a bounded time for PREDICATE in BUFFER during startup only."
  (let ((deadline (+ (float-time) python-workspace-startup-timeout)))
    (with-current-buffer buffer
      (while (and (comint-check-proc buffer) (not (funcall predicate))
                  (< (float-time) deadline))
        (accept-process-output (get-buffer-process buffer) 0.05))
      (unless (and (comint-check-proc buffer) (funcall predicate))
        (error "IPython startup timed out in %s: %s" (buffer-name buffer)
               (buffer-substring-no-properties
                (max (point-min) (- (point-max) 2000)) (point-max)))))))

(defun python-workspace--trim-output (_)
  "Keep completed console output bounded, including very long lines."
  (let* ((proc (get-buffer-process (current-buffer)))
         (end (and proc (marker-position (process-mark proc))))
         (excess (- (buffer-size) 500000)))
    (when (and end (> excess 0))
      (let ((inhibit-read-only t))
        (delete-region (point-min) (min (+ (point-min) excess) end))))))

(defun python-workspace--configure-console (session)
  (setq-local python-workspace--session session
              ansi-osc-handlers (copy-tree ansi-osc-handlers)
              comint-mime-renderer-alist (copy-tree comint-mime-renderer-alist)
              comint-mime-use-vtable t
              shr-inhibit-images t
              shr-use-fonts nil
              comint-mime-image-props '(:max-width 1000 :max-height 750)
              comint-buffer-maximum-size 3000)
  (add-hook 'comint-output-filter-functions #'comint-truncate-buffer t t)
  (add-hook 'comint-output-filter-functions #'python-workspace--trim-output t t)
  ;; `local-set-key' otherwise mutates the shared major-mode keymap.
  (use-local-map (copy-keymap (current-local-map)))
  (local-set-key (kbd "C-c %") python-workspace-prefix-map)
  (when (fboundp 'evil-local-set-key)
    (dolist (state '(normal insert visual))
      (evil-local-set-key state (kbd "C-c %") python-workspace-prefix-map))
    ;; Evil's insert-state RET takes precedence over Comint's remapping.
    (evil-local-set-key 'insert (kbd "RET")
                        (if (derived-mode-p 'drepl-mode)
                            #'drepl-send-input-maybe
                          #'comint-send-input)))
  (when (fboundp 'evil-insert-state) (evil-insert-state)))

(defun python-workspace--mime-osc (command text)
  "Handle package MIME messages, decoding escaped Windows file URIs.
comint-mime 0.7 leaves percent escapes in filenames.  Normalize only
the URI payload; all protocol decoding and rendering stay in the package."
  (let* ((newline (string-match "\n" text))
         (payload (and newline (string-trim (substring text (1+ newline))))))
    (if (and payload (string-match-p "\\`\\(?:tmp\\)?file:" payload))
        (comint-mime-osc-handler
         command (concat (substring text 0 (1+ newline))
                         (decode-coding-string (url-unhex-string payload) 'utf-8)))
      (if (> (string-bytes text) (* 3 1024 1024))
          (insert "[Workspace: oversized MIME message omitted]\n")
        (comint-mime-osc-handler command text)))))

(defun python-workspace--install-mime-handler (buffer)
  (with-current-buffer buffer
    (setq-local ansi-osc-handlers
                (cons '("5151" . python-workspace--mime-osc)
                      (cl-remove-if (lambda (entry) (equal (car entry) "5151"))
                                    ansi-osc-handlers)))))

(defun python-workspace--echo-input (code)
  "Display source CODE at the console prompt, preserving pending input."
  (comint-output-filter (get-buffer-process (current-buffer))
                        (concat code (unless (string-suffix-p "\n" code) "\n")))
  ;; dREPL otherwise inserts a newline at the old prompt, before the code.
  (setq comint-last-prompt nil))

(defun python-workspace--send (session code &optional echo)
  "Send CODE to SESSION, using its existing process.
When ECHO is non-nil, display the source code before its output."
  (let ((buffer (python-workspace--session-buffer session)))
    (unless (python-workspace--live-p session)
      (user-error "Workspace stopped; run M-x python-workspace-start"))
    (with-current-buffer buffer
      (if (eq (python-workspace--session-backend session) 'drepl)
          (progn
            ;; Avoid unbounded queues and accidental input into input()/pdb.
            (unless (eq (drepl--status drepl--current) 'ready)
              (user-error "IPython is busy; finish or interrupt it in the console"))
            (when echo (python-workspace--echo-input code))
            (drepl-eval code))
        (unless (python-shell-comint-end-of-output-p
                 (buffer-substring-no-properties
                  (max (point-min) (- (point-max) 200)) (point-max)))
          (user-error "IPython is busy; finish or interrupt it in the console"))
        (when echo (python-workspace--echo-input code))
        ;; Assignment suppresses the outer ExecutionResult, preserving rich
        ;; display of the actual cell and IPython line/cell magics.
        (python-shell-send-string
         (format "_emacs_workspace_result = get_ipython().run_cell(%s, store_history=True)"
                 (json-serialize code))
         (get-buffer-process buffer))))))

(defun python-workspace--create (directory python backend)
  "Create one process for DIRECTORY, PYTHON and BACKEND."
  (let* ((name (format "IPython Workspace:%s:%s"
                       (file-name-nondirectory (directory-file-name directory))
                       (substring (secure-hash 'sha1 (prin1-to-string
                                                     (list directory python backend))) 0 8)))
         (buffer (get-buffer-create (format "*%s*" name)))
         (session (python-workspace--new :directory directory :python python
                                         :backend backend :buffer buffer))
         (default-directory directory)
         (process-environment (copy-sequence process-environment))
         (exec-path (cons (file-name-directory python) exec-path))
         (process-connection-type nil)
         (coding-system-for-read 'utf-8-unix)
         (coding-system-for-write 'utf-8-unix))
    (setenv "PYTHONUTF8" "1")
    (setenv "PYTHONUNBUFFERED" "1")
    (setenv "PATH" (concat (file-name-directory python) path-separator (getenv "PATH")))
    (when (file-exists-p (expand-file-name "../pyvenv.cfg" (file-name-directory python)))
      (setenv "VIRTUAL_ENV" (directory-file-name
                             (expand-file-name ".." (file-name-directory python)))))
    (condition-case err
        (progn
          (if (eq backend 'drepl)
              (progn
                (require 'drepl-ipython)
                (with-current-buffer buffer
                  (setq default-directory directory)
                  (drepl-mode)
                  (python-workspace--configure-console session)
                  (let ((python-interpreter python)
                        (drepl-ipython-config '(InlineBackend.figure_formats ["png"])))
                    (setq drepl--current (drepl-ipython--create :buffer buffer))
                    (drepl--init drepl--current)))
                (python-workspace--wait buffer
                 (lambda () (eq (drepl--status drepl--current) 'ready))))
            (let ((python-shell-interpreter python)
                  (python-shell-interpreter-args
                   "-m IPython --simple-prompt --no-autoindent --colors=NoColor --HistoryManager.enabled=False")
                  (python-shell-completion-native-enable nil))
              (python-shell-make-comint (python-shell-calculate-command) name)
              (with-current-buffer buffer
                (python-workspace--configure-console session))
              (python-workspace--wait buffer (lambda () python-shell--first-prompt-received))
              (with-current-buffer buffer (comint-mime-setup))))
          (python-workspace--install-mime-handler buffer)
          (python-workspace--send
           session (format "exec(compile(__import__('pathlib').Path(%s).read_text(encoding='utf-8'), %s, 'exec'))"
                           (json-serialize python-workspace--setup-file)
                           (json-serialize python-workspace--setup-file)))
          (python-workspace--wait
           buffer (if (eq backend 'drepl)
                      (lambda () (eq (drepl--status drepl--current) 'ready))
                    (lambda () (python-shell-comint-end-of-output-p
                                (buffer-substring-no-properties (point-min) (point-max))))))
          (push session python-workspace--sessions)
          session)
      (error
       (when-let* ((proc (get-buffer-process buffer)))
         (set-process-query-on-exit-flag proc nil) (delete-process proc))
       (signal (car err) (cdr err))))))

(defun python-workspace--default-python (directory)
  (or (cl-loop for root in (list (getenv "VIRTUAL_ENV")
                                 (and (boundp 'python-shell-virtualenv-root)
                                      python-shell-virtualenv-root)
                                 (expand-file-name ".venv" directory)
                                 (expand-file-name "venv" directory))
               when root
               thereis (cl-find-if #'file-executable-p
                        (mapcar (lambda (suffix) (expand-file-name suffix root))
                                '("Scripts/python.exe" "bin/python"))))
      (executable-find python-shell-interpreter)
      (executable-find "python")
      (user-error "Select an installed Python interpreter")))

(defun python-workspace--current ()
  (unless (python-workspace--live-p python-workspace--session)
    (user-error "Run M-x python-workspace-start in a Python buffer first"))
  python-workspace--session)

(defun python-workspace--directory ()
  "Current source directory, normalized for environment lookup."
  (when (file-remote-p default-directory)
    (user-error "Workspace requires a local directory"))
  (file-name-as-directory (file-truename default-directory)))

(defun python-workspace-environments (directory)
  "Return named existing Python executables for DIRECTORY, without starting any."
  (let* ((venv (cl-find-if
                (lambda (path) (and (file-regular-p path) (file-executable-p path)))
                (mapcar (lambda (suffix) (expand-file-name suffix directory))
                        '(".venv/Scripts/python.exe" ".venv/bin/python"))))
         (system (or (executable-find python-shell-interpreter)
                     (executable-find "python")
                     (executable-find "python3"))))
    (append (when venv (list (cons ".venv текущей папки" venv)))
            (when (and system (not (and venv (file-equal-p system venv))))
              (list (cons "Системный Python" system))))))

(defun python-workspace--choose-python (directory)
  "Choose a discovered environment using a native popup, or completion in a TTY."
  (let* ((choices (append (python-workspace-environments directory)
                          '(("Другой интерпретатор…" . other))))
         (selected
          (if (display-graphic-p)
              (x-popup-menu t (list "Python Workspace"
                                   (cons "Выберите окружение" choices)))
            (cdr (assoc (completing-read "Python: " choices nil t) choices)))))
    (unless selected (keyboard-quit))
    (if (eq selected 'other)
        (read-file-name "Python executable: " directory
                        (ignore-errors (python-workspace--default-python directory))
                        t nil #'file-executable-p)
      selected)))

(defun python-workspace--start-arguments (&optional choose)
  "Reuse the current/remembered environment unless CHOOSE is non-nil."
  (unless (derived-mode-p 'python-base-mode)
    (user-error "Start a workspace from a Python source buffer"))
  (let* ((current (and (not choose) (python-workspace--live-p python-workspace--session)
                       python-workspace--session))
         (directory (if current (python-workspace--session-directory current)
                      (python-workspace--directory)))
         (remembered (cdr (assoc directory python-workspace--environment-choices)))
         (live (cl-remove-if-not
                (lambda (session)
                  (and (python-workspace--live-p session)
                       (equal directory (python-workspace--session-directory session))))
                python-workspace--sessions))
         (reuse (or current (and (not choose) (not remembered) (= (length live) 1)
                                  (car live)))))
    (cond
     (reuse (list directory (python-workspace--session-python reuse)
                  (python-workspace--session-backend reuse)))
     ((and (not choose) remembered (file-executable-p (car remembered)))
      (list directory (car remembered) (cdr remembered)))
     (t (list directory (python-workspace--choose-python directory)
              (if choose
                  (intern (completing-read "Backend: " '("drepl" "python") nil t nil nil
                                           (symbol-name python-workspace-backend)))
                python-workspace-backend))))))

(defun python-workspace-change-environment ()
  "Choose the environment for the current directory; keep other sessions alive."
  (interactive)
  (unless (derived-mode-p 'python-base-mode)
    (user-error "Choose an environment from a Python source buffer"))
  (let ((directory (python-workspace--directory)))
    (python-workspace-start directory (python-workspace--choose-python directory)
                            python-workspace-backend)))

(defun python-workspace-select-interpreter (python)
  "Select a custom PYTHON executable directly from a file chooser."
  (interactive
   (list (read-file-name "Python executable: " default-directory
                         (ignore-errors (python-workspace--default-python default-directory))
                         t nil #'file-executable-p)))
  (python-workspace-start (python-workspace--directory) python python-workspace-backend))

(defun python-workspace-start-in-directory (directory)
  "Choose another workspace DIRECTORY and its interpreter explicitly."
  (interactive (list (read-directory-name "Workspace directory: " nil nil t)))
  (unless (derived-mode-p 'python-base-mode)
    (user-error "Start a workspace from a Python source buffer"))
  (python-workspace-start directory (python-workspace--choose-python directory)
                          python-workspace-backend))

;;;###autoload
(defun python-workspace-start (directory python &optional backend)
  "Start or reuse persistent IPython in the current source directory.
Interactively, reuse an associated or remembered environment, otherwise
offer .venv and system Python in a native menu.  Choices last until Emacs exits.
From Lisp, use DIRECTORY and PYTHON explicitly.
PYTHON is an executable, including .venv/Scripts/python.exe on Windows.
With a prefix argument choose the environment and BACKEND again."
  (interactive (python-workspace--start-arguments current-prefix-arg))
  (unless (derived-mode-p 'python-base-mode)
    (user-error "Start a workspace from a Python source buffer"))
  (setq directory (file-name-as-directory (file-truename directory))
        python (file-truename python)
        backend (or backend python-workspace-backend))
  (unless (and (file-directory-p directory) (file-executable-p python)
               (memq backend '(drepl python)))
    (user-error "Invalid directory, Python executable, or backend"))
  (unless (and (file-exists-p python-workspace--setup-file)
               (not (file-remote-p directory)))
    (user-error "Workspace requires local files and python-workspace-setup.py"))
  (let ((session (cl-find-if
                  (lambda (s)
                    (and (python-workspace--live-p s)
                         (equal directory (python-workspace--session-directory s))
                         (equal python (python-workspace--session-python s))
                         (eq backend (python-workspace--session-backend s))))
                  python-workspace--sessions)))
    (unless session (setq session (python-workspace--create directory python backend)))
    (setf (alist-get directory python-workspace--environment-choices nil nil #'equal)
          (cons python backend))
    (setq python-workspace--session session)
    (setf (python-workspace--session-editor session) (current-buffer))
    (python-workspace-mode 1)
    (python-workspace--display session)
    (message "IPython workspace: %s; %s; %s" directory python backend)
    session))

(defun python-workspace--display (session)
  (display-buffer (python-workspace--session-buffer session)
                  '((display-buffer-reuse-window display-buffer-at-bottom)
                    (window-height . 0.32) (inhibit-same-window . t))))

(defun python-workspace-switch ()
  "Switch between the source buffer and its persistent console."
  (interactive)
  (let ((session (python-workspace--current)))
    (if (eq (current-buffer) (python-workspace--session-buffer session))
        (if (buffer-live-p (python-workspace--session-editor session))
            (pop-to-buffer (python-workspace--session-editor session))
          (user-error "The source buffer has been closed"))
      (setf (python-workspace--session-editor session) (current-buffer))
      (select-window (python-workspace--display session)))))

(defun python-workspace-send-region (start end)
  "Execute selected code from START to END in the associated process."
  (interactive "r")
  (let ((session (python-workspace--current)))
    (python-workspace--send session (buffer-substring-no-properties start end) t)
    (python-workspace--display session)))

(defun python-workspace-run-cell ()
  "Execute the cell at point, even if a region is active."
  (interactive)
  (pcase-let ((`(,start ,end) (code-cells--bounds 1 nil t)))
    (python-workspace-send-region start end)))

(defun python-workspace-run-cell-and-step ()
  "Execute the current cell and move to the next cell."
  (interactive)
  (python-workspace-run-cell)
  (code-cells-forward-cell))

(defun python-workspace-run-file ()
  "Execute the entire source buffer, including unsaved edits, in IPython.
The source buffer's directory does not change the workspace directory."
  (interactive)
  (python-workspace-send-region (point-min) (point-max)))

(defun python-workspace-stop ()
  "Explicitly terminate this workspace process after confirmation.
All buffers associated with that workspace are detached."
  (interactive)
  (let* ((session (python-workspace--current))
         (buffer (python-workspace--session-buffer session)))
    (when (yes-or-no-p "Stop IPython and discard its variables? ")
      (let ((proc (get-buffer-process buffer)))
        (set-process-query-on-exit-flag proc nil) (delete-process proc))
      (dolist (source (buffer-list))
        (with-current-buffer source
          (when (eq python-workspace--session session)
            (when python-workspace-mode (python-workspace-mode -1))
            (setq python-workspace--session nil))))
      (setq python-workspace--sessions (delq session python-workspace--sessions))
      (quit-windows-on buffer))))

(defvar python-workspace-prefix-map
  (let ((map (make-sparse-keymap)))
    (dolist (entry '(("e" . python-workspace-run-cell)
                     ("s" . python-workspace-run-cell-and-step)
                     ("r" . python-workspace-send-region)
                     ("b" . python-workspace-run-file)
                     ("p" . code-cells-backward-cell)
                     ("n" . code-cells-forward-cell)
                     ("z" . python-workspace-switch)
                     ("o" . python-workspace-start)
                     ("q" . python-workspace-mode)
                     ("k" . python-workspace-stop)))
      (define-key map (kbd (car entry)) (cdr entry)))
    map))

;;;###autoload
(define-minor-mode python-workspace-mode
  "Enable local cell editing and workspace commands without starting Python.
Disabling detaches this buffer; it retains the process and its variables.
Use `python-workspace-stop' to explicitly discard the session."
  :lighter " PyWS"
  :keymap (let ((map (make-sparse-keymap)))
            (define-key map (kbd "C-c %") python-workspace-prefix-map) map)
  (if python-workspace-mode
      (if (not (derived-mode-p 'python-base-mode))
          (progn (setq python-workspace-mode nil)
                 (user-error "Python source buffers only"))
        (unless python-workspace--saved-locals
          (setq python-workspace--saved-locals
                (mapcar (lambda (var) (list var (local-variable-p var) (symbol-value var)))
                        '(code-cells-eval-region-commands))))
        (unless (bound-and-true-p code-cells-mode)
          (setq python-workspace--owned-cells t)
          (code-cells-mode 1))
        (setq-local code-cells-eval-region-commands
                    '((python-workspace-mode . python-workspace-send-region))))
    (dolist (entry python-workspace--saved-locals)
      (if (cadr entry) (set (car entry) (caddr entry))
        (kill-local-variable (car entry))))
    (setq python-workspace--saved-locals nil)
    (when python-workspace--owned-cells
      (code-cells-mode -1) (setq python-workspace--owned-cells nil))
    (setq python-workspace--session nil)))

(with-eval-after-load 'evil
  ;; Auxiliary minor-mode maps; Evil's global and major-mode maps stay intact.
  (dolist (state '(normal insert visual))
    (evil-define-key state python-workspace-mode-map
      (kbd "C-c %") python-workspace-prefix-map)))

(provide 'init-python-workspace)
;;; init-python-workspace.el ends here
