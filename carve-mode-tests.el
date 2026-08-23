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

(ert-deftest carve-test-thematic-break-spellings ()
  "Every thematic-break spelling is markup, not prose.
This one passes before the indentation fix below; it pins the column-zero
behavior so a later rewrite of the rule cannot drop a spelling."
  (dolist (line '("---" "***" "___"))
    (should (carve-test--face-includes
             (carve-test--face-at (concat "a\n\n" line "\n\nb\n") line)
             'carve-markup-face))))

(ert-deftest carve-test-thematic-break-indented ()
  "A break inside a container is still a break."
  (should (carve-test--face-includes
           (carve-test--face-at "- item\n\n  ***\n" "***")
           'carve-markup-face)))

(ert-deftest carve-test-frontmatter-keeps-its-own-face ()
  "The break rule does not steal the front-matter delimiters."
  (should (carve-test--face-includes
           (carve-test--face-at "---\ntitle: Doc\n---\n\nText\n" "title: Doc")
           'carve-frontmatter-face)))

(ert-deftest carve-test-ordered-list-marker ()
  "A valued ordered marker is a list marker."
  (should (carve-test--face-includes
           (carve-test--face-at "1. first\n" "1.")
           'carve-list-marker-face)))

(ert-deftest carve-test-bare-dot-ordered-marker ()
  "A bare `.' continues an ordered sequence (carve#472), so it is a marker."
  (should (carve-test--face-includes
           (carve-test--face-at ". first\n. second\n" ". first")
           'carve-list-marker-face)))

(ert-deftest carve-test-bare-dot-marker-with-attributes ()
  "A marker glued to an attribute block is still a marker."
  (should (carve-test--face-includes
           (carve-test--face-at ".{#x} attributed\n" ".{")
           'carve-list-marker-face)))

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

(ert-deftest carve-test-inline-comment ()
  "A `{% ... %}' run is a comment (markup-carve/carve#1239)."
  (should (carve-test--face-includes
           (carve-test--face-at "a {% hidden note %} b\n" "hidden note")
           'font-lock-comment-face)))

(ert-deftest carve-test-inline-comment-hides-emphasis ()
  "Emphasis inside an inline comment is not fontified as emphasis."
  (should (carve-test--face-includes
           (carve-test--face-at "{% *not bold* %}\n" "not bold")
           'font-lock-comment-face))
  (should-not (carve-test--face-includes
               (carve-test--face-at "{% *not bold* %}\n" "not bold")
               'carve-bold-face)))

(ert-deftest carve-test-inline-comment-inside-code-stays-code ()
  "A `{%' inside a code span stays code."
  (should (carve-test--face-includes
           (carve-test--face-at "`{% stays code %}`\n" "stays code")
           'carve-code-face)))

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

(ert-deftest carve-test-markers-need-content ()
  "MARKER REQUIRES CONTENT (markup-carve/carve#513).

A marker followed by whitespace only is prose: carve-rs renders `- ' as
`<p>-</p>'.  The bare dot is not an exception - it may drop its VALUE, the
number, but `. ' is still `<p>.</p>'.

Only spaces and tabs separate a marker from its content, so a heading whose
content starts with a non-ASCII space is still a heading."
  ;; A RUN of spaces is not content either - `one-or-more not-newline' matched
  ;; those spaces and made the separator do the content's job.
  (dolist (src '("# " "#  " "- " "-  " "1. " ". " "^ " ":: "))
    (should-not (carve-test--face-at (concat src "\n") (substring src 0 1))))
  (should (carve-test--face-includes
           (carve-test--face-at "# H\n" "#") 'carve-markup-face))
  (should (carve-test--face-includes
           (carve-test--face-at "- item\n" "-") 'carve-list-marker-face))
  (should (carve-test--face-includes
           (carve-test--face-at ". bare\n" ".") 'carve-list-marker-face))
  (should (carve-test--face-includes
           (carve-test--face-at "# \u00a0Title\n" "#") 'carve-markup-face))
  ;; An empty task item is a plain bullet holding the literal `[ ]', with no
  ;; checkbox: carve-rs and carve-js both render `<ul><li>[ ]</li></ul>'.
  (should (carve-test--face-includes
           (carve-test--face-at "- [ ] \n" "-") 'carve-list-marker-face))
  (should-not (carve-test--face-at "- [ ] \n" "["))
  (should (carve-test--face-includes
           (carve-test--face-at "- [x] done\n" "[") 'carve-markup-face)))

(ert-deftest carve-test-blockquote-needs-a-space ()
  "A `>' with no space after it is prose, not a blockquote marker.

Verified against carve-rs: `>no space', `>>x', `>> x' and `>\tx' all render as
paragraphs.  `>>' is not a nested marker - that is written `> > x', a space per
marker - and a tab does not separate (markup-carve/carve#525)."
  (dolist (src '(">no space\n" ">>x\n" ">> x\n" ">\tx\n"))
    (should-not (carve-test--face-includes
                 (carve-test--face-at src ">")
                 'carve-blockquote-face)))
  ;; A bare `>' alone on its line is still a marker.
  (should (carve-test--face-includes
           (carve-test--face-at ">\n" ">")
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

(ert-deftest carve-test-inline-literal ()
  "An inline literal `!`...`' is fontified with the code face."
  (should (carve-test--face-includes
           (carve-test--face-at "the word !`/kaet/` ok\n" "!`/kaet/`")
           'carve-code-face)))

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

(ert-deftest carve-test-symbol ()
  "A `:name:' symbol shortcode at a word boundary is fontified."
  (should (carve-test--face-includes
           (carve-test--face-at "a :rocket: here\n" ":rocket:")
           'carve-symbol-face)))

(ert-deftest carve-test-citation-key ()
  "The @key inside a citation group is fontified as a mention."
  (should (carve-test--face-includes
           (carve-test--face-at "See [@smith2023] for details.\n" "@smith2023")
           'carve-mention-face)))

(ert-deftest carve-test-citation-integral ()
  "A leading `+' in a citation group is fontified."
  (should (carve-test--face-includes
           (carve-test--face-at "Proved in [+@jones2020, p. 5].\n" "+")
           'carve-mention-face)))

(ert-deftest carve-test-callout-marker ()
  "A `<N>' code callout marker is fontified as markup."
  (should (carve-test--face-includes
           (carve-test--face-at "    x = 1  <1>\n" "<1>")
           'carve-markup-face)))

(ert-deftest carve-test-braced-superscript ()
  "A braced `{^...^}' superscript is fontified as markup."
  (should (carve-test--face-includes
           (carve-test--face-at "energy mc{^2^} here\n" "{^2^}")
           'carve-markup-face)))

(ert-deftest carve-test-braced-subscript ()
  "A braced `{,...,}' subscript is fontified as markup."
  (should (carve-test--face-includes
           (carve-test--face-at "water H{,2,}O here\n" "{,2,}")
           'carve-markup-face)))

(ert-deftest carve-test-bare-caret-is-literal ()
  "A bare `^text^' is literal text, not superscript markup."
  (should-not (carve-test--face-includes
               (carve-test--face-at "a ^literal^ caret\n" "^literal^")
               'carve-markup-face)))

(ert-deftest carve-test-bare-comma-is-literal ()
  "A bare `,text,' is literal text, not subscript markup."
  (should-not (carve-test--face-includes
               (carve-test--face-at "a ,literal, comma\n" ",literal,")
               'carve-markup-face)))

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

(ert-deftest carve-test-brace-span-alone-on-a-line-is-not-an-attribute-line ()
  "A forced span alone on a line is emphasis, not a block-attribute line.
The face is the ITALIC one, not the generic markup face it used to be: the
braced spellings are now one rule each, so each carries the face of the mark
it means (markup-carve/emacs-carve#19)."
  (with-temp-buffer
    (insert "{/a/b/}")
    (carve-mode)
    (font-lock-ensure)
    (should (eq (get-text-property 2 'face) 'carve-italic-face))))

(ert-deftest carve-test-block-attribute-line-still-highlights ()
  "A real block-attribute line keeps its face."
  (with-temp-buffer
    (insert "{#id .class key=value}")
    (carve-mode)
    (font-lock-ensure)
    (should (eq (get-text-property 2 'face) 'carve-attribute-face))))

(ert-deftest carve-test-language-attribute-inline ()
  "A span's language attribute is an attribute block."
  (should (carve-test--face-includes
           (carve-test--face-at "[x]{:fr} t\n" "{:fr}")
           'carve-attribute-face)))

(ert-deftest carve-test-language-attribute-block-line ()
  "A language attribute alone on a line is a block-attribute line."
  (should (carve-test--face-includes
           (carve-test--face-at "{:fr}\n" "{:fr}")
           'carve-attribute-face)))

(ert-deftest carve-test-language-attribute-with-subtags ()
  "Hyphenated subtags are part of the tag, and other items may follow."
  (should (carve-test--face-includes
           (carve-test--face-at "[y]{:zh-Hant .hl} t\n" "{:zh-Hant")
           'carve-attribute-face)))

(ert-deftest carve-test-empty-language-attribute ()
  "The empty form `{:}' is a valid attribute block."
  (should (carve-test--face-includes
           (carve-test--face-at "[w]{:} t\n" "{:}")
           'carve-attribute-face)))

(ert-deftest carve-test-overlong-language-tag-is-prose ()
  "A subtag is at most eight characters, so `{:toolongtag}' is prose.
Emacs regexps have no lookahead, so this is the case that proves the
trailing brace is doing the anchoring: without it the tag rule would
take the first eight characters and fontify a partial block."
  (should-not (carve-test--face-at "[x]{:toolongtag} t\n" "{:toolongtag}"))
  (should-not (carve-test--face-at "{:toolongtag}\n" "{:toolongtag}")))

(ert-deftest carve-test-inline-attribute-block-does-not-cross-a-line ()
  "An inline attribute block may not span lines.
Only the standalone attribute LINE continues (markup-carve/carve#897).
Without excluding the newline, an unclosed block ran on through the prose
below it to the next `}\=' anywhere in the buffer.  Both branches of the
rule are checked, because both carried the same payload class."
  (should-not (carve-test--face-at "[x]{:fr item\nprose}\n" "{:fr"))
  (should-not (carve-test--face-at "[x]{.c item\nprose}\n" "{.c"))
  (should-not (carve-test--face-at "[x]{#i item\nprose}\n" "{#i")))

(ert-deftest carve-test-tilde-brace-without-arrow-is-strikethrough ()
  "{~x~} with no ~> arrow is a forced strikethrough, not a substitution.
It now carries the STRIKE face rather than the generic markup face, which is
what this test always said it was."
  (with-temp-buffer
    (insert "x{~gone~}y")
    (carve-mode)
    (font-lock-ensure)
    (should (eq (get-text-property 4 'face) 'carve-strike-face))))

(ert-deftest carve-test-tilde-brace-with-arrow-is-a-substitution ()
  "{~old~>new~} keeps the critic face."
  (with-temp-buffer
    (insert "a {~old~>new~} b")
    (carve-mode)
    (font-lock-ensure)
    (should (eq (get-text-property 5 'face) 'carve-critic-face))))

;;; Composite figures (PART 9 §4c, markup-carve/carve#1215).
;;
;; A BARE `::: figure' opener - the fence, its separator, the word `figure',
;; and nothing else - is ONE figure of ordered panels; an opener carrying a
;; quoted title or a `[label]' is not that production and stays the generic
;; container.  The distinction lives entirely in the tail of one line, so the
;; controls below are the point of these tests, not padding: a rule that never
;; reaches them would pass the positive test on its own.

(ert-deftest carve-test-bare-figure-is-a-composite-figure ()
  "A bare `::: figure' opener takes the composite-figure face, not the div one."
  (should (carve-test--face-includes
           (carve-test--face-at "::: figure\n![a](a.png)\n:::\n" ":::")
           'carve-figure-group-face))
  (should (carve-test--face-includes
           (carve-test--face-at "::: figure\n![a](a.png)\n:::\n" "figure")
           'carve-figure-group-face))
  (should-not (carve-test--face-includes
               (carve-test--face-at "::: figure\n![a](a.png)\n:::\n" "figure")
               'carve-admonition-face)))

(ert-deftest carve-test-figure-with-title-is-a-generic-container ()
  "`::: figure \"T\"' is not a composite figure; it stays the generic container."
  (let ((src "::: figure \"A titled figure div\"\nbody\n:::\n"))
    (should (carve-test--face-includes
             (carve-test--face-at src "figure")
             'carve-admonition-face))
    (should-not (carve-test--face-includes
                 (carve-test--face-at src "figure")
                 'carve-figure-group-face))))

(ert-deftest carve-test-figure-with-label-is-a-generic-container ()
  "`::: figure [g]' is not a composite figure either."
  (let ((src "::: figure [g]\nbody\n:::\n"))
    (should (carve-test--face-includes
             (carve-test--face-at src "figure")
             'carve-admonition-face))
    (should-not (carve-test--face-includes
                 (carve-test--face-at src "figure")
                 'carve-figure-group-face))))

(ert-deftest carve-test-tab-separated-figure-is-a-generic-container ()
  "The separator is a SPACE run, never a tab.
Grammar PART 7, MARKER SEPARATORS; corpus 254 renders `:::<TAB>note' as a
paragraph.  Spelling the rule with `space' - which is `[[:space:]]' in `rx',
and what the generic rule beside it uses - would give this line the composite
face."
  (let ((src ":::\tfigure\nbody\n:::\n"))
    (should (carve-test--face-includes
             (carve-test--face-at src "figure")
             'carve-admonition-face))
    (should-not (carve-test--face-includes
                 (carve-test--face-at src "figure")
                 'carve-figure-group-face))))

(ert-deftest carve-test-figure-trailing-whitespace-is-insignificant ()
  "Trailing whitespace after the kind word does not spoil a bare opener."
  (should (carve-test--face-includes
           (carve-test--face-at "::: figure\t\nbody\n:::\n" "figure")
           'carve-figure-group-face)))

(ert-deftest carve-test-other-container-kinds-are-unchanged ()
  "Only `figure' is reserved; every other kind word keeps the div face."
  (dolist (kind '("note" "warning" "figures" "figure-panel"))
    (let ((src (concat "::: " kind "\nbody\n:::\n")))
      (should (carve-test--face-includes
               (carve-test--face-at src kind)
               'carve-admonition-face))
      (should-not (carve-test--face-includes
                   (carve-test--face-at src kind)
                   'carve-figure-group-face)))))

(ert-deftest carve-test-group-caption-after-the-closer-is-a-caption ()
  "The group caption is an ordinary `^ ' line below the CLOSING fence.
It needs no rule of its own - the caption rule already claims it - and that
claim is an OVER-APPROXIMATION that stays one: a `^ ' line after any other
`:::' closer gets the same face, because no rule in this file has container
state.  Both halves are asserted so the limit is recorded rather than
rediscovered."
  (should (carve-test--face-includes
           (carve-test--face-at "::: figure\n![a](a.png)\n:::\n^ A caption\n" "^ A caption")
           'carve-markup-face))
  (should (carve-test--face-includes
           (carve-test--face-at "::: note\nbody\n:::\n^ A caption\n" "^ A caption")
           'carve-markup-face)))

;;; The construct ledger (markup-carve/emacs-carve#19).
;;
;; Every test below was written from a MEASUREMENT of what this mode did with
;; the construct, not from the ledger's claim about it: the ledger is the thing
;; under audit.  Each one pins a row that was red - a construct with no rule at
;; all, a construct claimed by a rule about a different construct, or a payload
;; nobody had measured.
;;
;; Where a construct is deliberately NOT fontified, the reason is written in
;; carve-mode.el under "Constructs this mode does not fontify, and why" rather
;; than asserted here: a test that pins the absence of a face would fail the
;; day someone implements it, which is the wrong signal.

(ert-deftest carve-test-local-hard-break-block ()
  "`::: \\' is a recognized `:::' type, and its backslash is part of the opener."
  (should (carve-test--face-includes
           (carve-test--face-at "::: \\\na\nb\n:::\n" "\\")
           'carve-admonition-face))
  ;; ... and inside a container, where the content column is not zero.
  (should (carve-test--face-includes
           (carve-test--face-at "- item\n\n  ::: \\\n  a\n  :::\n" "\\")
           'carve-admonition-face)))

(ert-deftest carve-test-line-block-pipe-is-not-a-table ()
  "An indented `::: |' is a verse container, not a one-column table.
The table rule matched the pipe of an INDENTED line block, so a container
opener came back scoped as a cell delimiter."
  (let ((src "- item\n\n  ::: |\n  a\n  :::\n"))
    (should (carve-test--face-includes
             (carve-test--face-at src "|")
             'carve-admonition-face))
    (should-not (carve-test--face-includes
                 (carve-test--face-at src "|")
                 'carve-table-face))))

(ert-deftest carve-test-raw-block-format-token ()
  "A raw fence's `=FORMAT' token is an attribute; a code fence has none."
  (should (carve-test--face-includes
           (carve-test--face-at "```=html\n<b>x</b>\n```\n" "=html")
           'carve-attribute-face))
  (should (carve-test--face-includes
           (carve-test--face-at "``` python\nx = 1\n```\n" "python")
           'carve-code-face)))

(ert-deftest carve-test-fence-shaped-line-in-a-payload-is-not-a-raw-opener ()
  "The format token cannot fire inside another block's verbatim body.
This is why it is a group of the fence matcher rather than a rule of its own:
a rule matching the same shape would paint the `=html' on this line, which is
payload rather than an opener."
  (should (carve-test--face-includes
           (carve-test--face-at "~~~\n```=html\n~~~\n" "=html")
           'carve-code-face))
  (should-not (carve-test--face-includes
               (carve-test--face-at "~~~\n```=html\n~~~\n" "=html")
               'carve-attribute-face)))

(ert-deftest carve-test-indented-fence-is-a-fence ()
  "A fence at a container's content column is a fence, not two backticks.
The opener was anchored at column zero, so an indented fence fell through to
the INLINE code-span rule: it took the third backtick as a span opener and ran
across the body, leaving two backticks as prose."
  (let ((src "- item\n\n  ```\n  a\n  ```\n"))
    (should (carve-test--face-includes
             (carve-test--face-at src "```") 'carve-code-face))
    (should (carve-test--face-includes
             (carve-test--face-at src "  a") 'carve-code-face))))

(ert-deftest carve-test-comment-block-payload-is-inert ()
  "The body of a `%%%' fence is a comment, not Carve.
The syntax table made each FENCE line a comment and left the lines between
them ordinary text, so an emphasis run inside a block that renders nothing
came back bold - the buffer claimed something the document does not say."
  (should (carve-test--face-includes
           (carve-test--face-at "%%%\na *b* c\n%%%\n" "*b*")
           'font-lock-comment-face))
  (should-not (carve-test--face-includes
               (carve-test--face-at "%%%\na *b* c\n%%%\n" "*b*")
               'carve-bold-face)))

(ert-deftest carve-test-unclosed-comment-fence-does-not-swallow-the-buffer ()
  "A `%%%' run with no closer is a comment LINE (PART 9 section 28).
So the emphasis two lines below it is still emphasis."
  (should (carve-test--face-includes
           (carve-test--face-at "%%%\nbody\n\nafter *b*\n" "*b*")
           'carve-bold-face)))

(ert-deftest carve-test-abbreviation-definition ()
  "`*[TERM]: expansion' is a definition line, at any content column."
  (should (carve-test--face-includes
           (carve-test--face-at "*[HTML]: HyperText Markup Language\n" "*[HTML]:")
           'carve-markup-face))
  (should (carve-test--face-includes
           (carve-test--face-at "- item\n\n  *[HTML]: HyperText\n" "*[HTML]:")
           'carve-markup-face)))

(ert-deftest carve-test-abbreviation-term-is-one-alphanumeric-word ()
  "A term holding punctuation or a space is not a definition (grammar PART 5)."
  (should-not (carve-test--face-at "*[e.g.]: for example\n" "*[e.g.]"))
  (should-not (carve-test--face-at "*[HTTP API]: an interface\n" "*[HTTP API]")))

(ert-deftest carve-test-definitions-at-a-content-column ()
  "A reference and a footnote definition open inside a container too."
  (should (carve-test--face-includes
           (carve-test--face-at "- item\n\n  [ref]: https://e.com\n" "[ref]:")
           'carve-footnote-face))
  (should (carve-test--face-includes
           (carve-test--face-at "- item\n\n  [^a]: note\n" "[^a]:")
           'carve-footnote-face)))

(ert-deftest carve-test-reference-image-is-an-image ()
  "`![alt][ref]' is a reference IMAGE, `!' included.
It was claimed by the reference LINK rule, which starts one character to the
right, so the `!' was left as prose and the run read as a link."
  (should (carve-test--face-includes
           (carve-test--face-at "see ![alt][ref] here\n" "![")
           'carve-markup-face))
  ;; The collapsed spelling is the same rule with an empty label.
  (should (carve-test--face-includes
           (carve-test--face-at "see ![ref][] here\n" "![")
           'carve-markup-face)))

(ert-deftest carve-test-escaped-char ()
  "A backslash before ASCII punctuation is markup, and the pair is literal."
  (should (carve-test--face-includes
           (carve-test--face-at "a \\*not bold\\* b\n" "\\*")
           'carve-markup-face)))

(ert-deftest carve-test-escaped-delimiter-cannot-open-emphasis ()
  "An escaped `*' does not open a bold run.
Claiming the pair is what enforces it: font-lock does not override a face an
earlier keyword set, so the delimiter can no longer start a run."
  (should-not (carve-test--face-includes
               (carve-test--face-at "a \\*x* b\n" "x")
               'carve-bold-face)))

(ert-deftest carve-test-escape-inside-a-code-span-is-content ()
  "Inside a code span a backslash is payload, so the code rule keeps it."
  (should (carve-test--face-includes
           (carve-test--face-at "a `x \\* y` z\n" "\\*")
           'carve-code-face)))

(ert-deftest carve-test-hard-break ()
  "A trailing backslash is the one inline mark that renders to nothing."
  (should (carve-test--face-includes
           (carve-test--face-at "line one\\\nline two\n" "\\")
           'carve-markup-face)))

(ert-deftest carve-test-bold-italic ()
  "`/*x*/' is one construct with two marks, not a plain italic."
  (should (carve-test--face-includes
           (carve-test--face-at "a /*both*/ b\n" "/*both*/")
           'carve-bold-italic-face)))

(ert-deftest carve-test-forced-spellings-carry-their-own-mark ()
  "Each braced spelling takes the face of the mark it means.
One rule keyed on a back-reference could not tell which delimiter it had
matched, so a forced bold read the same as a forced strikethrough."
  (dolist (case '(("a{*x*}b" . carve-bold-face)
                  ("a{/x/}b" . carve-italic-face)
                  ("a{_x_}b" . carve-underline-face)
                  ("a{~x~}b" . carve-strike-face)
                  ("a{=x=}b" . carve-highlight-face)
                  ("a{^x^}b" . carve-markup-face)
                  ("a{,x,}b" . carve-markup-face)))
    (should (carve-test--face-includes
             (carve-test--face-at (car case) (substring (car case) 1 6))
             (cdr case)))))

(ert-deftest carve-test-empty-brace-pair-is-text ()
  "An empty brace pair renders literally (markup-carve/carve#1447).
`{--}' is the one exception and is tested with the dashes below."
  (dolist (pair '("{++}" "{##}" "{^^}" "{**}"))
    (should-not (carve-test--face-at (concat "a " pair " b\n") pair))))

(ert-deftest carve-test-editorial-markup-still-highlights ()
  "Requiring content did not cost the four editorial spellings their face."
  (dolist (span '("{+ins+}" "{-del-}" "{~old~>new~}" "{# note #}"))
    (should (carve-test--face-includes
             (carve-test--face-at (concat "a " span " b\n") span)
             'carve-critic-face))))

(ert-deftest carve-test-extension-inline ()
  "`:name[content]' is an inline extension; a digit-first name is prose."
  (should (carve-test--face-includes
           (carve-test--face-at "a :kbd[Ctrl] b\n" ":kbd[")
           'carve-markup-face))
  (should-not (carve-test--face-at "a :1[x] b\n" ":1[")))

(ert-deftest carve-test-smart-typography ()
  "Every run the renderer replaces carries the typographic face."
  (dolist (run '("---" "--" "..." "-->" "<--" "<-->" "<=>" "<==" "==>"
                 "!=" "<=" ">=" "(c)" "(r)" "(tm)" "+-" "{--}"))
    (should (carve-test--face-includes
             (carve-test--face-at (concat "a " run " b\n") run)
             'carve-typographic-face))))

(ert-deftest carve-test-braced-en-dash-is-not-a-deletion ()
  "`{--}' is an EN DASH, not an empty deletion (markup-carve/carve#1447).
The deletion rule owned the spelling, so a dash came back as editorial
markup - a claim that the author deleted something."
  (should-not (carve-test--face-includes
               (carve-test--face-at "a {--} b\n" "{--}")
               'carve-critic-face)))

(ert-deftest carve-test-hyphen-run-opening-a-word-is-a-flag ()
  "A run with whitespace before it and a word after it stays literal.
That is what keeps `git log --oneline' a flag (markup-carve/carve#1443)."
  (should-not (carve-test--face-at "git log --oneline\n" "--oneline"))
  (should-not (carve-test--face-at "run --force-with-lease now\n" "--force"))
  ;; A numeric range is left-flanked by content, so it converts.
  (should (carve-test--face-includes
           (carve-test--face-at "pages 1--10\n" "--")
           'carve-typographic-face))
  ;; So does a trailing run on an interrupted clause.
  (should (carve-test--face-includes
           (carve-test--face-at "wait--- then\n" "---")
           'carve-typographic-face)))

(ert-deftest carve-test-typography-does-not-reach-into-a-payload ()
  "A dash inside a verbatim run is payload, and the earlier rule keeps it.
The typography rules come last for this reason, so each of these is a
regression test on the ORDER as much as on the rule."
  (should (carve-test--face-includes
           (carve-test--face-at "a `x -- y` z\n" "--") 'carve-code-face))
  (should (carve-test--face-includes
           (carve-test--face-at "a $`x -- y` z\n" "--") 'carve-math-face))
  (should (carve-test--face-includes
           (carve-test--face-at "a <https://e.com/a--b> z\n" "--") 'carve-url-face))
  (should (carve-test--face-includes
           (carve-test--face-at "%% a -- b\n" "--") 'font-lock-comment-face))
  ;; ... and a thematic break is a break, not an em dash.
  (should (carve-test--face-includes
           (carve-test--face-at "a\n\n---\n\nb\n" "---") 'carve-markup-face)))

(ert-deftest carve-test-verbatim-payloads-are-inert ()
  "No inline rule reaches inside a payload that is not Carve.
One sample per construct with a live emphasis marker in the payload; the
positive half of each pair is what keeps the negative honest, because a
negative alone passes just as well when the search lands somewhere else."
  (dolist (case '(("```\na *b* c\n```\n" . carve-code-face)
                  ("```=html\na *b* c\n```\n" . carve-code-face)
                  ("%%%\na *b* c\n%%%\n" . font-lock-comment-face)
                  ("%% a *b* c\n" . font-lock-comment-face)
                  ("x %% a *b* c\n" . font-lock-comment-face)
                  ("a `x *b* y`{=html} z\n" . carve-code-face)
                  ("a !`x *b* y` z\n" . carve-code-face)
                  ("a `x *b* y` z\n" . carve-code-face)
                  ("a <https://e.com/x*b*y> z\n" . carve-url-face)
                  ("a $`x *b* y` z\n" . carve-math-face)
                  ("a $$`x *b* y` z\n" . carve-math-face)
                  ("a {% x *b* y %} z\n" . font-lock-comment-face)
                  ("a {# x *b* y #} z\n" . carve-critic-face)))
    (should (carve-test--face-includes
             (carve-test--face-at (car case) "*b*") (cdr case)))
    (should-not (carve-test--face-includes
                 (carve-test--face-at (car case) "*b*") 'carve-bold-face))))

(ert-deftest carve-test-heading-at-a-content-column ()
  "A heading opens at its container's content column too."
  (should (carve-test--face-includes
           (carve-test--face-at "- item\n\n  # Head\n" "Head")
           'carve-heading-face))
  ;; ... and a `#' inside a fenced body is still payload.
  (should (carve-test--face-includes
           (carve-test--face-at "```\n# not a heading\n```\n" "# not")
           'carve-code-face)))

(ert-deftest carve-test-inline-footnote-is-not-the-reference-rule ()
  "`^[text]' is a construct of its own, and it had no rule.
The ledger read it as implemented on the strength of the REFERENCE rule -
`[^id]', one construct over - whose regexp cannot match a caret-bracket run at
all.  Both halves are asserted, because the positive alone would pass just as
happily if the reference rule were the one firing."
  (should (carve-test--face-includes
           (carve-test--face-at "a ^[a note] b\n" "^[")
           'carve-footnote-face))
  (should (carve-test--face-includes
           (carve-test--face-at "a ^[a note] b\n" "a note")
           'carve-link-text-face))
  ;; ... and the reference spelling still fires on its own shape.
  (should (carve-test--face-includes
           (carve-test--face-at "a [^id] b\n" "[^id]")
           'carve-footnote-face)))

(ert-deftest carve-test-inline-span-is-not-the-code-span-rule ()
  "`[text]{.c}' is a span, and its brackets had no rule.
The ledger cited the CODE span rule, which matches a backtick run and cannot
match a bracketed one: only the trailing attribute block was painted, by a
different rule again."
  (should (carve-test--face-includes
           (carve-test--face-at "a [x]{.c} b\n" "[")
           'carve-markup-face))
  (should (carve-test--face-includes
           (carve-test--face-at "a [x]{.c} b\n" "x")
           'carve-link-text-face))
  ;; The `{' is what tells a span from a link, so a link is still a link.
  (should (carve-test--face-includes
           (carve-test--face-at "a [t](u) b\n" "u")
           'carve-url-face))
  ;; ... and a citation bracket is not a span.
  (should (carve-test--face-includes
           (carve-test--face-at "see [@key] here\n" "[@key")
           'carve-mention-face)))

;;; A percent run only opens a comment where the language has one
;;; (markup-carve/emacs-carve#22).
;;
;; The syntax table gives `%' the comment-start flags, so `%%' opened a comment
;; to end of line ANYWHERE.  Syntactic fontification runs before the keywords
;; and the keywords are non-override, so no rule below could take the region
;; back - which is why the fix is a `syntax-propertize-function' and why these
;; tests assert the FACE of the payload rather than the presence of a rule.
;;
;; Every shape is asserted twice where a column can change it: at column zero
;; and again at a container's content column, because a construct that only
;; works at column zero is the failure this mode has shipped before.

(ert-deftest carve-test-percent-in-a-code-span-is-not-a-comment ()
  "A code span's payload is verbatim, so a `%%' in it opens nothing."
  (dolist (src '("a `x %% y` z\n" "- item\n\n  a `x %% y` z\n"))
    (should (carve-test--face-includes
             (carve-test--face-at src "%%") 'carve-code-face))
    ;; The closing backtick and the tail of the line are outside the span, so
    ;; a comment that swallowed them would show up here.
    (should-not (carve-test--face-includes
                 (carve-test--face-at src "z") 'font-lock-comment-face))))

(ert-deftest carve-test-percent-in-a-verbatim-prefix-run-is-not-a-comment ()
  "The math, literal and raw spellings of a backtick run protect it too.
Each one lost its OWN face as well before this: the comment face was already
on the payload when the keywords ran, so the math rule could not apply."
  (dolist (case '(("a $`x %% y` z\n" . carve-math-face)
                  ("a $$`x %% y` z\n" . carve-math-face)
                  ("a !`x %% y` z\n" . carve-code-face)
                  ("a `<i>%%</i>`{=html} z\n" . carve-code-face)))
    (should (carve-test--face-includes
             (carve-test--face-at (car case) "%%") (cdr case)))))

(ert-deftest carve-test-percent-in-a-fenced-body-is-payload ()
  "A fenced body is verbatim, at column zero and at a content column."
  (dolist (src '("```\na %% b\n```\n" "- item\n\n  ```\n  a %% b\n  ```\n"))
    (should (carve-test--face-includes
             (carve-test--face-at src "%%") 'carve-code-face))))

(ert-deftest carve-test-percent-in-a-link-does-not-kill-the-link ()
  "A `%%' in a label or a destination leaves the link a link.
The engine renders `a [x %% y](u) z' as a link followed by `z'; the comment
took the label, the destination, the parentheses and the tail of the line."
  (dolist (src '("a [x %% y](u) z\n" "a ![x %% y](u) z\n" "a [x](u%%v) z\n"))
    (should (carve-test--face-includes
             (carve-test--face-at src "u") 'carve-url-face))
    (should-not (carve-test--face-includes
                 (carve-test--face-at src "z") 'font-lock-comment-face)))
  ;; ... and the payload has to CLOSE for the bracket run to be one of those.
  ;; `a [x %% y](u z' is no link, and the engine renders it `a [x' - the
  ;; comment reaching the end of the line after all.
  (dolist (src '("a [x %% y](u z\n" "a [x %% y][r z\n" "a [x %% y]{.c z\n"))
    (should (carve-test--face-includes
             (carve-test--face-at src "%% y") 'font-lock-comment-delimiter-face))))

(ert-deftest carve-test-percent-in-an-autolink-is-part-of-the-url ()
  "An autolink's text IS its destination, so a percent-encoded path is URL."
  (should (carve-test--face-includes
           (carve-test--face-at "a <https://e.com/a%%b> z\n" "%%")
           'carve-url-face)))

(ert-deftest carve-test-percent-needs-whitespace-before-it ()
  "`50%%' is literal text: a comment marker is preceded by whitespace.
Spec, \"Comments\": without preceding whitespace `%%' stays literal, which is
what keeps a percentage safe."
  (dolist (src '("a 50%% off\n" "a x%%y z\n"))
    (should-not (carve-test--face-includes
                 (carve-test--face-at src "%%") 'font-lock-comment-face))
    (should-not (carve-test--face-includes
                 (carve-test--face-at src "%%") 'font-lock-comment-delimiter-face))))

(ert-deftest carve-test-escaped-percent-is-not-a-comment ()
  "`\\%%' is an escaped percent, so the run cannot open a comment."
  (should-not (carve-test--face-includes
               (carve-test--face-at "a \\%% b\n" "b") 'font-lock-comment-face)))

(ert-deftest carve-test-percent-in-an-unpartnered-run-is-not-a-comment ()
  "An unpartnered backtick run is a span to the end of its PARAGRAPH.
So a `%%' after it is inside the span and opens nothing - and the paragraph is
the bound, not the line: the next line is inside the run and the one after the
blank line is not.

The face asserted is the DELIMITER face, because that is what a `%%' run takes
when it opens a comment; the payload face is a separate question, and it is
the one markup-carve/emacs-carve#21 is about."
  (let ((src "a `x %% y\nb %% c\n\nd %% e\n"))
    (should-not (carve-test--face-includes
                 (carve-test--face-at src "%% y") 'font-lock-comment-delimiter-face))
    (should-not (carve-test--face-includes
                 (carve-test--face-at src "%% c") 'font-lock-comment-delimiter-face))
    (should (carve-test--face-includes
             (carve-test--face-at src "%% e") 'font-lock-comment-delimiter-face))))

(ert-deftest carve-test-a-comment-is-still-a-comment ()
  "The narrowing does not take the comment constructs with it.
A comment line at column zero and at a content column, a trailing comment
after prose, and the two delimiter lines of a comment fence."
  (dolist (src '("%% hidden\n" "- item\n\n  %% hidden\n"))
    (should (carve-test--face-includes
             (carve-test--face-at src "hidden") 'font-lock-comment-face)))
  (should (carve-test--face-includes
           (carve-test--face-at "x %% note\n" "note") 'font-lock-comment-face))
  (should (carve-test--face-includes
           (carve-test--face-at "%%%\nbody\n%%%\n" "body") 'font-lock-comment-face)))

;;; The payload axis: a run the engine keeps verbatim keeps its markup inert
;;; (markup-carve/emacs-carve#21).
;;
;; A construct that is recognized but does not hold its payload is worse than
;; one that is not highlighted at all, because the buffer then claims the
;; document says something it does not.  Each test below pins a shape
;; carve-grammars' generated payload sweep found leaking, and each asserts the
;; payload's face rather than the construct's, because the payload is the
;; question.

(ert-deftest carve-test-wide-backtick-run-is-paired-at-its-own-width ()
  "A run of two backticks is closed by a run of two, not by the next one.
The span was paired ONE CHARACTER IN - from the second backtick of the opener
to the third of the closer - so the outer backtick at each end was left
outside it and a payload reaching either seam coloured."
  (dolist (src '("a ``x *b* y`` z\n" "- item\n\n  a ``x *b* y`` z\n"))
    (should (carve-test--face-includes
             (carve-test--face-at src "``x") 'carve-code-face))
    (should (carve-test--face-includes
             (carve-test--face-at src "*b*") 'carve-code-face))
    (should-not (carve-test--face-includes
                 (carve-test--face-at src "*b*") 'carve-bold-face)))
  ;; A run of a DIFFERENT width does not close it, so the span holds a literal
  ;; backtick pair: `a ``x `y` z`` w' is one span, not two.
  (should (carve-test--face-includes
           (carve-test--face-at "a ``x `y` z`` w\n" "y") 'carve-code-face))
  (should-not (carve-test--face-includes
               (carve-test--face-at "a ``x `y` z`` w\n" "w") 'carve-code-face)))

(ert-deftest carve-test-unpartnered-backtick-run-reaches-its-paragraph ()
  "An unclosed run is a span to the end of its PARAGRAPH, not to nowhere.
The engine renders `a `x *b* y' as `a <code>x *b* y</code>'; the rest of the
line stayed live here, so an emphasis run after an unclosed backtick coloured.
The paragraph is the bound: the next line is inside the span and the one after
a blank line is not."
  (dolist (src '("a `x *b* y\nc *d* e\n\nf *g* h\n"
                 "a ``x *b* y\nc *d* e\n\nf *g* h\n"))
    (should (carve-test--face-includes
             (carve-test--face-at src "*b*") 'carve-code-face))
    (should (carve-test--face-includes
             (carve-test--face-at src "*d*") 'carve-code-face))
    (should (carve-test--face-includes
             (carve-test--face-at src "*g*") 'carve-bold-face))))

(ert-deftest carve-test-delimited-comment-crosses-a-soft-break ()
  "`{% ... %}' delimits a comment inside a PARAGRAPH, not inside a line.
Its own rule said so - \"the whole run takes the comment face and the emphasis
rules below never reach inside\" - and its body was `not-newline'."
  (dolist (src '("a {% x\n*b* %} z\n" "- item\n\n  a {% x\n  *b* %} z\n"))
    (should (carve-test--face-includes
             (carve-test--face-at src "*b*") 'font-lock-comment-face))
    (should-not (carve-test--face-includes
                 (carve-test--face-at src "*b*") 'carve-bold-face)))
  ;; A BLANK LINE still ends it: the engine renders the second half of
  ;; `a {% x' + blank + `*b* %} z' as a paragraph with a bold run in it.
  (should (carve-test--face-includes
           (carve-test--face-at "a {% x\n\n*b* %} z\n" "*b*") 'carve-bold-face)))

(ert-deftest carve-test-editorial-comment-crosses-a-soft-break ()
  "`{# ... #}' is bounded by its paragraph too, for the same reason."
  (should (carve-test--face-includes
           (carve-test--face-at "a {# x\n*b* #} z\n" "*b*") 'carve-critic-face))
  (should-not (carve-test--face-includes
               (carve-test--face-at "a {# x\n*b* #} z\n" "*b*") 'carve-bold-face))
  ;; An EMPTY brace pair is still text (markup-carve/carve#1447), which the
  ;; matcher has to keep saying now that the payload may be a newline.
  (should-not (carve-test--face-includes
               (carve-test--face-at "a {##} b\n" "{##}") 'carve-critic-face)))

(ert-deftest carve-test-indented-delimiter-line-is-fence-payload ()
  "A closer sits at the OPENER's own column; a run past it is content.
A fence holding a fence is what every document describing Carve in Carve is
made of, and an indented delimiter-shaped line ended the block early - so
everything after the sample went live."
  (should (carve-test--face-includes
           (carve-test--face-at "~~~\n  ~~~\n*b*\n~~~\n" "*b*") 'carve-code-face))
  (should (carve-test--face-includes
           (carve-test--face-at "```\n  ```\n*b*\n```\n" "*b*") 'carve-code-face))
  ;; ... and a fence that opens at a container's content column still closes
  ;; at that column.
  (should (carve-test--face-includes
           (carve-test--face-at "- item\n\n  ```\n  *b*\n  ```\n\n*c*\n" "*b*")
           'carve-code-face))
  (should (carve-test--face-includes
           (carve-test--face-at "- item\n\n  ```\n  *b*\n  ```\n\n*c*\n" "*c*")
           'carve-bold-face))
  ;; The column is a COLUMN, not a spelling of whitespace: an opener indented
  ;; with eight spaces still meets a closer indented with one tab.  A TILDE
  ;; fence, because a backtick one is also claimed by the code-span matcher
  ;; and would answer this question without the fence rule taking part.
  (let ((src "        ~~~\n*b*\n\t~~~\n\n*c*\n"))
    (should (carve-test--face-includes
             (carve-test--face-at src "*b*") 'carve-code-face))
    (should (carve-test--face-includes
             (carve-test--face-at src "*c*") 'carve-bold-face))))

(defun carve-test--face-after-partial-fontify (text from search)
  "Fontify TEXT from FROM's line to its end only, then return SEARCH's face.
`font-lock-ensure' hands the whole buffer to the keywords, which is not what a
real editor does: it fontifies a CHUNK.  A multi-line construct is only
reliable if the mode widens that chunk to the construct's bounds, and this is
the only way to ask."
  (with-temp-buffer
    (insert text)
    (carve-mode)
    (font-lock-set-defaults)
    (goto-char (point-min))
    (search-forward from)
    (font-lock-fontify-region (line-beginning-position) (point-max))
    (goto-char (point-min))
    (search-forward search)
    (goto-char (match-beginning 0))
    (get-text-property (point) 'face)))

(ert-deftest carve-test-a-chunk-is-widened-to-its-paragraph ()
  "A multi-line run keeps its payload when only its SECOND line is fontified.
The three matchers that reach past a line - an unpartnered backtick run and
the two delimited comments - are handed a chunk of the buffer by font-lock,
and a chunk starting inside a run has no opener to find."
  (should (carve-test--face-includes
           (carve-test--face-after-partial-fontify "a `x *b* y\nc *d* e\n" "c *d*" "*d*")
           'carve-code-face))
  (should (carve-test--face-includes
           (carve-test--face-after-partial-fontify "a {% x\n*b* %} z\n" "*b*" "*b*")
           'font-lock-comment-face))
  (should (carve-test--face-includes
           (carve-test--face-after-partial-fontify "a {# x\n*b* #} z\n" "*b*" "*b*")
           'carve-critic-face))
  ;; And widening does not hand the prose after a CLOSED block to the block:
  ;; a chunk starting on the line after a closer walks back to the opener, and
  ;; a delimiter run that opens its line is not an inline opener either.
  (should (carve-test--face-includes
           (carve-test--face-after-partial-fontify "```\na\n```\nb *c* d\n" "b *c*" "*c*")
           'carve-bold-face)))
