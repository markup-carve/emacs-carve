;;; carve-lsp.el --- Language server support for Carve markup -*- lexical-binding: t; -*-

;; Author: markup-carve
;; Maintainer: markup-carve
;; Version: 0.1.2
;; Package-Requires: ((emacs "27.1"))
;; Keywords: languages
;; URL: https://github.com/markup-carve/emacs-carve
;; SPDX-License-Identifier: MIT

;;; Commentary:

;; Optional integration with markup-carve/carve-lsp.
;;
;; `carve-mode' is font-lock: a set of per-line regular expressions with no
;; container state.  Its own commentary says so, and names the two places that
;; costs something around composite figures.  Those are not fixable with a
;; better regexp - they need a real parse of the document, and that is what the
;; language server has.
;;
;; What it adds over highlighting is the class of question no font-lock rule can
;; answer: which `[^note]' has no definition, which `</#id>' cross-reference
;; points at nothing, and that `**bold**' is a Markdown habit that renders in
;; Carve as two literal asterisks around bold text.  Plus rename across a
;; workspace, go-to-definition, completion and formatting.
;;
;; Install the server:
;;
;;     npm i -g @markup-carve/carve-lsp
;;
;; Then opt in:
;;
;;     (require 'carve-lsp)
;;     (carve-lsp-setup)
;;
;; Nothing starts on its own.  Loading this file registers no hook and starts no
;; process: attaching a language server spawns one, and that is the reader's
;; decision rather than a side effect of installing a major mode.  If the server
;; is not on `exec-path', `carve-lsp-setup' is a no-op that RETURNS a reason
;; instead of signalling, so an init file that calls it stays loadable on a
;; machine that has never installed it.
;;
;; Both clients are supported, because Emacs has two and neither is the obvious
;; default across versions: eglot (built in from Emacs 29, a package before
;; that) and lsp-mode.  `carve-lsp-setup' registers with whichever is present.

;;; Code:

(require 'carve-mode)
(require 'seq)

;; Declared, not required: both belong to clients that may not be installed.
;; Without these the byte-compiler warns about a free variable on a branch that
;; only ever runs when the client that defines it is loaded.
(defvar eglot-server-programs)
(defvar lsp-language-id-configuration)

(defgroup carve-lsp nil
  "Language server support for Carve markup."
  :group 'carve
  :prefix "carve-lsp-")

(defcustom carve-lsp-command '("carve-lsp" "--stdio")
  "Command that starts the Carve language server.
The npm package `@markup-carve/carve-lsp' installs a binary named
exactly `carve-lsp'; `--stdio' is how it speaks."
  :type '(repeat string)
  :group 'carve-lsp)

(defcustom carve-lsp-settings nil
  "Settings sent to the server under the `carve' section.
An alist, serialized as JSON.  See the carve-lsp README for the keys -
`formatter', `severities', and the include-resolution options."
  :type '(alist :key-type symbol :value-type sexp)
  :group 'carve-lsp)

(defcustom carve-lsp-autostart t
  "Whether `carve-lsp-setup' also starts the server in Carve buffers.
When nil, the server is registered with the client but only starts when
you ask for it (`eglot' / `lsp' by hand).  Registration alone is enough
for a reader who wants the server available but not automatic."
  :type 'boolean
  :group 'carve-lsp)

(defun carve-lsp-available-p ()
  "Return non-nil when the Carve language server is installed."
  (and carve-lsp-command
       (stringp (car carve-lsp-command))
       (executable-find (car carve-lsp-command))))

(defun carve-lsp--project-root (&optional dir)
  "Return the workspace root for DIR, or nil.
Rename, find-references and go-to-definition are workspace-wide in
carve-lsp - renaming a heading id updates every cross-reference that
points at it - so the root is what decides how much of the tree those
commands can see.  A server rooted at the file's own directory silently
narrows them to one folder."
  (let ((start (or dir default-directory)))
    (or (locate-dominating-file start ".git")
        start)))

(defun carve-lsp--register-eglot ()
  "Register the server with eglot.  Return non-nil on success."
  (when (require 'eglot nil t)
    (let ((entry (cons 'carve-mode carve-lsp-command)))
      ;; Replace rather than push: calling setup twice must not leave two
      ;; entries, and a reader who has customized `carve-lsp-command' between
      ;; calls should get the new command rather than the first one to win.
      (when (boundp 'eglot-server-programs)
        (setq eglot-server-programs
              (cons entry
                    (seq-remove (lambda (pair) (eq (car-safe pair) 'carve-mode))
                                eglot-server-programs)))
        t))))

(defun carve-lsp--register-lsp-mode ()
  "Register the server with lsp-mode.  Return non-nil on success."
  (when (and (require 'lsp-mode nil t)
             (fboundp 'lsp-register-client)
             (fboundp 'make-lsp-client)
             (fboundp 'lsp-stdio-connection)
             (fboundp 'lsp-activate-on))
    (when (fboundp 'lsp-register-custom-settings)
      (ignore-errors (lsp-register-custom-settings nil)))
    (add-to-list 'lsp-language-id-configuration '(carve-mode . "carve"))
    (lsp-register-client
     (make-lsp-client
      :new-connection (lsp-stdio-connection (lambda () carve-lsp-command))
      :activation-fn (lsp-activate-on "carve")
      :server-id 'carve-lsp
      :initialization-options (lambda () carve-lsp-settings)))
    t))

;;;###autoload
(defun carve-lsp-setup ()
  "Set up the Carve language server.

Returns the client it registered with - the symbol `eglot' or
`lsp-mode' - or nil plus a reason string when nothing was set up.
Returning rather than signalling is deliberate: an init file that calls
this must stay loadable on a machine where the server, or either client,
is absent."
  (interactive)
  (cond
   ((not (carve-lsp-available-p))
    (let ((reason (format "%s is not on exec-path; install it with `npm i -g @markup-carve/carve-lsp'"
                          (or (car carve-lsp-command) "carve-lsp"))))
      (when (called-interactively-p 'interactive)
        (message "carve-lsp: %s" reason))
      (list nil reason)))
   (t
    (let ((client (cond ((carve-lsp--register-eglot) 'eglot)
                        ((carve-lsp--register-lsp-mode) 'lsp-mode)
                        (t nil))))
      (cond
       ((null client)
        (let ((reason "neither eglot nor lsp-mode is available"))
          (when (called-interactively-p 'interactive)
            (message "carve-lsp: %s" reason))
          (list nil reason)))
       (t
        (when carve-lsp-autostart
          (add-hook 'carve-mode-hook #'carve-lsp--maybe-start))
        (when (called-interactively-p 'interactive)
          (message "carve-lsp: registered with %s" client))
        client))))))

(defun carve-lsp--maybe-start ()
  "Start the language server for the current buffer, if one can be.
Attached to `carve-mode-hook' by `carve-lsp-setup' when
`carve-lsp-autostart' is non-nil.  Silent on failure: a buffer that
cannot reach a server should still be editable."
  (when (carve-lsp-available-p)
    (let ((default-directory (carve-lsp--project-root)))
      (ignore-errors
        (cond ((fboundp 'eglot-ensure) (eglot-ensure))
              ((fboundp 'lsp-deferred) (lsp-deferred)))))))

(provide 'carve-lsp)

;;; carve-lsp.el ends here
