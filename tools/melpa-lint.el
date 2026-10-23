;;; melpa-lint.el --- Run package-lint and checkdoc the way MELPA does -*- lexical-binding: t; -*-

;;; Commentary:

;; `emacs -Q --batch -l tools/melpa-lint.el'
;; Installs package-lint into a throwaway directory, lints the package files and
;; runs checkdoc over every .el file.  Exits non-zero on any finding.

;;; Code:

(require 'package)
(require 'checkdoc)

(setq package-user-dir (make-temp-file "carve-lint-elpa" t))
(setq package-archives '(("melpa" . "https://melpa.org/packages/")))
(package-initialize)
(package-refresh-contents)
(package-install 'package-lint)
(require 'package-lint)

(defvar carve-lint--failed nil)

(let ((package-lint-main-file "carve-mode.el")
      (files '("carve-mode.el" "carve-lsp.el")))
  (dolist (file files)
    (with-current-buffer (find-file-noselect file)
      (dolist (issue (package-lint-buffer))
        (setq carve-lint--failed t)
        (message "%s:%d:%d: %s: %s" file (nth 0 issue) (nth 1 issue)
                 (nth 2 issue) (nth 3 issue))))))

;; Not `checkdoc-file': it rebinds the diagnostic buffer to its own.
(let ((checkdoc-diagnostic-buffer "*carve-checkdoc*"))
  (dolist (file (directory-files "." nil "\\.el\\'"))
    (with-current-buffer (find-file-noselect file)
      (checkdoc-current-buffer t)))
  (with-current-buffer (get-buffer-create checkdoc-diagnostic-buffer)
    (goto-char (point-min))
    (when (re-search-forward "^[^ \n]+\\.el:[0-9]+: " nil t)
      (setq carve-lint--failed t)
      (message "%s" (buffer-string)))))

(kill-emacs (if carve-lint--failed 1 0))

;;; melpa-lint.el ends here
