;;; codex-prompt-encoding.el --- Keep Codex prompts editable and decode Cyrillic -*- lexical-binding: t; -*-

(require 'seq)

(defconst my/codex-cyrillic-mojibake
  (concat "\\(?:[" (string #xd0 #xd1) "][" (string #x80) "-" (string #xbf) "]\\)+")
  "UTF-8 Russian letters misread as ISO-8859-1.")

(defun my/codex-decode-cyrillic (text)
  "Decode the misinterpreted UTF-8 byte pairs in TEXT."
  (decode-coding-string (encode-coding-string text 'iso-latin-1) 'utf-8-unix))

(defun my/codex-display-stored-prompt (text)
  "Decode misinterpreted Cyrillic in TEXT, leaving other characters alone."
  (if (stringp text)
      ;; These are literal byte values.  Case folding would also match
      ;; lowercase Latin letters such as ñ and pass invalid UTF-8 to decode.
      (let ((case-fold-search nil))
        (replace-regexp-in-string my/codex-cyrillic-mojibake
                                  #'my/codex-decode-cyrillic text t t))
    text))

(defun my/codex-display-live-prompt (start end)
  "Correct the visible user prompt between START and END without editing it."
  (let ((case-fold-search nil))
    (save-excursion
      (save-match-data
        (goto-char start)
        (while (re-search-forward my/codex-cyrillic-mojibake end t)
          (let* ((from (match-beginning 0))
                 (to (match-end 0))
                 (text (match-string-no-properties 0)))
            (when (and (eq (get-text-property from 'face) 'codex-ide-user-prompt-face)
                       (not (seq-some (lambda (overlay)
                                        (overlay-get overlay 'my/codex-prompt-encoding))
                                      (overlays-at from))))
              (let ((overlay (make-overlay from to nil t)))
                (overlay-put overlay 'my/codex-prompt-encoding t)
                (overlay-put overlay 'evaporate t)
                (overlay-put overlay 'display (my/codex-decode-cyrillic text))))))))))

(advice-add 'codex-ide--style-user-prompt-region :after #'my/codex-display-live-prompt)
(advice-add 'codex-ide--thread-read-display-user-text :filter-return
            #'my/codex-display-stored-prompt)

;; The transcript, the "> " prefix, and the padding after the prompt are
;; protected text in the same buffer.  In particular, (point-max) is *after*
;; the editable field.  Move only when starting an edit so scrolling, search,
;; selecting text and copying from the transcript keep working normally.
(defconst my/codex-input-commands
  '(self-insert-command newline newline-and-indent
    electric-newline-and-maybe-indent open-line
    yank cua-paste clipboard-yank evil-paste-before evil-paste-after
    evil-paste-from-register)
  "Commands that should insert into the active Codex input field.")

(defun my/codex-repair-input-boundaries (start end)
  "Restore editability between prompt markers START and END."
  ;; An active overlay alone does not override read-only text properties.
  ;; Repair the draft and the stickiness on its two neighbors.  The prefix
  ;; and padding themselves keep their protection.
  (with-silent-modifications
    (codex-ide--make-region-writable start end)
    (when (> start (point-min))
      (let ((sticky (get-text-property (1- start) 'rear-nonsticky)))
        (unless (eq sticky t)
          (put-text-property (1- start) start 'rear-nonsticky
                             (cons 'read-only (remq 'read-only sticky))))))
    (when (< end (point-max))
      (let ((sticky (get-text-property end 'front-sticky)))
        (put-text-property end (1+ end) 'front-sticky
                           (unless (eq sticky t)
                             (remq 'read-only sticky)))))))

(defun my/codex-prepare-input ()
  "Ensure that point is editable in this Codex session, if available."
  (when-let* ((session (codex-ide--session-for-current-buffer)))
    ;; An interactive approval has its own keys and must still receive them.
    (unless (codex-ide-session-mode--approval-pending-p session)
      (setq buffer-read-only nil)
      (unless (codex-ide--input-prompt-active-p session)
        ;; Use the native renderer to rebuild the prompt markers and overlay.
        ;; This does not start a turn, add a queue entry or restart the server.
        (codex-ide--insert-input-prompt session))
      (let* ((start (marker-position (codex-ide-session-input-start-marker session)))
             (end (codex-ide--input-end-position session)))
        (when (or (get-pos-property start 'read-only)
                  (get-pos-property end 'read-only)
                  (text-property-not-all start end 'read-only nil))
          (my/codex-repair-input-boundaries start end))
        ;; A selection that touches history must not be replaced by typing
        ;; or pasting.  A selection wholly inside the draft stays editable.
        (when (and (use-region-p)
                   (or (< (region-beginning) start) (> (region-end) end)))
          (deactivate-mark t))
        (unless (<= start (point) end)
          (goto-char end))
        (codex-ide--sync-prompt-minor-mode session)
        t))))

(defun my/codex-prepare-input-command ()
  "Redirect commands that insert text before they attempt to edit."
  (when (memq this-command my/codex-input-commands)
    (my/codex-prepare-input)))

(defun my/codex-mouse-yank (original &rest args)
  "In a Codex session, paste at the draft instead of the mouse position."
  ;; The standard command moves point to the click after pre-command-hook.
  ;; Its built-in mouse-yank-at-point option keeps the position we prepared.
  (let ((mouse-yank-at-point
         (or (and (derived-mode-p 'codex-ide-session-mode)
                  (my/codex-prepare-input))
             mouse-yank-at-point)))
    (apply original args)))

(defvar-local my/codex-input-changed nil
  "Non-nil when the current command may have inserted text into the draft.")

(defun my/codex-note-input-change (start end _old-length)
  "Schedule decoding if START to END contains new user input."
  ;; Render transactions explicitly bind inhibit-read-only.  Ignore their
  ;; changes and ordinary deletions, including undo.  Running the decoder at
  ;; the end of the command lets paste, input methods and undo finish first.
  (when (and (< start end) (not inhibit-read-only) (not undo-in-progress))
    (when-let* ((session (codex-ide--session-for-current-buffer))
                (_ (codex-ide--input-prompt-active-p session))
                (input-start (marker-position
                              (codex-ide-session-input-start-marker session))))
      (when (and (<= input-start start)
                 (<= end (codex-ide--input-end-position session)))
        (setq my/codex-input-changed t)))))

(defun my/codex-decode-input-after-command ()
  "Decode complete mojibake sequences inside the editable field."
  (when my/codex-input-changed
    (let ((my/codex-input-changed nil)
          (case-fold-search nil))
      (when-let* ((session (codex-ide--session-for-current-buffer))
                  (_ (codex-ide--input-prompt-active-p session))
                  (start (codex-ide-session-input-start-marker session)))
        ;; A lone leading byte is left until its continuation arrives.  Move
        ;; the saved cursor and end markers with replacements so typing can
        ;; continue immediately after the decoded text.
        (let ((cursor (copy-marker (point) t))
              (end (copy-marker (codex-ide--input-end-position session) t)))
          (unwind-protect
              (save-match-data
                (goto-char start)
                (while (re-search-forward my/codex-cyrillic-mojibake end t)
                  (replace-match
                   (my/codex-decode-cyrillic (match-string-no-properties 0))
                   t t)))
            (goto-char cursor)
            (set-marker cursor nil)
            (set-marker end nil)))))
    (setq my/codex-input-changed nil)))

(defun my/codex-enable-prompt-fixes ()
  "Install local hooks in a Codex session buffer."
  ;; Run before deletion of an active selection so a paste from history
  ;; cannot delete it.  Use a late post-command hook for text normalization.
  (add-hook 'pre-command-hook #'my/codex-prepare-input-command -90 t)
  (add-hook 'after-change-functions #'my/codex-note-input-change 0 t)
  (add-hook 'post-command-hook #'my/codex-decode-input-after-command 80 t))

(add-hook 'codex-ide-session-mode-hook #'my/codex-enable-prompt-fixes)
(advice-add 'mouse-yank-primary :around #'my/codex-mouse-yank)
;; Explicit prompts and some programmatic edits bypass the buffer hooks.
;; Normalize the resolved text before the session records it or sends JSON.
(advice-add 'codex-ide--prompt-for-submission :filter-return
            #'my/codex-display-stored-prompt)

(dolist (buffer (buffer-list))
  (with-current-buffer buffer
    (when (derived-mode-p 'codex-ide-session-mode)
      (my/codex-enable-prompt-fixes))))

(provide 'codex-prompt-encoding)
