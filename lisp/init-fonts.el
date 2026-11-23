;;; init-fonts.el --- Font setup -*- lexical-binding: t; -*-

(require 'face-remap)
(require 'seq)

(defconst my/font-height 120
  "Base text height in tenths of a point.")

(defun my/first-available-font (families)
  "Return the first available font family in FAMILIES."
  (seq-find (lambda (family) (find-font (font-spec :family family)))
            families))

(defun my/setup-fonts (&optional frame)
  "Set the base size and preferred programming font on a graphical frame."
  (with-selected-frame (or frame (selected-frame))
    (when (display-graphic-p)
      (let ((family (my/first-available-font '("Iosevka Term" "Fira Code"))))
        (dolist (face '(default fixed-pitch))
          (apply #'set-face-attribute face nil :height my/font-height
                 (when family (list :family family))))))))

(defvar-local my/treemacs-font-cookie nil
  "Face remapping cookie for the Treemacs font.")

(defun my/treemacs-set-font ()
  "Choose the Treemacs font family and inherit the base text height."
  (when my/treemacs-font-cookie
    (face-remap-remove-relative my/treemacs-font-cookie)
    (setq my/treemacs-font-cookie nil))
  (when (display-graphic-p)
    (when-let* ((family (my/first-available-font '("Calibri" "PT Sans Narrow"))))
      (setq my/treemacs-font-cookie
            (face-remap-add-relative 'default :family family)))))

(defvar shr-use-fonts)

(defun my/python-console-fonts ()
  "Use the console's monospaced font when rendering HTML."
  (setq-local shr-use-fonts nil))

(my/setup-fonts)
(add-hook 'after-make-frame-functions #'my/setup-fonts)
(add-hook 'treemacs-mode-hook #'my/treemacs-set-font)

(dolist (buffer (buffer-list))
  (with-current-buffer buffer
    (when (derived-mode-p 'treemacs-mode)
      (my/treemacs-set-font))))

(provide 'init-fonts)
