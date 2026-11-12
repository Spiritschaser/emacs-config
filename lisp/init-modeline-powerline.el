;;; init-modeline-powerline.el -*- lexical-binding: t; -*-

;; Disable Doom Modeline before enabling Telephone Line.
(when (bound-and-true-p doom-modeline-mode)
  (doom-modeline-mode -1))

(use-package telephone-line
  :ensure t
  :after evil
  :custom
  (telephone-line-height 28)
  (telephone-line-evil-use-short-tag nil)

  :config
  ;; Angular Powerline separators.
  (setq telephone-line-primary-left-separator
        'telephone-line-abs-left
        telephone-line-secondary-left-separator
        'telephone-line-abs-hollow-left
        telephone-line-primary-right-separator
        'telephone-line-abs-right
        telephone-line-secondary-right-separator
        'telephone-line-abs-hollow-right)

  ;; Left: Evil state, Git, filename.
  (setq telephone-line-lhs
        '((evil . (telephone-line-evil-tag-segment))
          (accent . (telephone-line-vc-segment))
          (nil . (telephone-line-buffer-segment))))

  ;; Right: mode and cursor position.
  (setq telephone-line-rhs
        '((nil . (telephone-line-misc-info-segment))
          (accent . (telephone-line-major-mode-segment))
          (evil . (telephone-line-airline-position-segment))))

  (telephone-line-mode 1))

(provide 'init-modeline-powerline)
