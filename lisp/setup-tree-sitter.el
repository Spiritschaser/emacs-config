;; 📦 TREESIT
;; Встроенный пакет для работы с TreeSitter
(use-package treesit
  :config
  ;; Грамматики
  (setq treesit-language-source-alist
    '(
       (asciidoc
         "https://github.com/m-novikov/tree-sitter-sql.git"
         "v0.1.0"
         "tree-sitter-sql/src/")
))
  ;; Сборка и установка грамматик
  (dolist (source treesit-language-source-alist)
    (let ((lang (car source)))
      (unless (treesit-ready-p lang t)
        (with-demoted-errors "Treesit: ошибка установки грамматики: %s"
          (treesit-install-language-grammar lang)))))
  ;; Замена "классических" режимов на TreeSitter
  (add-to-list 'major-mode-remap-alist '(bash-mode . bash-ts-mode))
