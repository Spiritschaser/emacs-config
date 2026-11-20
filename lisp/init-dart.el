;;; init-dart.el --- Dart editing and Flutter Web -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'comint)
(require 'easymenu)
(require 'init-lsp)
(require 'project)

(defun my/dart-executable ()
  "Find Dart on PATH, preferring Flutter's native Dart over its batch wrapper."
  (let ((dart (executable-find "dart"))
        (flutter (executable-find "flutter")))
    (or (and dart (not (string-suffix-p ".bat" dart t)) dart)
        (when-let* ((launcher (or dart flutter))
                    (native (expand-file-name
                             (if (eq system-type 'windows-nt)
                                 "cache/dart-sdk/bin/dart.exe"
                               "cache/dart-sdk/bin/dart")
                             (file-name-directory launcher))))
          (and (file-executable-p native) native))
        dart)))

(defun my/dart-eglot-contact (_interactive)
  "Return the Dart Analysis Server command for Eglot."
  (list (or (my/dart-executable) (user-error "Dart SDK not found on PATH"))
        "language-server" "--client-id=emacs.eglot-dart"))

(add-to-list 'eglot-server-programs
             '(dart-mode . my/dart-eglot-contact))

(defun my/dart-pubspec-root (directory)
  "Return the nearest Dart package root above local DIRECTORY."
  (unless (file-remote-p directory)
    (when-let* ((root (locate-dominating-file directory "pubspec.yaml")))
      (file-name-as-directory (expand-file-name root)))))

(defun my/dart-project-find (directory)
  "Recognize a Dart package above DIRECTORY while editing Dart."
  (when (derived-mode-p 'dart-mode)
    (when-let* ((root (my/dart-pubspec-root directory)))
      (cons 'dart-package root))))

(cl-defmethod project-root ((project (head dart-package)))
  (cdr project))

(add-hook 'project-find-functions #'my/dart-project-find)

(defun my/dart-setup ()
  "Start Eglot for local Dart files when the SDK is available."
  (when (and buffer-file-name
             (not (file-remote-p buffer-file-name))
             (my/dart-executable))
    (eglot-ensure)))

(use-package dart-mode
  :ensure t
  :mode "\\.dart\\'"
  :hook (dart-mode . my/dart-setup))

(defgroup my/flutter-web nil "Flutter Web development in Emacs." :group 'tools)

(defcustom my/flutter-web-device (if (eq system-type 'windows-nt) "edge" "chrome")
  "Flutter device identifier used to run and debug web apps."
  :type 'string)

(define-derived-mode my/flutter-web-mode comint-mode "Flutter Web"
  "Show output and accept commands from a Flutter Web run."
  (setq-local comint-prompt-read-only t)
  (add-hook 'comint-output-filter-functions #'comint-truncate-buffer nil t))

(defun my/flutter-web-root ()
  "Return the current Flutter package root if it has a web entry point."
  (when-let* ((root (my/dart-pubspec-root default-directory))
              ((file-readable-p (expand-file-name "web/index.html" root)))
              (pubspec (expand-file-name "pubspec.yaml" root))
              ((file-readable-p pubspec)))
    (with-temp-buffer
      (insert-file-contents pubspec)
      (when (re-search-forward
             "\\_<sdk[ \t]*:[ \t]*['\"]?flutter['\"]?[ \t]*\\(?:[#,}]\\|$\\)"
             nil t)
        (file-name-as-directory (file-truename root))))))

(defun my/flutter-web-buffer-name (root)
  "Return the dedicated Flutter Web buffer name for ROOT."
  (format "*Flutter Web: %s*" (abbreviate-file-name (directory-file-name root))))

(defun my/flutter-web-process ()
  "Return the live Flutter Web process for the current project."
  (let ((buffer (if (derived-mode-p 'my/flutter-web-mode)
                    (current-buffer)
                  (when-let* ((root (my/flutter-web-root)))
                    (get-buffer (my/flutter-web-buffer-name root))))))
    (and buffer (comint-check-proc buffer) (get-buffer-process buffer))))

(defun my/flutter-web-run ()
  "Run the current Flutter project in the browser and show its console."
  (interactive)
  (let* ((root (or (my/flutter-web-root)
                   (user-error "Open a Flutter project with web support")))
         (default-directory root)
         (flutter (or (executable-find "flutter")
                      (user-error "Flutter SDK not found on PATH")))
         (buffer (get-buffer-create (my/flutter-web-buffer-name root))))
    (unless (comint-check-proc buffer)
      (save-some-buffers nil (lambda ()
                              (and buffer-file-name
                                   (file-in-directory-p buffer-file-name root))))
      (let ((process-connection-type nil))
        (with-current-buffer buffer
          (setq default-directory root)
          (my/flutter-web-mode))
        (make-comint-in-buffer "Flutter Web" buffer flutter nil
                               "run" "-d" my/flutter-web-device)))
    (display-buffer buffer)))

(defun my/flutter-web-reload ()
  "Hot reload the running Flutter Web application."
  (interactive)
  (let ((process (or (my/flutter-web-process)
                     (user-error "Flutter Web is not running for this project"))))
    (let ((root (with-current-buffer (process-buffer process) default-directory)))
      (save-some-buffers nil (lambda ()
                              (and buffer-file-name
                                   (file-in-directory-p buffer-file-name root)))))
    (comint-send-string process "r")))

(defun my/flutter-web-stop ()
  "Ask the running Flutter Web application to quit."
  (interactive)
  (comint-send-string (or (my/flutter-web-process)
                          (user-error "Flutter Web is not running for this project"))
                      "q"))

(defun my/dart-menu-visible-p ()
  "Return non-nil in a Dart source, Flutter console or package manifest."
  (or (derived-mode-p 'dart-mode 'my/flutter-web-mode)
      (and buffer-file-name
           (equal (file-name-nondirectory buffer-file-name) "pubspec.yaml"))))

(defvar my/dart-menu-map
  (easy-menu-create-menu
   "Dart / Flutter"
   '(["Запустить Flutter Web" my/flutter-web-run
      :active (and (my/flutter-web-root) (executable-find "flutter"))]
     ["Горячая перезагрузка" my/flutter-web-reload :active (my/flutter-web-process)]
     ["Остановить Flutter Web" my/flutter-web-stop :active (my/flutter-web-process)]
     "--"
     ["Форматировать Dart" eglot-format-buffer :active (eglot-managed-p)]
     ["Документация" eldoc-doc-buffer :active (eglot-managed-p)]
     ["Перейти к определению" xref-find-definitions :active (eglot-managed-p)])))

(provide 'init-dart)
;;; init-dart.el ends here
