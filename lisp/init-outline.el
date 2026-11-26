;;; init-outline.el --- Imenu outline sidebar -*- lexical-binding: t; -*-

(require 'imenu)
(require 'rx)
(require 'subr-x)

(defconst my/python-notebook-cell-regexp
  (rx bol "#" (* blank) "%%" (or (seq (+ blank) (group (* nonl))) eol)))

(defconst my/python-notebook-heading-regexp
  (rx bol "#" (+ blank) (group (repeat 1 6 "#")) (+ blank) (group (+ nonl))))

(defvar-local my/python-notebook-imenu-cache nil)

(defun my/python-notebook-cell-label (end)
  "Find the first nonempty line of the cell ending at END."
  (save-excursion
    (let (label)
      (while (and (not label) (< (point) end))
        (let ((line (string-trim (buffer-substring-no-properties
                                  (point) (line-end-position)))))
          (setq line (string-trim (string-remove-prefix "#" line)))
          (unless (string-empty-p line)
            (setq label line)))
        (forward-line 1))
      label)))

(defun my/python-notebook-index ()
  "Return a cell and Markdown section tree for a Python percent notebook."
  (save-excursion
    (save-restriction
      (widen)
      (goto-char (point-min))
      (let (cells)
        (while (re-search-forward my/python-notebook-cell-regexp nil t)
          (let ((start (match-beginning 0))
                (header (or (match-string-no-properties 1) "")))
            (unless (save-excursion (nth 3 (syntax-ppss start)))
              (push (cons start (string-trim header)) cells))))
        (when cells
          (let* ((root (list (if buffer-file-name
                                 (file-name-nondirectory buffer-file-name)
                               (buffer-name))))
                 (sections (list (cons 0 root)))
                 (number 0))
            (setq cells (nreverse cells))
            (goto-char (point-min))
            (when-let* ((label (my/python-notebook-cell-label (caar cells))))
              (push (cons (truncate-string-to-width label 72 nil nil "…") (point-marker))
                    (cdr root)))
            (while cells
              (let* ((cell (pop cells))
                     (end (if cells (caar cells) (point-max)))
                     (markdown (string-match-p (rx bos "[markdown]" (or blank eos))
                                               (cdr cell)))
                     (title (if markdown
                                (string-trim (string-remove-prefix "[markdown]" (cdr cell)))
                              (cdr cell)))
                     (has-heading nil))
                (setq number (1+ number))
                (goto-char (car cell))
                (forward-line 1)
                (when markdown
                  (save-excursion
                    (while (re-search-forward my/python-notebook-heading-regexp end t)
                      (let* ((level (length (match-string 1)))
                             (heading (string-trim (match-string-no-properties 2)))
                             (branch (list heading
                                           (cons "Начало раздела"
                                                 (copy-marker (match-beginning 0))))))
                        (setq has-heading t)
                        (while (>= (caar sections) level)
                          (pop sections))
                        (push branch (cdr (cdar sections)))
                        (push (cons level branch) sections)))))
                (unless has-heading
                  (let ((label (or (unless (string-empty-p title) title)
                                   (my/python-notebook-cell-label end)
                                   (format "Ячейка %d" number))))
                    (push (cons (truncate-string-to-width label 72 nil nil "…")
                                (copy-marker (car cell)))
                          (cdr (cdar sections)))))))
            (my/python-notebook-order-entries root)
            (list root)))))))

(defun my/python-notebook-order-entries (branch)
  "Restore source order for the children accumulated in BRANCH."
  (setcdr branch (nreverse (cdr branch)))
  (dolist (entry (cdr branch))
    (when (imenu--subalist-p entry)
      (my/python-notebook-order-entries entry))))

(defun my/python-notebook-cached-index ()
  "Return the notebook index for the current buffer contents."
  (let ((tick (buffer-chars-modified-tick)))
    (unless (eq tick (car my/python-notebook-imenu-cache))
      (setq my/python-notebook-imenu-cache (cons tick (my/python-notebook-index))))
    (cdr my/python-notebook-imenu-cache)))

(defun my/imenu-list-last-buffer ()
  "Return the buffer that Outline last tried to index."
  (when imenu-list--last-location
    (marker-buffer imenu-list--last-location)))

(defun my/imenu-list-update-source (update &optional force)
  "Refresh the index for a new source and preserve it in auxiliary panels."
  (unless (derived-mode-p 'codex-ide-session-mode 'imenu-list-major-mode 'treemacs-mode)
    (let ((imenu-list-persist-when-imenu-index-unavailable
           (and (not buffer-file-name)
                imenu-list-persist-when-imenu-index-unavailable)))
      ;; The package compares only numeric positions when deciding to skip.
      (let ((refresh (or force (not (eq (current-buffer)
                                        (my/imenu-list-last-buffer)))))
            (notebook (and (derived-mode-p 'python-base-mode)
                           (my/python-notebook-cached-index))))
        (if notebook
            (let ((imenu-create-index-function (lambda () notebook))
                  (imenu--index-alist nil))
              (funcall update refresh))
          (funcall update refresh)))
      (unless imenu-list--imenu-entries
        (setq imenu-list--displayed-buffer nil)))))

(defun my/imenu-list-refresh-frame (frame)
  "Update a visible Outline for FRAME's newly selected buffer."
  (when (and (eq frame (selected-frame))
             imenu-list-auto-update
             (get-buffer-window imenu-list-buffer-name frame))
    (with-selected-window (frame-selected-window frame)
      (unless (eq (current-buffer) (my/imenu-list-last-buffer))
        (imenu-list-update)))))

(defun my/imenu-list-follow-buffer (frame)
  "Schedule an Outline refresh outside redisplay for FRAME."
  (when (and imenu-list-auto-update
             (get-buffer-window imenu-list-buffer-name frame)
             (not (eq (window-buffer (frame-selected-window frame))
                      (my/imenu-list-last-buffer))))
    (run-at-time 0 nil #'my/imenu-list-refresh-frame frame)))

(defun my/imenu-list-clear-closed-source ()
  "Clear Outline when its source buffer is killed."
  (when (eq (current-buffer) imenu-list--displayed-buffer)
    (setq imenu-list--displayed-buffer nil)
    (imenu-list-clear)))

(use-package imenu-list
  :ensure t
  :bind ("C-c o" . imenu-list-smart-toggle)
  :custom
  (imenu-list-position 'right)
  (imenu-list-size 32)
  (imenu-list-auto-resize nil)
  :config
  (advice-add 'imenu-list-update :around #'my/imenu-list-update-source)
  (add-hook 'window-state-change-functions #'my/imenu-list-follow-buffer)
  (add-hook 'kill-buffer-hook #'my/imenu-list-clear-closed-source))

(defun my/sql-imenu-sections ()
  "Include named SQL comments alongside the standard object index."
  (setq-local imenu-generic-expression
              (copy-sequence imenu-generic-expression))
  (add-to-list 'imenu-generic-expression
               '("Разделы"
                 "^[ \t]*--[ \t]+outline:[ \t]+\\([^ \t\n].*?\\)[ \t]*$"
                 1))
  (setq imenu--index-alist nil))

(add-hook 'sql-mode-hook #'my/sql-imenu-sections)

;; Apply the index extension to SQL buffers that are already open.
(dolist (buffer (buffer-list))
  (with-current-buffer buffer
    (when (derived-mode-p 'sql-mode)
      (my/sql-imenu-sections))))

(provide 'init-outline)
;;; init-outline.el ends here
