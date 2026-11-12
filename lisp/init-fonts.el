;;; init-fonts.el --- Font setup -*- lexical-binding: t; -*-

(defun my/setup-fonts (&optional frame)
  "Select an available programming font."
  (with-selected-frame (or frame (selected-frame))
    (when (display-graphic-p)
      (let ((family
             (cond
              ((find-font (font-spec :family "Iosevka"))
               "Iosevka")
              ((find-font (font-spec :family "JetBrains Mono"))
               "JetBrains Mono")
              ((find-font (font-spec :family "Cascadia Code"))
               "Cascadia Code"))))
        (when family
          (set-face-attribute
           'default nil
           :family family
           :height 140)
          (set-face-attribute
           'fixed-pitch nil
           :family family
           :height 140))))))

(my/setup-fonts)
(add-hook 'after-make-frame-functions #'my/setup-fonts)

(provide 'init-fonts)
