;;; carve-cli-tests.el --- Tests against a Carve 0.2 `carve' CLI -*- lexical-binding: t; -*-

;;; Commentary:

;; The preview and import commands shell out to the `carve' CLI.  These tests
;; run them against a real one and skip when none is on `exec-path', unless
;; CARVE_REQUIRE_CLI is set: CI builds carve-js `main' at a pinned commit and
;; sets it, so a missing CLI there fails instead of passing silently.

;;; Code:

(require 'ert)
(require 'carve-mode)

(defun carve-cli-tests--skip-unless-cli ()
  "Skip the current test unless a Carve 0.2 CLI is available."
  (let ((version (and (carve--available-p)
                      (car (process-lines carve-command "--version")))))
    (cond
     ((and version (string-prefix-p "0.2" version)) t)
     ((getenv "CARVE_REQUIRE_CLI")
      (ert-fail (format "CARVE_REQUIRE_CLI is set but `%s --version' gave %S"
                        carve-command version)))
     (t (ert-skip "No Carve 0.2 CLI on exec-path")))))

(ert-deftest carve-cli-test-preview-renders-with-the-0.2-engine ()
  "`carve-preview-buffer' renders through the CLI's default `render' command."
  (carve-cli-tests--skip-unless-cli)
  (with-temp-buffer
    (insert "== Section\n\nSome /text/.\n")
    (carve-mode)
    (let ((display-buffer-overriding-action '(display-buffer-no-window)))
      (carve-preview-buffer)))
  (with-current-buffer "*Carve Output*"
    (should (string-match-p "<h2>Section</h2>" (buffer-string)))
    (should (string-match-p "<em>text</em>" (buffer-string)))))

(ert-deftest carve-cli-test-import-runs-the-0.2-import-command ()
  "`carve-import-file' converts Markdown with `carve import --from markdown'."
  (carve-cli-tests--skip-unless-cli)
  (let* ((dir (file-name-as-directory (make-temp-file "carve-cli" t)))
         (src (expand-file-name "doc.md" dir)))
    (unwind-protect
        (progn
          (write-region "# Hello *world*\n" nil src)
          (let ((display-buffer-overriding-action '(display-buffer-no-window)))
            (carve-import-file src))
          (should (equal (buffer-string) "= Hello /world/\n")))
      (dolist (buf (buffer-list))
        (let ((f (buffer-file-name buf)))
          (when (and f (string-prefix-p dir f))
            (kill-buffer buf))))
      (delete-directory dir t))))

(provide 'carve-cli-tests)

;;; carve-cli-tests.el ends here
