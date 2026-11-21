;;; codex-prompt-encoding.el --- Display misdecoded Cyrillic prompts -*- lexical-binding: t; -*-

(require 'seq)

(defconst my/codex-cyrillic-mojibake
  (concat "\\(?:[" (string #xd0 #xd1) "][" (string #x80) "-" (string #xbf) "]\\)+")
  "UTF-8 Russian letters misread as ISO-8859-1.")

(defun my/codex-decode-cyrillic (text)
  "Decode the misinterpreted UTF-8 byte pairs in TEXT."
  (decode-coding-string (encode-coding-string text 'iso-latin-1) 'utf-8-unix))

(defun my/codex-display-stored-prompt (text)
  "Correct the display of misdecoded Cyrillic in a stored user prompt."
  (if (stringp text)
      (replace-regexp-in-string my/codex-cyrillic-mojibake
                                #'my/codex-decode-cyrillic text t t)
    text))

(defun my/codex-display-live-prompt (start end)
  "Correct the visible user prompt between START and END without editing it."
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
              (overlay-put overlay 'display (my/codex-decode-cyrillic text)))))))))

(advice-add 'codex-ide--style-user-prompt-region :after #'my/codex-display-live-prompt)
(advice-add 'codex-ide--thread-read-display-user-text :filter-return
            #'my/codex-display-stored-prompt)

(provide 'codex-prompt-encoding)
