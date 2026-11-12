;;; Windows compatibility -*- lexical-binding: t; -*-

(when (eq system-type 'windows-nt)
  (let ((git-unix-bin "C:/Program Files/Git/usr/bin"))
    (when (file-directory-p git-unix-bin)
      ;; GNU utilities take priority over Windows commands.
      (add-to-list 'exec-path git-unix-bin)
      (setenv "PATH"
              (concat git-unix-bin
                      path-separator
                      (getenv "PATH"))))))

;;; init.el --- Main Emacs configuration -*- lexical-binding: t; -*-

(add-to-list 'load-path
             (expand-file-name "lisp" user-emacs-directory))

(require 'package)

(add-to-list 'package-archives
             '("melpa" . "https://melpa.org/packages/") t)

;;; Codex IDE — correct VC package source

(with-eval-after-load 'package-vc
  (setf (alist-get "codex-ide"
                   package-vc-selected-packages
                   nil nil #'string=)
        '(:url "https://github.com/dgillis/emacs-codex-ide"
          :lisp-dir ".")))

;;; Network proxy for Codex CLI

(let ((proxy "http://192.168.1.1:8080"))
  (setenv "HTTP_PROXY" proxy)
  (setenv "HTTPS_PROXY" proxy)
  (setenv "ALL_PROXY" proxy)
  (setenv "NO_PROXY" "localhost,127.0.0.1,::1"))

(require 'init-codex)
(require 'init-treesit)
(require 'init-lsp)
(require 'init-python)
(require 'init-python-workspace)
(require 'init-sql)
(require 'init-completion)
(require 'init-ui)
(require 'init-toolbar)
(require 'init-evil)
(require 'init-treemacs)
(require 'init-outline)
(require 'init-keys)
(require 'init-modeline)
(require 'init-fonts)
(require 'init-workspace-menu)

;;; init.el ends here
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(package-selected-packages
   '(clutch imenu-list codex-ide corfu doom-modeline evil evil-collection
	    flymake-ruff markdown-mode pgsql telephone-line treemacs
	    treemacs-evil))
 '(safe-local-variable-values '((codex-ide-log-max-lines . 1000000))))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
