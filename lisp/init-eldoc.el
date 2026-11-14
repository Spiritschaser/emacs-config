;;; init-eldoc.el --- Persistent documentation buffer -*- lexical-binding: t; -*-

(require 'eldoc)

(defun my/eldoc-ensure-buffer ()
  "Return the visible-by-name documentation buffer, creating it if needed."
  (let ((buffer (or (get-buffer "*eldoc*")
                    (and (buffer-live-p eldoc--doc-buffer) eldoc--doc-buffer)
                    (get-buffer-create "*eldoc*"))))
    (setq eldoc--doc-buffer buffer)
    (with-current-buffer buffer
      (unless (derived-mode-p 'special-mode)
        (special-mode))
      (unless (equal (buffer-name) "*eldoc*")
        (rename-buffer "*eldoc*")))
    buffer))

(defun my/eldoc-display (docs interactive)
  "Render DOCS in *eldoc*, opening a window only when INTERACTIVE."
  (my/eldoc-ensure-buffer)
  ;; Let ElDoc format rich documentation, then undo its per-symbol renaming.
  (eldoc-display-in-buffer docs nil)
  (let ((buffer (my/eldoc-ensure-buffer)))
    (when interactive
      (display-buffer buffer)))
  t)

(defun my/eldoc-use-buffer ()
  "Route this buffer's documentation to the persistent ElDoc buffer."
  (setq-local eldoc-display-functions '(my/eldoc-display)))

(setq-default eldoc-display-functions '(my/eldoc-display))
(add-hook 'eldoc-mode-hook #'my/eldoc-use-buffer)

;; Apply to already open buffers, including the former Python console setup.
(dolist (buffer (buffer-list))
  (with-current-buffer buffer
    (when (or (bound-and-true-p eldoc-mode)
              (local-variable-p 'eldoc-display-functions))
      (my/eldoc-use-buffer))))

(my/eldoc-ensure-buffer)

(provide 'init-eldoc)
;;; init-eldoc.el ends here
