;;; init-org-drawing.el --- Drawing and mind maps in Org -*- lexical-binding: t; -*-

(use-package edraw
  :ensure nil
  :vc (:url "https://github.com/misohena/el-easydraw.git"
       :main-file "edraw.el" :rev :newest)
  :after org
  :config
  (require 'edraw-org)
  (edraw-org-setup-default))

(use-package org-mindmap
  :ensure nil
  :vc (:url "https://github.com/krvkir/org-mindmap.git" :rev :newest)
  :hook (org-mode . org-mindmap-mode)
  :bind (:map org-mindmap-mode-map
         ("C-c m c" . org-mindmap-insert-child)
         ("C-c m s" . org-mindmap-insert-sibling)
         ("C-c m d" . org-mindmap-delete-node)
         ("C-c m v" . org-mindmap-switch-layout)))

(provide 'init-org-drawing)
;;; init-org-drawing.el ends here
