;;; init-toolbar.el --- Monochrome toolbar -*- lexical-binding: t; -*-

(require 'tool-bar)
(require 'cl-lib)

(defconst my/toolbar-icons
  '("new" "open" "diropen" "close"
    "save" "undo" "cut" "copy"
    "paste" "search")
  "Standard toolbar icons to replace with monochrome versions.")

(defconst my/toolbar-labels
  '((open-directory . "Dir")
    (kill-buffer . "Close")
    (undo . "Undo")
    (cut . "Cut")
    (copy . "Copy")
    (paste . "Paste"))
  "Explicit labels for standard buttons that lack them.")

(defun my/toolbar-apply ()
  "Set monochrome PBM icons and short labels for the standard toolbar."
  (interactive)

  (let* ((fg (face-foreground 'tool-bar nil t))
         (bg (face-background 'tool-bar nil t))
         (map (default-value 'tool-bar-map))
         (changes nil))

    ;; Collect modified menu items without changing their commands.
    (map-keymap
     (lambda (key binding)
       (when (and (consp binding)
                  (eq (car binding) 'menu-item)
                  (memq :image binding))
         (let* ((label (alist-get key my/toolbar-labels))
                (original (prin1-to-string
                           (cadr (memq :image binding))))
                (icon
                 (cl-find-if
                  (lambda (name)
                    (string-match-p
                     (regexp-quote (concat name ".pbm"))
                     original))
                  my/toolbar-icons))
                (file
                 (when icon
                   (locate-file
                    (concat icon ".pbm")
                    (append image-load-path load-path)))))

           (when (or label file)
             (let ((item (copy-tree binding)))
               (when label
                 (setcdr (nthcdr 2 item)
                         (plist-put (nthcdr 3 item) :label label)))
               (when file
                 (setcar
                  (cdr (memq :image item))
                  `(find-image
                    '((:type pbm
                       :file ,file
                       :foreground ,fg
                       :background ,bg))
                    t)))
               (push (cons key item) changes))))))

     map)

    ;; Apply changes while keeping the original commands.
    (dolist (change changes)
      (define-key map
                  (vector (car change))
                  (cdr change)))

    ;; Refresh toolbar images.
    (when (fboundp 'tool-bar--flush-cache)
      (tool-bar--flush-cache))

    (force-mode-line-update t)

    (when (called-interactively-p 'interactive)
      (message "Updated %d toolbar buttons" (length changes)))))

(defun my/toolbar-setup ()
  "Configure a dark monochrome toolbar."
  (when (display-graphic-p)

    (tool-bar-mode 1)

    (set-face-attribute
     'tool-bar nil
     :foreground "#cdd6f4"
     :background "#1e2030"
     :box nil)

    (my/toolbar-apply)))

;; Apply after the theme and toolbar are initialized.
(my/toolbar-setup)


;;; Additional toolbar commands

(defun my/toolbar-add-button (key command icon label help)
  "Add a monochrome toolbar button.
KEY identifies it, COMMAND is its action, and ICON is a standard Emacs PBM
icon.  LABEL is the short visible caption and HELP is the tooltip."
  (when-let* ((file (locate-file
                     (concat icon ".pbm")
                     (append image-load-path load-path))))
    (let ((fg (face-foreground 'tool-bar nil t))
          (bg (face-background 'tool-bar nil t)))
      (define-key-after
        (default-value 'tool-bar-map)
        (vector key)
        `(menu-item
          ,label ,command
          :label ,label
          :help ,help
          :image (find-image
                  '((:type pbm
                     :file ,file
                     :foreground ,fg
                     :background ,bg))
                  t))))))

;; M-:  Evaluate Elisp.
(my/toolbar-add-button
 'my-eval 'eval-expression
 "preferences" "Eval" "M-:  Evaluate expression")

;; M-x  Execute command.
(my/toolbar-add-button
 'my-command 'execute-extended-command
 "help" "Command" "M-x  Execute command")

;; Close the selected window, not the buffer.
(my/toolbar-add-button
 'my-close-window 'delete-window
 "close" "Close Window" "Close current window")

;; Toggle Treemacs.
(my/toolbar-add-button
 'my-treemacs 'treemacs
 "diropen" "Treemacs" "Show / Hide Treemacs")

;; Toggle the Imenu outline sidebar.
(my/toolbar-add-button
 'my-outline 'imenu-list-smart-toggle
 "index" "Outline" "Структура файла (C-c o)")

;; Refresh toolbar.
(when (fboundp 'tool-bar--flush-cache)
  (tool-bar--flush-cache))

(provide 'init-toolbar)
;;; init-toolbar.el ends here
