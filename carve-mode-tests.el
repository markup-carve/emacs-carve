;;; carve-mode-tests.el --- Tests for carve-mode -*- lexical-binding: t; -*-

;; SPDX-License-Identifier: MIT

;;; Commentary:

;; ERT tests for `carve-mode'.  Each test opens a snippet of Carve text in a
;; temporary buffer, forces font-lock, and asserts that representative
;; positions carry the expected face.  Run with:
;;
;;   emacs -Q --batch -l ert -l carve-mode.el -l carve-mode-tests.el \
;;     -f ert-run-tests-batch-and-exit

;;; Code:

(require 'ert)
(require 'carve-mode)

(defun carve-test--face-at (text search)
  "Open TEXT in a `carve-mode' buffer, fontify, and return the face.
Point is moved to the start of the first match of SEARCH (a string),
and the `face' text property at that position is returned."
  (with-temp-buffer
    (insert text)
    (carve-mode)
    (font-lock-ensure)
    (goto-char (point-min))
    (search-forward search)
    (goto-char (match-beginning 0))
    (get-text-property (point) 'face)))

(defun carve-test--face-includes (face expected)
  "Return non-nil when FACE is EXPECTED or contains EXPECTED in a list."
  (or (eq face expected)
      (and (listp face) (memq expected face))))

(ert-deftest carve-test-heading ()
  "An ATX heading's text is fontified with the heading face."
  (should (carve-test--face-includes
           (carve-test--face-at "# Welcome\n" "Welcome")
           'carve-heading-face)))

(ert-deftest carve-test-heading-marker ()
  "The leading `#' run of a heading is markup."
  (should (carve-test--face-includes
           (carve-test--face-at "### Setup\n" "###")
           'carve-markup-face)))

(ert-deftest carve-test-bold ()
  "A `*bold*' span is fontified bold."
  (should (carve-test--face-includes
           (carve-test--face-at "this is *bold* text\n" "*bold*")
           'carve-bold-face)))

(ert-deftest carve-test-italic ()
  "A `/italic/' span is fontified italic."
  (should (carve-test--face-includes
           (carve-test--face-at "an /italic/ word\n" "/italic/")
           'carve-italic-face)))

(ert-deftest carve-test-highlight ()
  "An `=highlight=' span is fontified with the highlight face."
  (should (carve-test--face-includes
           (carve-test--face-at "see =marked= here\n" "=marked=")
           'carve-highlight-face)))

(ert-deftest carve-test-inline-code ()
  "An inline code span is fontified with the code face."
  (should (carve-test--face-includes
           (carve-test--face-at "run `npm install` now\n" "`npm install`")
           'carve-code-face)))

(ert-deftest carve-test-code-fence ()
  "Body text inside a fenced code block is fontified as code."
  (should (carve-test--face-includes
           (carve-test--face-at "```python\nprint(1)\n```\n" "print(1)")
           'carve-code-face)))

(ert-deftest carve-test-code-fence-not-heading ()
  "A `#' line inside a code fence is code, not a heading."
  (should (carve-test--face-includes
           (carve-test--face-at "```\n# not a heading\n```\n" "# not")
           'carve-code-face)))

(ert-deftest carve-test-comment ()
  "A `%%' line is a comment (the text after the delimiter)."
  (should (carve-test--face-includes
           (carve-test--face-at "%% a line comment\n" "a line comment")
           'font-lock-comment-face)))

(ert-deftest carve-test-link-url ()
  "A link URL is fontified with the URL face."
  (should (carve-test--face-includes
           (carve-test--face-at "see [Djot](https://djot.net) ok\n" "https://djot.net")
           'carve-url-face)))

(ert-deftest carve-test-link-text ()
  "Link text is fontified with the link-text face."
  (should (carve-test--face-includes
           (carve-test--face-at "see [Djot](https://djot.net) ok\n" "Djot")
           'carve-link-text-face)))

(ert-deftest carve-test-div ()
  "A `:::' admonition fence is fontified with the admonition face."
  (should (carve-test--face-includes
           (carve-test--face-at "::: note\nbody\n:::\n" ":::")
           'carve-admonition-face)))

(ert-deftest carve-test-blockquote ()
  "A `>' blockquote marker is fontified."
  (should (carve-test--face-includes
           (carve-test--face-at "> quoted line\n" ">")
           'carve-blockquote-face)))

(ert-deftest carve-test-attribute-line ()
  "A standalone `{#id .class}' line is an attribute line."
  (should (carve-test--face-includes
           (carve-test--face-at "{#intro .featured}\n# Title\n" "{#intro")
           'carve-attribute-face)))

(ert-deftest carve-test-table-header ()
  "A `|=' table header marker is fontified with the table face."
  (should (carve-test--face-includes
           (carve-test--face-at "|= Fruit |= Price |\n" "|=")
           'carve-table-face)))

(ert-deftest carve-test-footnote-ref ()
  "A `[^id]' footnote reference is fontified."
  (should (carve-test--face-includes
           (carve-test--face-at "a fact[^fn] here\n" "[^fn]")
           'carve-footnote-face)))

(ert-deftest carve-test-math-inline ()
  "Inline math `$`...`' is fontified with the math face."
  (should (carve-test--face-includes
           (carve-test--face-at "energy $`E=mc^2` ok\n" "$`E=mc^2`")
           'carve-math-face)))

(ert-deftest carve-test-image ()
  "An image source is fontified with the URL face."
  (should (carve-test--face-includes
           (carve-test--face-at "![Apollo](apollo.jpg) cap\n" "apollo.jpg")
           'carve-url-face)))

(ert-deftest carve-test-tag ()
  "A `#tag' at a word boundary is fontified as a tag."
  (should (carve-test--face-includes
           (carve-test--face-at "see #release here\n" "#release")
           'carve-tag-face)))

(ert-deftest carve-test-mention ()
  "An `@mention' at a word boundary is fontified."
  (should (carve-test--face-includes
           (carve-test--face-at "hi @alice there\n" "@alice")
           'carve-mention-face)))

(ert-deftest carve-test-critic ()
  "A CriticMarkup insertion is fontified with the critic face."
  (should (carve-test--face-includes
           (carve-test--face-at "a {+new+} word\n" "{+new+}")
           'carve-critic-face)))

(ert-deftest carve-test-imenu ()
  "The imenu index lists headings."
  (with-temp-buffer
    (insert "# One\n\nbody\n\n## Two\n")
    (carve-mode)
    (font-lock-ensure)
    (let ((index (carve--imenu-create-index)))
      (should (assoc "One" index))
      (should (assoc " Two" index)))))

(ert-deftest carve-test-mode-loads ()
  "Enabling `carve-mode' sets the expected locals."
  (with-temp-buffer
    (carve-mode)
    (should (equal comment-start "%% "))
    (should (eq major-mode 'carve-mode))
    (should (eq imenu-create-index-function #'carve--imenu-create-index))))

(provide 'carve-mode-tests)

;;; carve-mode-tests.el ends here
