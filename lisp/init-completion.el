;;; init-completion.el --- Completion UI -*- lexical-binding: t; -*-

(use-package corfu
  :ensure t
  :custom
  (corfu-auto t)
  (corfu-auto-delay 0.25)
  (corfu-auto-prefix 2)
  (corfu-cycle t)
  (corfu-preview-current nil)
  :init
  (global-corfu-mode 1))

(provide 'init-completion)
;;; init-completion.el ends here
