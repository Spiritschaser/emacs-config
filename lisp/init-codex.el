;;; init-codex.el --- Native Codex IDE and Emacs MCP bridge -*- lexical-binding: t; -*-

(require 'server)
(require 'package-vc)

;; Its macro must be available while package-vc generates Codex autoloads.
(use-package transient
  :demand t)

;;; GitHub installation and local transport/server patch

(defconst my/codex-ide-revision
  "5eba84dd58ad8609e8f7e8c4159d4aac90b4f303"
  "GitHub revision against which the local patch is maintained.")

;; This name also exists in archives, for a different author's package.
;; Override its VC metadata both for installation and subsequent updates.
(setf (alist-get 'codex-ide package-vc-selected-packages nil nil #'string=)
      '(:url "https://github.com/dgillis/emacs-codex-ide"
        :lisp-dir "."))

(defun my/codex-ide-apply-patch (directory)
  "Apply the maintained patch in DIRECTORY, or recognize it as applied.
Refuse a conflicting or partially applied patch before loading Codex."
  (let ((default-directory (file-name-as-directory directory))
        (patch (expand-file-name
                "patches/codex-ide-emacsclient-server-file.patch"
                user-emacs-directory)))
    (unless (executable-find "git")
      (error "Codex installation requires Git in PATH"))
    (unless (file-readable-p patch)
      (error "Missing Codex patch: %s" patch))
    (with-temp-buffer
      (cond
       ((zerop (call-process "git" nil t nil "apply" "--reverse" "--check" patch))
        'already-applied)
       ((zerop (call-process "git" nil t nil "apply" "--check" patch))
        (erase-buffer)
        (unless (zerop (call-process "git" nil t nil "apply" patch))
          (error "Cannot apply Codex patch: %s" (buffer-string)))
        ;; package-vc compiled the original bridge.  Rebuild it so Emacs
        ;; cannot load that bytecode instead of the patched source.
        (require 'bytecomp)
        (let* ((source (expand-file-name "codex-ide-mcp-bridge.el" directory))
               (compiled (byte-compile-dest-file source)))
          (when (file-exists-p compiled)
            (delete-file compiled))
          (unless (byte-compile-file source)
            (error "Cannot compile patched Codex bridge: %s" source)))
        'applied)
       (t
        (error "Codex patch conflicts with %s; see patches/README.md: %s"
               directory (buffer-string)))))))

(defun my/codex-ide-prepare ()
  "Install the GitHub package if missing and patch it before loading."
  (unless (package-installed-p 'codex-ide)
    (unless package-archive-contents
      (package-refresh-contents))
    ;; Compile native code only after the source has been patched.
    (let ((package-native-compile nil)
          (package-vc-register-as-project nil))
      (package-vc-install
       (cons 'codex-ide
             (alist-get 'codex-ide package-vc-selected-packages nil nil #'string=))
       my/codex-ide-revision)))
  (let* ((descriptor (cadr (assq 'codex-ide package-alist)))
         (directory (and descriptor (package-desc-dir descriptor))))
    (unless (and descriptor (eq (package-desc-kind descriptor) 'vc)
                 (not (alist-get :vc-dir (package-desc-extras descriptor)))
                 (file-directory-p (expand-file-name ".git" directory)))
      (error "Codex must be a direct GitHub checkout in elpa; see patches/README.md"))
    (my/codex-ide-apply-patch directory)))

;; Keep bootstrap errors visible instead of catching them inside use-package.
(my/codex-ide-prepare)

(use-package codex-ide
  :ensure nil
  :demand t)

;;; Codex: выполнять команды и менять файлы без запросов разрешений
;; "never" отключает запросы подтверждения со стороны Codex.
;; "danger-full-access" снимает ограничения песочницы на файловую систему
;; и сеть. Нужны оба параметра: один "never" при сохранённой песочнице
;; не разрешает запрещённые операции — они будут завершаться отказом.
;; Вместе эти настройки дают агенту полный доступ к файлам и выполнению
;; команд с правами текущего пользователя, включая файлы вне проекта.
;; Это настройки по умолчанию; явные настройки отдельной сессии могут
;; их переопределять. Для уже открытых сессий можно применить пресет
;; Danger через M-x codex-ide-apply-config-preset, выбрав область действия.
;; У подключённых сервисов могут оставаться собственные подтверждения.
;; Подтверждения инструментов Emacs управляются отдельно переменной
;; codex-ide-emacs-bridge-require-approval (ниже установлена в nil).
(setq codex-ide-approval-policy "never"
      codex-ide-sandbox-mode "danger-full-access")

(require 'codex-ide-mcp-bridge)
(require 'init-emacs-server)

(setq codex-ide-want-mcp-bridge t
      codex-ide-enable-emacs-tool-bridge t
      codex-ide-emacs-bridge-require-approval t
      codex-ide-emacs-bridge-python-command
      (or (executable-find (if (eq system-type 'windows-nt) "python" "python3"))
          (executable-find "python")
          "python3")
      codex-ide-emacs-bridge-emacsclient-command
      (or (executable-find "emacsclient")
          (let ((client (expand-file-name "emacsclient.exe" invocation-directory)))
            (and (eq system-type 'windows-nt) (file-executable-p client) client))
          "emacsclient"))

;; Configure the endpoint before enabling the bridge.  Windows normally uses
;; TCP; Unix normally uses a local socket, but either may explicitly use TCP.
(setq codex-ide-emacs-bridge-server-name (emacs-server-connection-file))

;; Use the package's authenticated Emacs server connection and MCP launcher.
;; Codex passes bridge configuration when starting its next app-server process.
(codex-ide-mcp-bridge-enable)

;;; Emacs MCP bridge: no per-tool approval prompts

(setq codex-ide-emacs-bridge-require-approval nil)

;; Do not export a TCP endpoint when the transport is a Unix socket.
(when server-use-tcp
  (setenv "EMACS_SERVER_FILE" (emacs-server-connection-file)))

(provide 'init-codex)
;;; init-codex.el ends here
