;;; init-python.el --- Python -*- lexical-binding: t; -*-

(defun my/python-setup ()
  "Configure Python buffers."

  ;; Indentation.
  (setq-local python-indent-offset 4)

  ;; Automatically start BasedPyright if installed.
  (my/eglot-start-if-available
   "basedpyright-langserver"))

(add-hook 'python-mode-hook #'my/python-setup)
(add-hook 'python-ts-mode-hook #'my/python-setup)

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
