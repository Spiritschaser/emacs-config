;;; init-org.el --- Org documents and previews -*- lexical-binding: t; -*-

(defun my/org-add-tool-bin (relative-directory)
  "Expose an installed Org tool in RELATIVE-DIRECTORY to Emacs processes."
  (let ((directory (expand-file-name relative-directory user-emacs-directory)))
    (when (and (file-directory-p directory) (not (member directory exec-path)))
      (add-to-list 'exec-path directory)
      (setenv "PATH" (concat directory path-separator (getenv "PATH"))))))

(my/org-add-tool-bin "tools/tinytex/bin/windows")

(use-package org
  :ensure nil
  :init
  (setq org-startup-with-link-previews t
        org-display-remote-inline-images 'skip
        org-src-fontify-natively t)
  :config
  (when (and (executable-find "latex") (executable-find "dvisvgm"))
    (setq org-preview-latex-default-process 'dvisvgm)))

(with-eval-after-load 'org-attach
  (setq org-attach-dir-relative t))

(provide 'init-org)
;;; init-org.el ends here
