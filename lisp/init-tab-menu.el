;;; init-tab-menu.el --- Window-local buffer tab actions -*- lexical-binding: t; -*-

(require 'tab-line)

(defun my/tab-line-buffer (tab)
  "Return the buffer represented by TAB."
  (if (bufferp tab) tab (alist-get 'buffer tab)))

(defun my/tab-line-remove-buffer (buffer window)
  "Remove BUFFER from WINDOW's tabs without killing it.
Close WINDOW when its last tab is removed, unless it is the only window."
  (unless (and (buffer-live-p buffer) (window-live-p window))
    (user-error "The buffer or source window no longer exists"))
  (with-selected-window window
    (let* ((tabs (mapcar #'my/tab-line-buffer
                        (funcall tab-line-tabs-function)))
           (remaining (delq buffer (copy-sequence tabs))))
      (if (and (null remaining)
               (not (one-window-p t (window-frame window))))
          (delete-window window)
        (when (eq buffer (window-buffer window))
          (let ((replacement (or (car remaining) (other-buffer buffer t))))
            (when (eq replacement buffer)
              (setq replacement (get-buffer-create
                                 (generate-new-buffer-name "*scratch*"))))
            (set-window-buffer window replacement)))
        ;; Remove both previous and next history, including the fixed tab order.
        (unrecord-window-buffer window buffer t)
        (set-window-parameter
         window 'tab-line-buffers
         (delq buffer (window-parameter window 'tab-line-buffers)))))
    (tab-line-force-update t)))

(defun my/tab-line-move-buffer (buffer source target)
  "Move BUFFER's tab from SOURCE to TARGET without killing BUFFER."
  (unless (and (buffer-live-p buffer)
               (window-live-p source) (window-live-p target)
               (not (eq source target)))
    (user-error "The buffer or one of the windows no longer exists"))
  (when (window-dedicated-p target)
    (user-error "The destination window is dedicated"))
  ;; Display first: a failed destination must not remove the source tab.
  (set-window-buffer target buffer)
  (my/tab-line-remove-buffer buffer source))

(defun my/tab-line-buffer-menu (buffer source event)
  "Build the tab menu for BUFFER in SOURCE, retaining click EVENT."
  (let ((menu (make-sparse-keymap "Tab"))
        (destinations (make-sparse-keymap "Переместить"))
        (index 0)
        (count 0))
    (dolist (target (window-list (window-frame source) 'no-minibuffer))
      (setq index (1+ index))
      (unless (or (eq target source) (window-dedicated-p target))
        (setq count (1+ count))
        (let ((destination target))
          (define-key-after destinations (vector (intern (format "window-%d" index)))
            `(menu-item ,(format "Окно %d: %s" index
                                 (buffer-name (window-buffer target)))
                        ,(lambda ()
                           (interactive)
                           (my/tab-line-move-buffer buffer source destination)))))))
    (define-key-after menu [remove]
      `(menu-item "Убрать" ,(lambda ()
                             (interactive)
                             (my/tab-line-remove-buffer buffer source))))
    (define-key-after menu [move]
      `(menu-item "Переместить" ,destinations :enable ,(> count 0)))
    (define-key-after menu [separator] '(menu-item "--"))
    (define-key-after menu [close]
      `(menu-item "Close" ,(lambda ()
                             (interactive)
                             (tab-line-close-tab event))))
    (define-key-after menu [close-other]
      `(menu-item "Close other tabs" ,(lambda ()
                                        (interactive)
                                        (tab-line-close-other-tabs event))))
    menu))

(defun my/tab-line-tab-context-menu (event)
  "Show buffer actions for the tab clicked in EVENT."
  (interactive "e")
  (let* ((position (event-start event))
         (window (posn-window position))
         (string (posn-string position))
         (tab (and string
                   (get-text-property (cdr string) 'tab (car string))))
         (buffer (my/tab-line-buffer tab)))
    (when (and (window-live-p window) (buffer-live-p buffer))
      (popup-menu (my/tab-line-buffer-menu buffer window event) event))))

(define-key tab-line-tab-map [tab-line down-mouse-3]
            #'my/tab-line-tab-context-menu)
(define-key tab-line-tab-close-map [tab-line down-mouse-3]
            #'my/tab-line-tab-context-menu)

(provide 'init-tab-menu)
;;; init-tab-menu.el ends here
