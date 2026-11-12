;;; init-treemacs.el --- Project file explorer -*- lexical-binding: t; -*-

(use-package treemacs
  :ensure t
  :commands (treemacs treemacs-select-window)

  :bind
  (("C-c t" . treemacs)
   ("M-0"   . treemacs-select-window))

  :custom
  ;; Appearance
  (treemacs-position 'left)
  (treemacs-width 32)

  ;; Keep the panel out of normal window switching.
  (treemacs-is-never-other-window t)

  ;; Do not follow the currently opened file.
  (treemacs-follow-after-init nil)

  ;; Do not collapse other roots while navigating.
  (treemacs-project-follow-cleanup nil))
  ;; Keep project selection entirely manual.
  ;; Both follow modes are disabled by default.
  ;; Do not call their disabling functions unnecessarily.

;; Vim-style navigation within Treemacs.
(use-package treemacs-evil
  :ensure t
  :after (treemacs evil))

;;; Python for Treemacs — Windows and Linux

(with-eval-after-load 'treemacs
  (setq treemacs-python-executable
        (if (eq system-type 'windows-nt)
            (executable-find "python")
          (or (executable-find "python3")
              (executable-find "python")))))

;;; Use Treemacs native context menu

(defun my/treemacs-native-context-menu ()
  "Use Treemacs native right-click menu."
  (setq-local context-menu-mode nil))

(add-hook 'treemacs-mode-hook
          #'my/treemacs-native-context-menu)

;;; Keep scroll bars out of the file tree

(defun my/treemacs-no-scroll-bars ()
  "Hide scroll bars in this Treemacs buffer and its existing windows."
  (setq-local vertical-scroll-bar nil)
  (setq-local horizontal-scroll-bar nil)
  (dolist (window (get-buffer-window-list (current-buffer) nil t))
    (set-window-scroll-bars window nil nil nil nil)))

(add-hook 'treemacs-mode-hook #'my/treemacs-no-scroll-bars)

;; Also update trees that were open when this module was loaded.
(dolist (buffer (buffer-list))
  (with-current-buffer buffer
    (when (derived-mode-p 'treemacs-mode)
      (my/treemacs-no-scroll-bars))))

(provide 'init-treemacs)

;;; init-treemacs.el ends here
