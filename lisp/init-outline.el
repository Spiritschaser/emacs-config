;;; init-outline.el --- Imenu outline sidebar -*- lexical-binding: t; -*-

(require 'imenu)

(defun my/imenu-list-last-buffer ()
  "Return the buffer that Outline last tried to index."
  (when imenu-list--last-location
    (marker-buffer imenu-list--last-location)))

(defun my/imenu-list-update-source (update &optional force)
  "Refresh the index for a new source and preserve it in auxiliary panels."
  (unless (derived-mode-p 'codex-ide-session-mode 'imenu-list-major-mode 'treemacs-mode)
    (let ((imenu-list-persist-when-imenu-index-unavailable
           (and (not buffer-file-name)
                imenu-list-persist-when-imenu-index-unavailable)))
      ;; The package compares only numeric positions when deciding to skip.
      (funcall update (or force (not (eq (current-buffer)
                                        (my/imenu-list-last-buffer)))))
      (unless imenu-list--imenu-entries
        (setq imenu-list--displayed-buffer nil)))))

(defun my/imenu-list-refresh-frame (frame)
  "Update a visible Outline for FRAME's newly selected buffer."
  (when (and (eq frame (selected-frame))
             imenu-list-auto-update
             (get-buffer-window imenu-list-buffer-name frame))
    (with-selected-window (frame-selected-window frame)
      (unless (eq (current-buffer) (my/imenu-list-last-buffer))
        (imenu-list-update)))))

(defun my/imenu-list-follow-buffer (frame)
  "Schedule an Outline refresh outside redisplay for FRAME."
  (when (and imenu-list-auto-update
             (get-buffer-window imenu-list-buffer-name frame)
             (not (eq (window-buffer (frame-selected-window frame))
                      (my/imenu-list-last-buffer))))
    (run-at-time 0 nil #'my/imenu-list-refresh-frame frame)))

(defun my/imenu-list-clear-closed-source ()
  "Clear Outline when its source buffer is killed."
  (when (eq (current-buffer) imenu-list--displayed-buffer)
    (setq imenu-list--displayed-buffer nil)
    (imenu-list-clear)))

(use-package imenu-list
  :ensure t
  :bind ("C-c o" . imenu-list-smart-toggle)
  :custom
  (imenu-list-position 'right)
  (imenu-list-size 32)
  (imenu-list-auto-resize nil)
  :config
  (advice-add 'imenu-list-update :around #'my/imenu-list-update-source)
  (add-hook 'window-state-change-functions #'my/imenu-list-follow-buffer)
  (add-hook 'kill-buffer-hook #'my/imenu-list-clear-closed-source))

(defun my/sql-imenu-sections ()
  "Include named SQL comments alongside the standard object index."
  (setq-local imenu-generic-expression
              (copy-sequence imenu-generic-expression))
  (add-to-list 'imenu-generic-expression
               '("Разделы"
                 "^[ \t]*--[ \t]+outline:[ \t]+\\([^ \t\n].*?\\)[ \t]*$"
                 1))
  (setq imenu--index-alist nil))

(add-hook 'sql-mode-hook #'my/sql-imenu-sections)

;; Apply the index extension to SQL buffers that are already open.
(dolist (buffer (buffer-list))
  (with-current-buffer buffer
    (when (derived-mode-p 'sql-mode)
      (my/sql-imenu-sections))))

(provide 'init-outline)
;;; init-outline.el ends here
