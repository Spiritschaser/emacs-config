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

(defun my/import-bash-path ()
  "Import PATH from interactive Bash on Linux."
  (when (eq system-type 'gnu/linux)
    (when-let* ((bash (executable-find "bash")))
      (with-temp-buffer
        ;; Delimit PATH so output from .bashrc does not pollute it.
        (when (eq 0 (ignore-error file-error
                      (call-process bash nil (list (current-buffer) nil) nil
                                    "-ic" "printf '\\0%s\\0' \"$PATH\"")))
          (goto-char (point-max))
          (when (re-search-backward "\0\\([^\0]+\\)\0" nil t)
            (let ((path (match-string-no-properties 1)))
              (setenv "PATH" path)
              (setq exec-path
                    (append (parse-colon-path path) (list exec-directory))))))))))

(my/import-bash-path)

(add-to-list 'load-path
             (expand-file-name "lisp" user-emacs-directory))

(require 'init-packages)

;;; Network proxy for Codex CLI

(let ((proxy "http://192.168.1.1:8080"))
  (setenv "HTTP_PROXY" proxy)
  (setenv "HTTPS_PROXY" proxy)
  (setenv "ALL_PROXY" proxy)
  (setenv "NO_PROXY" "localhost,127.0.0.1,::1"))

(require 'init-codex)
(require 'init-treesit)
(require 'init-eldoc)
(require 'init-lsp)
(require 'init-dart)
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
 '(cua-mode t)
 '(custom-enabled-themes '(modus-vivendi))
 '(custom-safe-themes
   '("967c23e9ba179b80560774419f081df22e7674aac23c5c550b817e4a1ce7d058"
     default))
 '(package-selected-packages
   '(canvas-minimap clutch code-cells codex-ide comint-mime corfu
		    dart-mode doom-modeline drepl evil evil-collection
		    flymake-ruff imenu-list markdown-mode modus-themes
		    pgsql ruff-format treemacs treemacs-evil))
 '(package-vc-selected-packages
   '((canvas-minimap :vc-backend Git :url
		     "https://github.com/Daskeladden/canvas-minimap")
     (codex-ide :url "https://github.com/dgillis/emacs-codex-ide"
		:lisp-dir ".")))
 '(safe-local-variable-values '((codex-ide-log-max-lines . 1000000))))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
