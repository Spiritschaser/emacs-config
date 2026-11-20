;;; init-outline.el --- Imenu outline sidebar -*- lexical-binding: t; -*-

(require 'imenu)

(defun my/imenu-list-skip-codex (update &rest args)
  "Keep the current outline when a Codex session buffer is selected."
  (unless (derived-mode-p 'codex-ide-session-mode)
    (apply update args)))

(use-package imenu-list
  :ensure t
  :bind ("C-c o" . imenu-list-smart-toggle)
  :custom
  (imenu-list-position 'right)
  (imenu-list-size 32)
  (imenu-list-auto-resize nil)
  :config
  (advice-add 'imenu-list-update :around #'my/imenu-list-skip-codex))

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
