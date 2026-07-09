;;; carve-mode.el --- Major mode for Carve markup -*- lexical-binding: t; -*-

;; Author: markup-carve
;; Maintainer: markup-carve
;; Version: 0.1.0
;; Package-Requires: ((emacs "27.1"))
;; Keywords: languages
;; URL: https://github.com/markup-carve/emacs-carve
;; SPDX-License-Identifier: MIT

;; Copyright (c) 2026 markup-carve

;; Permission is hereby granted, free of charge, to any person obtaining a copy
;; of this software and associated documentation files (the "Software"), to deal
;; in the Software without restriction, including without limitation the rights
;; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
;; copies of the Software, and to permit persons to whom the Software is
;; furnished to do so, subject to the following conditions:

;; The above copyright notice and this permission notice shall be included in
;; all copies or substantial portions of the Software.

;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
;; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
;; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
;; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
;; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
;; SOFTWARE.

;;; Commentary:

;; Carve is a post-Markdown markup language (see https://github.com/markup-carve/carve).
;; This package provides `carve-mode', a major mode that adds syntax
;; highlighting, a comment syntax, an imenu index of headings, outline support,
;; and an optional preview command for `.crv' files.
;;
;; The font-lock rules cover the core Carve constructs: ATX headings, the
;; mnemonic inline emphasis family (`/italic/', `*bold*', `_underline_',
;; `~strike~', `=highlight=', `^super^', `,,sub,,', and the forced brace
;; forms), inline and raw inline code, links, autolinks, reference links and
;; definitions, images, cross-references, lists (bullet, ordered, task),
;; definition lists, blockquotes, caption lines, fenced and raw code blocks,
;; `%%' comments, fenced divs and admonitions, block-attribute lines, tables,
;; footnotes, math, frontmatter, mentions, tags, and CriticMarkup.
;;
;; Carve is a young language; some constructs (notably the word-boundary rules
;; for bare delimiters) are context sensitive and only approximated here.  See
;; the README for the known limitations.
;;
;; Quick start:
;;
;;   (require 'carve-mode)
;;
;; Files ending in `.crv' then open in `carve-mode'.

;;; Code:

(require 'rx)

(defgroup carve nil
  "Major mode for editing Carve markup."
  :prefix "carve-"
  :group 'text
  :link '(url-link "https://github.com/markup-carve/emacs-carve"))

(defcustom carve-command "carve"
  "Name of (or path to) the Carve command-line tool.
Used by `carve-compile-region' and `carve-preview-buffer' when the
executable is found on variable `exec-path'.  These commands degrade gracefully
when the tool is absent, so the mode never hard-depends on it."
  :type 'string
  :group 'carve)

(defcustom carve-mode-hook nil
  "Hook run when entering `carve-mode'."
  :type 'hook
  :group 'carve)

;;;; Faces

(defface carve-heading-face
  '((t :inherit font-lock-function-name-face :weight bold))
  "Face for Carve ATX headings."
  :group 'carve)

(defface carve-bold-face
  '((t :inherit bold))
  "Face for `*bold*' text."
  :group 'carve)

(defface carve-italic-face
  '((t :inherit italic))
  "Face for `/italic/' text."
  :group 'carve)

(defface carve-underline-face
  '((t :inherit underline))
  "Face for `_underline_' text."
  :group 'carve)

(defface carve-strike-face
  '((t :strike-through t))
  "Face for `~strike~' text."
  :group 'carve)

(defface carve-highlight-face
  '((t :inherit highlight))
  "Face for `=highlight=' text."
  :group 'carve)

(defface carve-code-face
  '((t :inherit font-lock-constant-face))
  "Face for inline and fenced code."
  :group 'carve)

(defface carve-link-text-face
  '((t :inherit font-lock-string-face))
  "Face for link text and image alt text."
  :group 'carve)

(defface carve-url-face
  '((t :inherit link :underline t))
  "Face for link URLs, autolinks, and cross-references."
  :group 'carve)

(defface carve-markup-face
  '((t :inherit shadow))
  "Face for structural markup characters (markers, fences, delimiters)."
  :group 'carve)

(defface carve-list-marker-face
  '((t :inherit font-lock-builtin-face))
  "Face for list item markers."
  :group 'carve)

(defface carve-blockquote-face
  '((t :inherit font-lock-doc-face))
  "Face for blockquote lines."
  :group 'carve)

(defface carve-attribute-face
  '((t :inherit font-lock-preprocessor-face))
  "Face for block-attribute lines and inline attribute blocks."
  :group 'carve)

(defface carve-admonition-face
  '((t :inherit font-lock-keyword-face :weight bold))
  "Face for `:::' div and admonition fences."
  :group 'carve)

(defface carve-table-face
  '((t :inherit font-lock-type-face))
  "Face for table pipes and header markers."
  :group 'carve)

(defface carve-footnote-face
  '((t :inherit font-lock-variable-name-face))
  "Face for footnote references and definitions."
  :group 'carve)

(defface carve-math-face
  '((t :inherit font-lock-constant-face :slant italic))
  "Face for inline and display math."
  :group 'carve)

(defface carve-frontmatter-face
  '((t :inherit font-lock-comment-face))
  "Face for frontmatter delimiters and body."
  :group 'carve)

(defface carve-mention-face
  '((t :inherit font-lock-keyword-face))
  "Face for `@mentions'."
  :group 'carve)

(defface carve-tag-face
  '((t :inherit font-lock-builtin-face))
  "Face for `#tags'."
  :group 'carve)

(defface carve-critic-face
  '((t :inherit font-lock-warning-face))
  "Face for CriticMarkup."
  :group 'carve)

;;;; Helper matchers

(defconst carve--heading-re
  (rx line-start (group (** 1 6 ?#)) (group (one-or-more space))
      (group (one-or-more not-newline)) line-end)
  "Match an ATX heading line (no trailing attribute blocks in Carve).")

(defun carve--fontify-fenced-blocks (limit)
  "Search for a fenced code, raw, or math block between point and LIMIT.
Set match groups so font-lock can color the opener, body, and closer.
Group 1 is the whole opener line, group 2 the body, group 3 the closer."
  (catch 'done
    (while (re-search-forward
            (rx line-start
                (group (or (>= 3 ?`) (>= 3 ?~)))
                (zero-or-more not-newline) line-end)
            limit t)
      (let* ((fence (match-string 1))
             (char (aref fence 0))
             (len (length fence))
             (opener-beg (match-beginning 0))
             (opener-end (save-excursion
                           (goto-char opener-beg)
                           (line-end-position)))
             (closer-re (concat "^" (regexp-quote (make-string len char))
                                (string char) "*[ \t]*$")))
        ;; Find the closing fence (same char, at least as long).
        (if (re-search-forward closer-re limit t)
            (let ((closer-beg (match-beginning 0))
                  (closer-end (match-end 0)))
              ;; Match data: 0=all 1=opener line 2=body 3=closer.
              (set-match-data
               (list opener-beg closer-end
                     opener-beg opener-end                 ; opener line
                     (min (1+ opener-end) closer-beg) closer-beg ; body
                     closer-beg closer-end))               ; closer
              (throw 'done t))
          ;; Unterminated fence: color to LIMIT and stop.
          (set-match-data
           (list opener-beg limit
                 opener-beg (line-end-position) (point) (point)
                 (point) (point)))
          (goto-char limit)
          (throw 'done t))))
    nil))

;;;; Font-lock keywords

(defconst carve-font-lock-keywords
  `(
    ;; Fenced code / raw / math blocks (multi-line; keep early so their
    ;; bodies are not re-fontified by inline rules).
    (carve--fontify-fenced-blocks
     (1 'carve-code-face)
     (2 'carve-code-face keep)
     (3 'carve-code-face))

    ;; Frontmatter at document start: ---, ---toml, ---json ... ---
    (carve--fontify-frontmatter
     (0 'carve-frontmatter-face keep))

    ;; ATX headings.
    (,carve--heading-re
     (1 'carve-markup-face)
     (3 'carve-heading-face))

    ;; Block comment fences %%% ... %%% and line comments %%.
    (,(rx line-start "%%" (zero-or-more not-newline) line-end)
     (0 'font-lock-comment-face))

    ;; Block-attribute line: {#id .class key=val} on its own line.
    (,(rx line-start (zero-or-more space) (group "{" (one-or-more (not (any "}"))) "}")
          (zero-or-more space) line-end)
     (1 'carve-attribute-face))

    ;; Fenced divs and admonitions: ::: type "Title" [Label]
    (,(rx line-start (group (>= 3 ?:))
          (zero-or-more space)
          (group (zero-or-more (any "a-zA-Z0-9_|")))
          (zero-or-more not-newline) line-end)
     (1 'carve-admonition-face)
     (2 'carve-admonition-face))

    ;; Tables: header marker |= |=> |=~ and plain pipes.
    (,(rx (group "|" (opt "=") (opt (any "<>~"))))
     (1 'carve-table-face))

    ;; Blockquote markers and caption lines.
    (,(rx line-start (zero-or-more space) (group ">") )
     (1 'carve-blockquote-face))
    (,(rx line-start (zero-or-more space) (group "^") space)
     (1 'carve-markup-face))

    ;; Task list items: - [ ] / - [x] (marker + checkbox).
    (,(rx line-start (zero-or-more space)
          (group (any "-*+")) space
          (group "[" (any ?\s ?x ?X ?_ ?- ?> ??) "]") space)
     (1 'carve-list-marker-face)
     (2 'carve-markup-face))

    ;; Ordered list markers: 1. 1) a. i.
    (,(rx line-start (zero-or-more space)
          (group (or (one-or-more digit) (any "a-zA-Z")) (any ".)")) space)
     (1 'carve-list-marker-face))

    ;; Bullet list markers: - * + followed by a space and content.
    (,(rx line-start (zero-or-more space) (group (any "-*+")) space (not (any space)))
     (1 'carve-list-marker-face))

    ;; Definition list: :: term  /  :  definition
    (,(rx line-start (group (or "::" ":")) space)
     (1 'carve-markup-face))

    ;; Footnote definition: [^id]:
    (,(rx line-start (group "[^" (one-or-more (not (any "]"))) "]" ":"))
     (1 'carve-footnote-face))

    ;; Reference / link definition: [label]: url
    (,(rx line-start (group "[" (one-or-more (not (any "]"))) "]" ":"))
     (1 'carve-footnote-face))

    ;; Inline footnote reference: [^id]
    (,(rx (group "[^" (one-or-more (not (any "]"))) "]"))
     (1 'carve-footnote-face))

    ;; Images: ![alt](src)
    (,(rx (group "!" "[") (group (zero-or-more (not (any "]")))) (group "]")
          (group "(") (group (zero-or-more (not (any ")")))) (group ")"))
     (1 'carve-markup-face)
     (2 'carve-link-text-face)
     (3 'carve-markup-face)
     (4 'carve-markup-face)
     (5 'carve-url-face)
     (6 'carve-markup-face))

    ;; Cross-reference: </#id>
    (,(rx (group "</#" (one-or-more (not (any ">"))) ">"))
     (1 'carve-url-face))

    ;; Inline links: [text](url) and reference links [text][ref].
    (,(rx (group "[") (group (zero-or-more (not (any "]")))) (group "]")
          (group "(") (group (zero-or-more (not (any ")")))) (group ")"))
     (1 'carve-markup-face)
     (2 'carve-link-text-face)
     (3 'carve-markup-face)
     (4 'carve-markup-face)
     (5 'carve-url-face)
     (6 'carve-markup-face))
    (,(rx (group "[") (group (zero-or-more (not (any "]")))) (group "]")
          (group "[") (group (zero-or-more (not (any "]")))) (group "]"))
     (1 'carve-markup-face)
     (2 'carve-link-text-face)
     (3 'carve-markup-face)
     (4 'carve-markup-face)
     (5 'carve-url-face)
     (6 'carve-markup-face))

    ;; Autolinks: <https://...> and <email>.
    (,(rx (group "<" (or "http" "mailto:" (seq (one-or-more (any "a-zA-Z0-9._%+-"))
                                               "@"))
                 (zero-or-more (not (any "> "))) ">"))
     (1 'carve-url-face))

    ;; Display math: $$`...`
    (,(rx (group "$$`" (minimal-match (zero-or-more not-newline)) "`"))
     (1 'carve-math-face))
    ;; Inline math: $`...`
    (,(rx (group "$`" (minimal-match (zero-or-more not-newline)) "`"))
     (1 'carve-math-face))

    ;; Raw inline code: `code`{=html}
    (,(rx (group "`" (minimal-match (one-or-more not-newline)) "`")
          (group "{=" (one-or-more (any "a-zA-Z")) "}"))
     (1 'carve-code-face)
     (2 'carve-attribute-face))

    ;; Inline code span: `code`
    (,(rx (group "`" (minimal-match (one-or-more (not (any "`")))) "`"))
     (1 'carve-code-face keep))

    ;; CriticMarkup: {+ins+} {-del-} {~old~>new~} {# comment #}
    (,(rx (group "{" (any "+-~#") (minimal-match (zero-or-more not-newline))
                 (any "+-~#") "}"))
     (1 'carve-critic-face))

    ;; Forced brace emphasis: {^...^} {,...,} {*...*} {/.../} {_..._} {~...~} {=...=}
    (,(rx "{" (group (any "*/_~^,=")) (minimal-match (one-or-more not-newline))
          (backref 1) "}")
     (0 'carve-markup-face))

    ;; Inline attribute block attached to a node: {.class #id key=val}
    (,(rx (group "{" (any ".#") (one-or-more (not (any "}{"))) "}"))
     (1 'carve-attribute-face))

    ;; Bare emphasis delimiters (word-boundary approximation).
    (,(rx (or bol space (any "([{")) (group "*" (minimal-match (one-or-more (not (any "*\n")))) "*"))
     (1 'carve-bold-face))
    (,(rx (or bol space (any "([{")) (group "/" (minimal-match (one-or-more (not (any "/\n")))) "/"))
     (1 'carve-italic-face))
    (,(rx (or bol space (any "([{")) (group "_" (minimal-match (one-or-more (not (any "_\n")))) "_"))
     (1 'carve-underline-face))
    (,(rx (or bol space (any "([{")) (group "~" (minimal-match (one-or-more (not (any "~\n")))) "~"))
     (1 'carve-strike-face))
    (,(rx (or bol space (any "([{")) (group "=" (minimal-match (one-or-more (not (any "=\n")))) "="))
     (1 'carve-highlight-face))
    (,(rx (or bol space (any "([{")) (group "^" (minimal-match (one-or-more (not (any "^\n")))) "^"))
     (1 'carve-markup-face))

    ;; Citation groups: [+@key, loc; @key2] — highlight @key and the +/- markers.
    ;; A citation bracket has no (url)/[ref]/{attr} tail.
    (,(rx (group "[" (opt "+"))
          (zero-or-more (not (any "@]")))
          (group "@" (one-or-more (any "A-Za-z0-9_:.#$%&+?<>~/-")))
          (zero-or-more (not (any "]")))
          "]"
          (not (any "([{" ?\n)))
     (1 'carve-mention-face)
     (2 'carve-mention-face))
    ;; Also match citation brackets at end-of-line.
    (,(rx (group "[" (opt "+"))
          (zero-or-more (not (any "@]")))
          (group "@" (one-or-more (any "A-Za-z0-9_:.#$%&+?<>~/-")))
          (zero-or-more (not (any "]")))
          "]" eol)
     (1 'carve-mention-face)
     (2 'carve-mention-face))

    ;; CodeCallout markers: <N> with digits only.
    (,(rx (group "<" (one-or-more digit) ">"))
     (1 'carve-markup-face))

    ;; Mentions and tags (word boundary).
    (,(rx (or bol space (any "([")) (group "@" (one-or-more (any "a-zA-Z0-9._-"))))
     (1 'carve-mention-face))
    (,(rx (or bol space (any "([")) (group "#" (one-or-more (any "a-zA-Z0-9._-"))))
     (1 'carve-tag-face))

    ;; Thematic break.
    (,(rx line-start (group (or (>= 3 ?-) (>= 3 ?*) (>= 3 ?_))) (zero-or-more space) line-end)
     (1 'carve-markup-face))
    )
  "Font-lock keywords for `carve-mode'.")

(defun carve--fontify-frontmatter (limit)
  "Fontify a leading frontmatter block between point and LIMIT.
Only matches when the block starts on the first line of the buffer."
  (when (and (= (point) (point-min))
             (save-excursion
               (goto-char (point-min))
               (looking-at (rx line-start "---" (zero-or-more (any "a-zA-Z ")) line-end))))
    (goto-char (point-min))
    (forward-line 1)
    (when (re-search-forward (rx line-start "---" (zero-or-more space) line-end) limit t)
      (set-match-data (list (point-min) (min (point) limit)))
      t)))

;;;; Syntax table

(defvar carve-mode-syntax-table
  (let ((table (make-syntax-table)))
    ;; `%%' begins a line comment; newline ends it.  The two-character
    ;; sequence is expressed with the `1'/`2' comment flags on `%'.
    (modify-syntax-entry ?% ". 12" table)
    (modify-syntax-entry ?\n ">" table)
    ;; Treat backtick as a string-ish delimiter for code spans.
    (modify-syntax-entry ?` "$" table)
    ;; Underscore and slash are punctuation, not word constituents, so the
    ;; emphasis delimiters behave predictably.
    (modify-syntax-entry ?_ "." table)
    (modify-syntax-entry ?/ "." table)
    ;; Bracket and brace pairs.
    (modify-syntax-entry ?\[ "(]" table)
    (modify-syntax-entry ?\] ")[" table)
    (modify-syntax-entry ?{ "(}" table)
    (modify-syntax-entry ?} "){" table)
    table)
  "Syntax table for `carve-mode'.")

;;;; Imenu

(defun carve--imenu-create-index ()
  "Build an imenu index of Carve headings."
  (let ((index '()))
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward carve--heading-re nil t)
        ;; Skip headings inside fenced code by checking the code face.
        (unless (eq (get-text-property (match-beginning 3) 'face)
                    'carve-code-face)
          (let* ((level (length (match-string 1)))
                 (text (string-trim (match-string-no-properties 3)))
                 (label (concat (make-string (1- level) ?\s) text)))
            (push (cons label (match-beginning 3)) index)))))
    (nreverse index)))

;;;; Optional preview / compile integration

(defun carve--available-p ()
  "Return non-nil when the Carve command-line tool is on variable `exec-path'."
  (and carve-command (executable-find carve-command)))

(defun carve-compile-region (start end)
  "Render the Carve text between START and END with the `carve' CLI.
Output is shown in a `*Carve Output*' buffer.  When the tool is not
installed, signal a user error instead of failing obscurely."
  (interactive "r")
  (unless (carve--available-p)
    (user-error "The `%s' command was not found on PATH; cannot preview"
                carve-command))
  (let ((input (buffer-substring-no-properties start end))
        (out (get-buffer-create "*Carve Output*")))
    (with-current-buffer out
      (erase-buffer))
    (with-temp-buffer
      (insert input)
      (call-process-region (point-min) (point-max) carve-command nil out nil))
    (display-buffer out)))

(defun carve-preview-buffer ()
  "Render the whole buffer with the `carve' CLI via `carve-compile-region'."
  (interactive)
  (carve-compile-region (point-min) (point-max)))

;;;; Keymap

(defvar carve-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c C-c") #'carve-preview-buffer)
    (define-key map (kbd "C-c C-r") #'carve-compile-region)
    map)
  "Keymap for `carve-mode'.")

;;;; Mode definition

;;;###autoload
(define-derived-mode carve-mode text-mode "Carve"
  "Major mode for editing Carve markup files.

\\{carve-mode-map}"
  :group 'carve
  (setq-local font-lock-defaults
              '(carve-font-lock-keywords nil nil nil nil
                (font-lock-multiline . t)))
  (setq-local font-lock-multiline t)
  (setq-local comment-start "%% ")
  (setq-local comment-start-skip "%%+[ \t]*")
  (setq-local comment-end "")
  (setq-local imenu-create-index-function #'carve--imenu-create-index)
  ;; Outline support keyed on ATX headings.
  (setq-local outline-regexp "#+ ")
  (setq-local outline-level (lambda () (- (match-end 0) (match-beginning 0) 1)))
  (setq-local paragraph-start "\f\\|[ \t]*$")
  (setq-local paragraph-separate "[ \t\f]*$"))

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.crv\\'" . carve-mode))

(provide 'carve-mode)

;;; carve-mode.el ends here
