;;; init-treesit.el --- Tree-sitter -*- lexical-binding: t; -*-

(require 'treesit)

(add-to-list 'treesit-language-source-alist
             '(python "https://github.com/tree-sitter/tree-sitter-python.git"
                      "v0.25.0"))
(add-to-list 'treesit-language-source-alist
             '(sql "https://github.com/DerekStride/tree-sitter-sql.git"
                   "gh-pages"))

;; Detailed syntax highlighting.
(setq treesit-font-lock-level 4)

;; Enable Tree-sitter Python mode when its grammar is available.
(when (and (treesit-available-p)
           (treesit-language-available-p 'python))
  (add-to-list 'major-mode-remap-alist
               '(python-mode . python-ts-mode)))

(use-package markdown-mode
  :commands (markdown-mode gfm-mode))

(use-package markdown-ts-mode
  ;; The built-in mode has no autoload in this Emacs distribution.
  ;; Register it before auto-mode-alist selects it for Markdown files.
  :commands markdown-ts-mode
  :custom
  (markdown-ts-fontify-code-blocks-natively t))

;; Replace the same rule when reloading after installing/removing grammars.
(setf (alist-get "\\.md\\'" auto-mode-alist nil nil #'equal)
      (if (and (treesit-available-p)
               (treesit-language-available-p 'markdown)
               (treesit-language-available-p 'markdown-inline))
          'markdown-ts-mode
        'markdown-mode))

(provide 'init-treesit)
