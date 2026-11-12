;;; init-modeline.el --- Modern modeline -*- lexical-binding: t; -*-

(use-package doom-modeline
  :ensure t
  :custom
  ;; Appearance
  (doom-modeline-height 32)
  (doom-modeline-bar-width 4)
  (doom-modeline-icon t)
  (doom-modeline-major-mode-icon t)
  (doom-modeline-major-mode-color-icon t)

  ;; Evil states: Normal, Insert, Visual
  (doom-modeline-modal t)
  (doom-modeline-modal-icon t)
  (doom-modeline-modal-modern-icon t)

  ;; File and project
  (doom-modeline-buffer-file-name-style 'auto)
  (doom-modeline-buffer-state-icon t)
  (doom-modeline-vcs-icon t)
  (doom-modeline-vcs-max-length 20)

  ;; LSP and diagnostics
  (doom-modeline-lsp t)
  (doom-modeline-check 'auto)

  ;; Clean status line
  (doom-modeline-minor-modes nil)
  (doom-modeline-buffer-encoding t)

  :init
  (doom-modeline-mode 1))

(provide 'init-modeline)
;;; init-modeline.el ends here
