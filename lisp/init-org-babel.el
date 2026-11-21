;;; init-org-babel.el --- Local Org Babel execution -*- lexical-binding: t; -*-

(require 'init-org)

(my/org-add-tool-bin "tools/graphviz/bin")
(my/org-add-tool-bin "tools/java/bin")

(setenv "PLANTUML_SECURITY_PROFILE" "SANDBOX")

(defun my/org-babel-preview-result ()
  "Refresh a Babel image result when Org link previews are enabled."
  (when (and org-startup-with-link-previews
             (display-graphic-p)
             (org-in-src-block-p))
    (when-let* ((info (org-babel-get-src-block-info 'light))
                (file (cdr (assq :file (nth 2 info))))
                ((string-match-p (image-file-name-regexp) file))
                (result (org-babel-where-is-src-block-result)))
      (save-excursion
        (goto-char result)
        (forward-line 1)
        (org-link-preview-region nil t (point) (org-babel-result-end))))))

(defun my/org-babel-setup-previews ()
  "Refresh inline image results in this Org buffer."
  (add-hook 'org-babel-after-execute-hook #'my/org-babel-preview-result nil t))

(add-hook 'org-mode-hook #'my/org-babel-setup-previews)

(with-eval-after-load 'org
  (setq org-plantuml-jar-path
        (expand-file-name "tools/plantuml/plantuml.jar" user-emacs-directory)
        org-plantuml-exec-mode 'jar
        org-plantuml-args '("-headless" "-charset" "UTF-8")
        org-babel-python-command-session "python")
  (let ((languages (copy-tree org-babel-load-languages)))
    (dolist (language '(dot plantuml python sql))
      (setf (alist-get language languages) t))
    (org-babel-do-load-languages 'org-babel-load-languages languages)))

(provide 'init-org-babel)
;;; init-org-babel.el ends here
