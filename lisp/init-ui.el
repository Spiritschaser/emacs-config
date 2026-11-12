;;; init-ui.el --- Appearance -*- lexical-binding: t; -*-

;; Hide unnecessary GUI elements.
;;(when (fboundp 'tool-bar-mode)
;;  (tool-bar-mode -1))

;; Keep vertical scroll bars on the right in existing and future frames.
(when (fboundp 'set-scroll-bar-mode)
  (set-scroll-bar-mode 'right))

;; Give the mouse a visible handle between side-by-side windows.
(setq window-divider-default-places 'right-only
      window-divider-default-right-width 5)
(window-divider-mode 1)

;; Show line numbers in programming buffers.
(add-hook 'prog-mode-hook #'display-line-numbers-mode)

;; Matching parentheses.
(show-paren-mode 1)

;; Highlight current line.
(add-hook 'prog-mode-hook #'hl-line-mode)

;; Dark theme.
(load-theme 'modus-vivendi-tinted t)

;; Keep the toolbar enabled.
(tool-bar-mode 1)

;;; Buffer tabs
(global-tab-line-mode 1)

;;; Encoding

(prefer-coding-system 'utf-8)
(set-default-coding-systems 'utf-8)

(setq default-process-coding-system
      '(utf-8-unix . utf-8-unix))

;;; Disable mouse-save-then-kill everywhere
(global-set-key [remap mouse-save-then-kill] #'ignore)

;;; Context menu (right mouse button)
(context-menu-mode 1)

;;; Double-click tab-line: maximize / restore window

(defun my/tab-line-toggle-maximize (event)
  "Maximize clicked window or restore previous layout."
  (interactive "e")
  (let* ((window (posn-window (event-start event)))
         (frame (window-frame window))
         (saved (frame-parameter frame 'my/saved-window-config)))
    (with-selected-frame frame
      (if saved
          (progn
            (set-frame-parameter frame 'my/saved-window-config nil)
            (set-window-configuration saved))
        (select-window window)
        (set-frame-parameter
         frame 'my/saved-window-config
         (current-window-configuration))
        (delete-other-windows window)))))

(with-eval-after-load 'tab-line
  (define-key tab-line-tab-map
              [tab-line double-down-mouse-1]
              #'my/tab-line-toggle-maximize))

;;; Close tab: kill buffer, then close window if it was the only tab

(defun my/tab-line-close-buffer (tab)
  "Kill TAB buffer and close its window if it was the last tab."
  (let* ((buffer (if (bufferp tab)
                     tab
                   (alist-get 'buffer tab)))
         (window (selected-window))
         (last-tab (= (length (funcall tab-line-tabs-function)) 1)))
    (when (and (buffer-live-p buffer)
               (kill-buffer buffer)
               last-tab
               (window-live-p window)
               (> (length (window-list)) 1))
      (delete-window window))))

(with-eval-after-load 'tab-line
  (setq tab-line-close-tab-function #'my/tab-line-close-buffer))

(provide 'init-ui)
;;; init-ui.el ends here
