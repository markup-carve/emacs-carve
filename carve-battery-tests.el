;;; carve-battery-tests.el --- Shared block battery for carve-mode  -*- lexical-binding: t; -*-

;; The block shapes every Carve grammar must classify the same way.
;;
;; Six copies of these block rules exist across the Carve editor integrations,
;; and the same rule has been fixed across all of them twice.  The second time,
;; one copy silently missed it and only a hand comparison caught it, which is
;; not a control.
;;
;; tests/lib/block-battery.json is carve-grammars' table, vendored.  This file
;; runs it against carve-mode by mapping the faces onto the classifications the
;; table uses.  carve-mode-tests.el stays: it pins Emacs-specific detail the
;; battery cannot express, while the battery pins what every grammar must agree
;; on.

;;; Code:

(require 'ert)
(require 'carve-mode)

(defconst carve-battery--file
  (expand-file-name "tests/lib/block-battery.json"
                    (file-name-directory (or load-file-name buffer-file-name)))
  "The vendored copy of carve-grammars' block battery.")

(defun carve-battery--classify (face)
  "Reduce FACE to the block classification the battery speaks.

carve-mode paints several constructs with `carve-markup-face', so a face
alone cannot separate a heading from a caption.  Only the NEGATIVE shapes
need that separation to be absent, and every positive shape in the table
maps to a face this mode does set, so the reduction is: which family, or
nil for none."
  (cond
   ((null face) "none")
   ((eq face 'carve-list-marker-face) "list")
   ((eq face 'carve-blockquote-face) "quote")
   ((eq face 'carve-markup-face) "markup")
   (t (format "%s" face))))

(defun carve-battery--face-at-start (src)
  "Fontify SRC as Carve and return the face at column 1 of its first line.

A trailing line keeps the shape off the last line of the buffer, where a
rule anchored at end-of-line behaves differently."
  (with-temp-buffer
    (insert src "\n" "after" "\n")
    (carve-mode)
    (font-lock-ensure)
    (goto-char (point-min))
    (get-text-property (point) 'face)))

(defun carve-battery--shapes ()
  "Read the vendored battery, returning a list of (SRC WANT WHY)."
  (should (file-readable-p carve-battery--file))
  (let* ((json (with-temp-buffer
                 (insert-file-contents carve-battery--file)
                 (json-parse-string (buffer-string)
                                    :object-type 'alist
                                    :array-type 'list)))
         (shapes (alist-get 'shapes json)))
    (should (>= (length shapes) 25))
    (mapcar (lambda (shape)
              (list (alist-get 'src shape)
                    (alist-get 'want shape)
                    (alist-get 'why shape)))
            shapes)))

(ert-deftest carve-battery-agrees-with-the-shared-table ()
  "Every shape in the shared battery classifies the way carve-rs renders it.

Only what the table calls `none' is asserted strictly.  carve-mode paints
headings, captions and definition terms with one face, so a positive shape
can only be checked as `some marker face was applied' - which is still
worth having, because it catches a rule that stops matching entirely."
  (let ((failures '()))
    (dolist (shape (carve-battery--shapes))
      (let* ((src (nth 0 shape))
             (want (nth 1 shape))
             (why (nth 2 shape))
             (got (carve-battery--classify (carve-battery--face-at-start src))))
        (cond
         ((string= want "none")
          (unless (string= got "none")
            (push (format "  %S: want=none got=%s%s" src got
                          (if why (format "   (%s)" why) ""))
                  failures)))
         (t
          (when (string= got "none")
            (push (format "  %S: want=%s but nothing was fontified%s" src want
                          (if why (format "   (%s)" why) ""))
                  failures))))))
    (should (equal
             (nreverse failures)
             '()))))

(provide 'carve-battery-tests)
;;; carve-battery-tests.el ends here
