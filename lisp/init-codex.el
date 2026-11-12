;;; init-codex.el --- Native Codex IDE and Emacs MCP bridge -*- lexical-binding: t; -*-

(require 'server)

;;; Initialize Codex IDE before configuring its components

(require 'codex-ide)

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

;; Let the MCP bridge connect to this Emacs through emacsclient.
(unless (server-running-p)
  (server-start))

(require 'codex-ide-mcp-bridge)

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

;; Use the package's authenticated Emacs server connection and MCP launcher.
;; Codex passes bridge configuration when starting its next app-server process.
(codex-ide-mcp-bridge-enable)

;;; Emacs MCP bridge: no per-tool approval prompts

(setq codex-ide-emacs-bridge-require-approval nil)

;;; TCP server file for Codex MCP bridge - это пиздец, без него клиент не видит сервер

(setenv "EMACS_SERVER_FILE"
        (expand-file-name server-name server-auth-dir))

(setq codex-ide-emacs-bridge-server-name
      (expand-file-name server-name server-auth-dir))

(provide 'init-codex)
;;; init-codex.el ends here
