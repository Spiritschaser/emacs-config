;;; init-treemacs.el --- Project file explorer -*- lexical-binding: t; -*-

(use-package treemacs
  :ensure t
  :commands (treemacs treemacs-select-window)

  :bind
  (("C-c t" . treemacs)
   ("M-0"   . treemacs-select-window))

  :custom
  ;; Appearance
  (treemacs-position 'left)
  (treemacs-width 32)

  ;; Keep the panel out of normal window switching.
  (treemacs-is-never-other-window t)

  ;; Do not follow the currently opened file.
  (treemacs-follow-after-init nil)

  ;; Do not collapse other roots while navigating.
  (treemacs-project-follow-cleanup nil))
  ;; Keep project selection entirely manual.
  ;; Both follow modes are disabled by default.
  ;; Do not call their disabling functions unnecessarily.

;; Vim-style navigation within Treemacs.
(use-package treemacs-evil
  :ensure t
  :after (treemacs evil))

;;; Open SQLite files in the Clutch workspace

(autoload 'my/clutch-workspace-open-sqlite "init-clutch-workspace")
(declare-function treemacs--prop-at-point "treemacs-core-utils" (prop))
(defvar treemacs-doubleclick-actions-config)

(defun my/treemacs-sqlite-file-p (file)
  "Return non-nil if local FILE starts with the SQLite format header."
  (and (stringp file)
       (not (file-remote-p file))
       (file-regular-p file)
       (ignore-error file-error
         (with-temp-buffer
           (set-buffer-multibyte nil)
           (insert-file-contents-literally file nil 0 16)
           (equal (buffer-string) "SQLite format 3\0")))))

(defun my/treemacs-doubleclick-open-sqlite (open-file)
  "Open the SQLite file at point in Clutch, or call OPEN-FILE."
  (let ((file (treemacs--prop-at-point :path)))
    (if (my/treemacs-sqlite-file-p file)
        (my/clutch-workspace-open-sqlite file)
      (funcall open-file))))

(with-eval-after-load 'treemacs
  (dolist (state '(file-node-open file-node-closed))
    (add-function :around (alist-get state treemacs-doubleclick-actions-config)
                  #'my/treemacs-doubleclick-open-sqlite)))

;;; Python for Treemacs — Windows and Linux

(with-eval-after-load 'treemacs
  (setq treemacs-python-executable
        (if (eq system-type 'windows-nt)
            (executable-find "python")
          (or (executable-find "python3")
              (executable-find "python")))))

;;; Use Treemacs native context menu

(defun my/treemacs-native-context-menu ()
  "Use Treemacs native right-click menu."
  (setq-local context-menu-mode nil))

(add-hook 'treemacs-mode-hook
          #'my/treemacs-native-context-menu)

;;; Use Calibri or PT Sans Narrow for the file tree

(require 'face-remap)
(require 'seq)

(defvar-local my/treemacs-font-cookie nil
  "Face remapping cookie for the Treemacs font.")

(defun my/treemacs-set-font ()
  "Use the first available preferred font in this Treemacs buffer."
  (when my/treemacs-font-cookie
    (face-remap-remove-relative my/treemacs-font-cookie)
    (setq my/treemacs-font-cookie nil))
  (when (display-graphic-p)
    (when-let* ((family (seq-find (lambda (family)
                                  (find-font (font-spec :family family)))
                                '("Calibri" "PT Sans Narrow"))))
      (setq my/treemacs-font-cookie
            (face-remap-add-relative 'default :family family)))))

(add-hook 'treemacs-mode-hook #'my/treemacs-set-font)

;;; Keep scroll bars out of the file tree

(defun my/treemacs-no-scroll-bars ()
  "Hide scroll bars in this Treemacs buffer and its existing windows."
  (setq-local vertical-scroll-bar nil)
  (setq-local horizontal-scroll-bar nil)
  (dolist (window (get-buffer-window-list (current-buffer) nil t))
    (set-window-scroll-bars window nil nil nil nil)))

(add-hook 'treemacs-mode-hook #'my/treemacs-no-scroll-bars)

;; Also update trees that were open when this module was loaded.
(dolist (buffer (buffer-list))
  (with-current-buffer buffer
    (when (derived-mode-p 'treemacs-mode)
      (my/treemacs-set-font)
      (my/treemacs-no-scroll-bars))))

(provide 'init-treemacs)

;;; init-treemacs.el ends here
