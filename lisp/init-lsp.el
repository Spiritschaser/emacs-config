;;; init-lsp.el --- Language servers -*- lexical-binding: t; -*-

(require 'eglot)

;; Do not advertise dynamic file watching.
;; Workaround for Pyright/BasedPyright on Windows.

(require 'cl-lib)

(cl-defmethod eglot-client-capabilities :around (server)
  (let* ((capabilities (cl-call-next-method))
         (workspace (plist-get capabilities :workspace)))
    (plist-put workspace
               :didChangeWatchedFiles
               '(:dynamicRegistration :json-false))
    capabilities))
(setq eglot-watch-files-outside-project-root nil)

;; Python: explicitly prefer BasedPyright.
(add-to-list 'eglot-server-programs
             '((python-mode python-ts-mode)
               . ("basedpyright-langserver" "--stdio")))

;; PostgreSQL language server.
(add-to-list 'eglot-server-programs
             '(sql-mode
               . ("postgres-language-server" "lsp-proxy")))

;; Start Eglot only when the requested executable exists.
(defun my/eglot-start-if-available (program)
  "Start Eglot if PROGRAM is available."
  (when (executable-find program)
    (eglot-ensure)))

(provide 'init-lsp)
