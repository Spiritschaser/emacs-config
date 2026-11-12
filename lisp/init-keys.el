;;; init-keys.el --- Keyboard conventions -*- lexical-binding: t; -*-

;; Windows-style clipboard and selection.
(cua-mode 1)

;; Common shortcuts.
(global-set-key (kbd "C-s") #'save-buffer)
(global-set-key (kbd "C-f") #'isearch-forward)
(global-set-key (kbd "C-a") #'mark-whole-buffer)

;; Evil has its own Ctrl+Z behavior.
;; Keep undo/redo explicit in editing states.
(with-eval-after-load 'evil
  (dolist (state '(normal insert visual))
    (evil-define-key state 'global
      (kbd "C-z") #'undo-only
      (kbd "C-y") #'undo-redo)))

(provide 'init-keys)
;;; init-keys.el ends here
