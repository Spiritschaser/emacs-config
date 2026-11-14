;;; init-packages.el --- Package manager bootstrap -*- lexical-binding: t; -*-

(when (version< emacs-version "29.1")
  (error "This configuration requires Emacs 29.1 or newer"))

(require 'package)

;; Keep the standard GNU and NonGNU archives, and add MELPA.
(add-to-list 'package-archives
             '("melpa" . "https://melpa.org/packages/") t)

;; Normal startup activates packages before init.el; -Q/batch does not.
(unless package--initialized
  (package-initialize))

;; Built into Emacs 29+.  Declarations live in the thematic init modules.
;; use-package refreshes archive metadata when a missing package needs it.
(require 'use-package)
(setq use-package-always-ensure t)

(provide 'init-packages)
;;; init-packages.el ends here
