;;; carve-lsp-tests.el --- Tests for carve-lsp -*- lexical-binding: t; -*-

;; SPDX-License-Identifier: MIT

;;; Commentary:

;; ERT tests for `carve-lsp'.
;;
;; Loading is not behaviour.  A file that byte-compiles and registers nothing
;; would satisfy a `require' check, so these drive `carve-lsp-setup' and assert
;; on what it actually did to the client's registry - and, for the case that
;; matters most, on what it did NOT do when the server is absent.
;;
;; No server is ever started here.  The executable is faked with a script on
;; `exec-path', which is enough to exercise every decision `carve-lsp-setup'
;; makes; actually spawning a language server would make the suite depend on
;; npm.
;;
;;   emacs -Q --batch -l ert -l carve-mode.el -l carve-lsp.el \
;;     -l carve-lsp-tests.el -f ert-run-tests-batch-and-exit

;;; Code:

(require 'ert)
(require 'carve-mode)
(require 'carve-lsp)

(defvar carve-lsp-test--fake-dir nil
  "Directory holding a fake `carve-lsp' executable, created on demand.")

(defun carve-lsp-test--fake-server ()
  "Return a directory containing an executable named `carve-lsp'."
  (or carve-lsp-test--fake-dir
      (let* ((dir (make-temp-file "carve-lsp-test" t))
             (bin (expand-file-name "carve-lsp" dir)))
        (with-temp-file bin (insert "#!/bin/sh\nexit 0\n"))
        (set-file-modes bin #o755)
        (setq carve-lsp-test--fake-dir dir))))

(defmacro carve-lsp-test--with-server (&rest body)
  "Run BODY with a fake `carve-lsp' on `exec-path'."
  (declare (indent 0))
  `(let* ((dir (carve-lsp-test--fake-server))
          (exec-path (cons dir exec-path))
          (process-environment
           (cons (concat "PATH=" dir ":" (getenv "PATH")) process-environment)))
     ,@body))

(ert-deftest carve-lsp-absent-server-is-a-no-op-with-a-reason ()
  "A missing server must not signal, and must not register anything.
An init file calling `carve-lsp-setup' has to stay loadable on a machine
that never installed the server - and every .crv buffer opened there must
not produce an error."
  (let ((carve-lsp-command (list "carve-lsp-definitely-absent" "--stdio"))
        (eglot-server-programs (list (cons 'text-mode '("unrelated")))))
    (let ((result (carve-lsp-setup)))
      (should (listp result))
      (should (null (car result)))
      (should (stringp (nth 1 result)))
      (should (string-match-p "exec-path" (nth 1 result))))
    ;; The registry is untouched, not merely "no carve entry added".
    (should (equal eglot-server-programs (list (cons 'text-mode '("unrelated")))))
    (should-not (memq #'carve-lsp--maybe-start carve-mode-hook))))

(ert-deftest carve-lsp-available-p-follows-exec-path ()
  (let ((carve-lsp-command (list "carve-lsp-definitely-absent")))
    (should-not (carve-lsp-available-p)))
  (carve-lsp-test--with-server
    (let ((carve-lsp-command (list "carve-lsp" "--stdio")))
      (should (carve-lsp-available-p)))))

(ert-deftest carve-lsp-registers-the-command-with-eglot ()
  "The entry must name carve-mode and the configured command."
  (skip-unless (require 'eglot nil t))
  (carve-lsp-test--with-server
    (let ((carve-lsp-command (list "carve-lsp" "--stdio"))
          (eglot-server-programs nil)
          (carve-mode-hook nil))
      (should (eq 'eglot (carve-lsp-setup)))
      (let ((entry (assq 'carve-mode eglot-server-programs)))
        (should entry)
        (should (equal (cdr entry) (list "carve-lsp" "--stdio")))))))

(ert-deftest carve-lsp-setup-twice-leaves-one-entry ()
  "Calling setup again must replace its entry, not add a second.
A reader who re-evaluates their init file, or who changes
`carve-lsp-command' and calls setup again, should end up with the new
command rather than with the first one still winning."
  (skip-unless (require 'eglot nil t))
  (carve-lsp-test--with-server
    (let ((carve-lsp-command (list "carve-lsp" "--stdio"))
          (eglot-server-programs nil)
          (carve-mode-hook nil))
      (carve-lsp-setup)
      (let ((carve-lsp-command (list "carve-lsp" "--socket")))
        (carve-lsp-setup)
        (should (= 1 (length (seq-filter (lambda (pair) (eq (car-safe pair) 'carve-mode))
                                         eglot-server-programs))))
        (should (equal (cdr (assq 'carve-mode eglot-server-programs))
                       (list "carve-lsp" "--socket")))))))

(ert-deftest carve-lsp-autostart-nil-registers-without-hooking ()
  "Registration and autostart are separate choices."
  (skip-unless (require 'eglot nil t))
  (carve-lsp-test--with-server
    (let ((carve-lsp-command (list "carve-lsp" "--stdio"))
          (eglot-server-programs nil)
          (carve-mode-hook nil)
          (carve-lsp-autostart nil))
      (should (eq 'eglot (carve-lsp-setup)))
      (should (assq 'carve-mode eglot-server-programs))
      (should-not (memq #'carve-lsp--maybe-start carve-mode-hook)))))

(ert-deftest carve-lsp-autostart-t-hooks-carve-mode ()
  (skip-unless (require 'eglot nil t))
  (carve-lsp-test--with-server
    (let ((carve-lsp-command (list "carve-lsp" "--stdio"))
          (eglot-server-programs nil)
          (carve-mode-hook nil)
          (carve-lsp-autostart t))
      (carve-lsp-setup)
      (should (memq #'carve-lsp--maybe-start carve-mode-hook)))))

(ert-deftest carve-lsp-project-root-prefers-the-git-root ()
  "Workspace-wide rename is only workspace-wide if the root is the project.
A root at the file's own directory would silently narrow rename and
find-references to one folder, which is the failure this resolves."
  (let* ((root (make-temp-file "carve-lsp-root" t))
         (nested (expand-file-name "docs/deep" root)))
    (make-directory (expand-file-name ".git" root) t)
    (make-directory nested t)
    (should (equal (file-truename (carve-lsp--project-root nested))
                   (file-truename (file-name-as-directory root))))))

(ert-deftest carve-lsp-project-root-falls-back-to-the-directory ()
  "Outside a project there is still a root: the file's own directory."
  (let ((loose (make-temp-file "carve-lsp-loose" t)))
    (should (carve-lsp--project-root loose))))

(ert-deftest carve-lsp-maybe-start-is-silent-without-a-server ()
  "A buffer that cannot reach a server must still open."
  (let ((carve-lsp-command (list "carve-lsp-definitely-absent")))
    (with-temp-buffer
      (carve-mode)
      (should-not (carve-lsp--maybe-start)))))

(provide 'carve-lsp-tests)

;;; carve-lsp-tests.el ends here
