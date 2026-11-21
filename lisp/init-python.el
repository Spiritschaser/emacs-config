;;; init-python.el --- Python -*- lexical-binding: t; -*-

(require 'treesit)

(defun my/python-enable-sql-font-lock ()
  "Highlight SQL in triple-quoted strings assigned to sql or *_sql."
  (when (and treesit-primary-parser (treesit-language-available-p 'sql))
    (setq-local treesit-range-settings
                (append
                 treesit-range-settings
                 (treesit-range-rules
                  :host 'python :embed 'sql :local t
                  '(((assignment
                      left: (identifier) @_name
                      right: (string
                              (string_start) @_quote
                              (string_content) @sql))
                     (:match "\\`\\(?:sql\\|.*_sql\\)\\'" @_name)
                     (:match "\\`[rR]?\\(?:\"\"\"\\|'''\\)\\'" @_quote))))))
    (setq-local treesit-font-lock-settings
                (append
                 treesit-font-lock-settings
                 (treesit-font-lock-rules
                  :language 'sql :feature 'keyword :override t
                  '([(keyword_with) (keyword_recursive) (keyword_as)
                     (keyword_select) (keyword_distinct) (keyword_from)
                     (keyword_join) (keyword_on) (keyword_where)
                     (keyword_group) (keyword_by) (keyword_having)
                     (keyword_order) (keyword_limit) (keyword_offset)
                     (keyword_union) (keyword_all) (keyword_and) (keyword_or)
                     (keyword_not) (keyword_null)
                     (keyword_insert) (keyword_into) (keyword_values)
                     (keyword_update) (keyword_set) (keyword_delete)
                     (keyword_returning)] @font-lock-keyword-face)
                  :language 'sql :feature 'comment :override t
                  '((comment) @font-lock-comment-face)
                  :language 'sql :feature 'number :override t
                  '(((literal) @font-lock-number-face
                     (:match "\\`[-+]?[0-9]+\\(?:\\.[0-9]+\\)?\\'"
                             @font-lock-number-face))))))
    (treesit-font-lock-recompute-features)))

(defun my/python-setup ()
  "Configure Python buffers."

  ;; Indentation.
  (setq-local python-indent-offset 4)

  ;; Automatically start BasedPyright if installed.
  (my/eglot-start-if-available
   "basedpyright-langserver"))

(add-hook 'python-mode-hook #'my/python-setup)
(add-hook 'python-ts-mode-hook #'my/python-setup)
(add-hook 'python-ts-mode-hook #'my/python-enable-sql-font-lock)

;; Ruff diagnostics through Flymake.
(use-package flymake-ruff
  :ensure t
  :hook
  (eglot-managed-mode . my/python-enable-ruff)

  :init
  (defun my/python-enable-ruff ()
    "Enable Ruff diagnostics in Python buffers."
    (when (derived-mode-p 'python-base-mode)
      (flymake-ruff-load))))

;; Ruff formatting.
(use-package ruff-format
  :ensure t
  :commands
  (ruff-format-buffer
   ruff-format-region
   ruff-format-on-save-mode))

(provide 'init-python)
