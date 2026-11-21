;;; init-desktop.el --- Restore the editing session and its tools -*- lexical-binding: t; -*-

(require 'desktop)
(require 'seq)

(defvar my/desktop-tools nil
  "Tool buffers that were visible when the desktop was saved.")

(defvar-local my/desktop-tool-placeholder nil)

(add-to-list 'desktop-globals-to-save 'my/desktop-tools)

(defun my/desktop-save-tools ()
  "Record visible tool buffers and the identity of each Codex thread."
  (setq my/desktop-tools nil)
  (walk-windows
   (lambda (window)
     (with-current-buffer (window-buffer window)
       (pcase major-mode
         ('treemacs-mode
          (push (list 'treemacs (buffer-name) default-directory) my/desktop-tools))
         ('imenu-list-major-mode
          (push (list 'imenu (buffer-name)) my/desktop-tools))
         ('codex-ide-session-mode
          (when-let* ((session (codex-ide--session-for-current-buffer))
                      (thread (codex-ide-session-thread-id session)))
            (push (list 'codex (buffer-name)
                        (codex-ide-session-directory session) thread)
                  my/desktop-tools))))))
   'no-minibuffer 'visible)
  (setq my/desktop-tools (delete-dups my/desktop-tools)))

(defun my/desktop-prepare-tools ()
  "Supply buffer names before Desktop restores the window tree."
  (when desktop-saved-frameset
    (pcase-dolist (`(,kind ,name . ,_) my/desktop-tools)
      (pcase kind
        ('imenu
         (require 'imenu-list)
         (imenu-list-get-buffer-create))
        ((or 'treemacs 'codex)
         (unless (get-buffer name)
           (with-current-buffer (get-buffer-create name)
             (setq-local my/desktop-tool-placeholder t))))))))

(defun my/desktop-restore-codex (buffer directory thread)
  "Resume THREAD from DIRECTORY in the windows showing BUFFER."
  (when (and (buffer-live-p buffer)
             (buffer-local-value 'my/desktop-tool-placeholder buffer)
             (file-directory-p directory))
    (let ((windows (get-buffer-window-list buffer nil t))
          (default-directory directory))
      (when windows
        (with-current-buffer buffer
          (rename-buffer " *Desktop Codex placeholder*" t))
        (unwind-protect
            (with-selected-window (car windows)
              ;; The transcript belongs in the saved window, even when Codex
              ;; normally creates a new split when opening a session.
              (let ((display-buffer-overriding-action
                     '((display-buffer-same-window))))
                (codex-ide--prepare-session-operations)
                (let* ((session (codex-ide--show-or-resume-thread thread directory))
                       (transcript (codex-ide-session-buffer session)))
                  (dolist (window windows)
                    (when (window-live-p window)
                      (set-window-buffer window transcript))))))
          (when (buffer-live-p buffer)
            (kill-buffer buffer)))))))

(defun my/desktop-restore-tools ()
  "Reopen the tools in the restored desktop."
  (let ((frame (selected-frame))
        (entries my/desktop-tools))
    ;; Restore once the initial GUI frame and its windows are ready.
    (run-with-idle-timer
     0 nil
     (lambda ()
       (when (frame-live-p frame)
         (with-selected-frame frame
           (pcase-dolist (`(,kind ,name . ,data) entries)
             (when-let* ((buffer (get-buffer name))
                         (window (get-buffer-window buffer t)))
               (condition-case error-data
                   (pcase kind
                     ('imenu
                      (when-let* ((source
                                   (seq-find
                                    (lambda (candidate)
                                      (buffer-file-name (window-buffer candidate)))
                                    (window-list (window-frame window) 'no-minibuffer))))
                        (with-selected-window source
                          (imenu-list-minor-mode 1))))
                     ('treemacs
                      (when (buffer-local-value 'my/desktop-tool-placeholder buffer)
                        ;; Treemacs treats any visible buffer with its name
                        ;; prefix as an already running panel.
                        (with-current-buffer buffer
                          (rename-buffer " *Desktop Treemacs placeholder*" t))
                        (with-selected-frame (window-frame window)
                          (let ((default-directory (if (file-directory-p (car data))
                                                       (car data) default-directory))
                                (display-buffer-overriding-action
                                 (list
                                  (list
                                   (lambda (tree _alist)
                                     (set-window-dedicated-p window nil)
                                     (set-window-buffer window tree)
                                     (set-window-dedicated-p window t)
                                     window)))))
                            (save-selected-window (treemacs-select-window))))
                        (unless (get-buffer-window buffer t)
                          (kill-buffer buffer))))
                     ('codex
                      (my/desktop-restore-codex buffer (car data) (cadr data))))
                 (error
                  (message "Desktop: %s: %s" kind
                           (error-message-string error-data))))))))))))

(add-hook 'desktop-save-hook #'my/desktop-save-tools)
(advice-add 'desktop-restore-frameset :before #'my/desktop-prepare-tools)
(add-hook 'desktop-after-read-hook #'my/desktop-restore-tools)

(setq desktop-save t
      desktop-restore-frames t
      desktop-auto-save-timeout 15
      desktop-load-locked-desktop 'check-pid)

(desktop-save-mode 1)

(provide 'init-desktop)
