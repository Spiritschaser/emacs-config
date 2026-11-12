;;; init-evil.el --- Vim editing -*- lexical-binding: t; -*-

;; Must be configured before Evil is loaded.
(setq evil-want-integration t
      evil-want-keybinding nil
      evil-want-C-u-scroll t
      evil-want-fine-undo t)

(use-package evil
  :ensure t
  :demand t
  :config
  (evil-mode 1))

(use-package evil-collection
  :ensure t
  :after evil
  :config
  (evil-collection-init))

(provide 'init-evil)
;;; init-evil.el ends here
