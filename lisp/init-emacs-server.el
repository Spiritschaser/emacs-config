;;; init-emacs-server.el --- Inspect and recover the Emacs MCP endpoint -*- lexical-binding: t; -*-

(require 'server)
(require 'subr-x)

(defun emacs-server-connection-file ()
  "Return this Emacs server's TCP authentication file or Unix socket path."
  (expand-file-name server-name
                    (if server-use-tcp server-auth-dir server-socket-dir)))

(defun emacs-server-health-data ()
  "Return server diagnostics without exposing the authentication key.
This is a local inspection, not an authenticated end-to-end client probe."
  (let* ((file (emacs-server-connection-file))
         (own (and (processp server-process) (process-live-p server-process)))
         (state (condition-case err (server-running-p server-name)
                  (error (list :error (error-message-string err)))))
         (owner nil)
         (endpoint nil))
    (when (and server-use-tcp (file-readable-p file))
      (with-temp-buffer
        ;; Parse only the header; never include the authentication key in output.
        (insert-file-contents-literally file nil 0 128)
        (when (looking-at "\\([^ \n]+\\) \\([0-9]+\\)")
          (setq endpoint (match-string 1)
                owner (string-to-number (match-string 2))))))
    (list :pid (emacs-pid) :transport (if server-use-tcp 'tcp 'local)
          :file file :file-exists (file-exists-p file)
          :own-server (and own t) :running-state state
          :endpoint endpoint :file-owner-pid owner
          :owner-process (and owner (cdr (assq 'comm (process-attributes owner))))
          :listener (and own (process-contact server-process :local)))))

(defun emacs-server-health ()
  "Display local server diagnostics, without the authentication key."
  (interactive)
  (with-help-window "*Emacs server health*"
    (princ "Emacs server / MCP endpoint\n\n")
    (pp (emacs-server-health-data))
    (princ "\n:other means unknown, not running.\n")
    (princ "Use M-x emacs-server-recover to start this Emacs server.\n")
    (princ "An authenticated MCP call is needed to verify the full connection.\n")))

(defun emacs-server-recover ()
  "Start the MCP endpoint without taking over another Emacs server.
The built-in server handles stale connection cleanup and normal exit cleanup."
  (interactive)
  (require 'codex-ide-mcp-bridge)
  (codex-ide-mcp-bridge-ensure-server)
  (when (called-interactively-p 'interactive) (emacs-server-health)))

(provide 'init-emacs-server)
;;; init-emacs-server.el ends here
