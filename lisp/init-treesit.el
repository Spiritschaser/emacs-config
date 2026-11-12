;;; init-treesit.el --- Tree-sitter -*- lexical-binding: t; -*-

;; Detailed syntax highlighting.
(setq treesit-font-lock-level 4)

;; Enable Tree-sitter Python mode when its grammar is available.
(when (and (treesit-available-p)
           (treesit-language-available-p 'python))
  (add-to-list 'major-mode-remap-alist
               '(python-mode . python-ts-mode)))

;; Markdown support.
(when (and (treesit-available-p)
           (treesit-language-available-p 'markdown)
           (treesit-language-available-p 'markdown-inline))
  (require 'markdown-ts-mode)
  (add-to-list 'auto-mode-alist
               '("\\.md\\'" . markdown-ts-mode)))

(setq markdown-ts-fontify-code-blocks-natively t)

(provide 'init-treesit)
