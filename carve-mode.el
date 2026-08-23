;;; carve-mode.el --- Major mode for Carve markup -*- lexical-binding: t; -*-

;; Author: markup-carve
;; Maintainer: markup-carve
;; Version: 0.1.1
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
;; `~strike~', `=highlight=', and the brace forms, including superscript
;; `{^...^}' and subscript `{,...,}'), inline literals, inline and raw inline code, links,
;; autolinks, reference links and
;; definitions, images, cross-references, lists (bullet, ordered, task),
;; definition lists, blockquotes, caption lines, fenced and raw code blocks,
;; `%%' and `{%..%}' comments, fenced divs and admonitions, block-attribute lines, tables,
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

(defface carve-bold-italic-face
  '((t :inherit (bold italic)))
  "Face for the combined `/*bold italic*/' spelling."
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

(defface carve-figure-group-face
  '((t :inherit font-lock-function-name-face :weight bold))
  "Face for a bare `::: figure' composite-figure opener.
A composite figure is a different construct from the generic container
`carve-admonition-face' marks, not a flavor of it (PART 9 §4c), so it takes
its own face rather than sharing that one.  Only the OPENER carries it: the
closing fence is a bare `:::' line, and which container it closes is not
something a per-line rule can know, so it keeps `carve-admonition-face'."
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

(defface carve-symbol-face
  '((t :inherit font-lock-constant-face))
  "Face for `:name:' symbol shortcodes."
  :group 'carve)

(defface carve-critic-face
  '((t :inherit font-lock-warning-face))
  "Face for CriticMarkup."
  :group 'carve)

(defface carve-typographic-face
  '((t :inherit font-lock-constant-face))
  "Face for the source spelling of a typographic replacement.
Covers the dash runs, the ellipsis, the arrows, the comparison operators
and the `(c)' family - every run the renderer replaces with a character
the author did not type."
  :group 'carve)

;;;; Helper matchers

(defconst carve--heading-re
  ;; MARKER REQUIRES CONTENT, and a RUN of spaces is not content: carve-rs
  ;; renders `#<space><space>' as `<p>#</p>'.  `one-or-more not-newline'
  ;; happily matched those spaces, so the separator was doing the content's
  ;; job.  `(in " \t")' for the separator and `(not (any " \t\n"))' for the
  ;; first content character - the newline in that set is what makes it bite.
  (rx line-start (zero-or-more (in " \t"))
      (group (** 1 6 ?#)) (group (one-or-more " "))
      (group (not (any " \t\n")) (zero-or-more not-newline)) line-end)
  "Match an ATX heading line (no trailing attribute blocks in Carve).")

(defun carve--fontify-fenced-blocks (limit)
  "Search for a fenced code, raw, or math block between point and LIMIT.
Set match groups so font-lock can color the opener, body, and closer.
Group 1 is the whole opener line, group 2 the body, group 3 the closer,
and group 4 the `=FORMAT' token of a raw block (empty when there is none).

LEADING WHITESPACE IS PART OF THE OPENER.  A fence opens at its
container's content column, which is zero only at the top level, so an
indented fence inside a list item is a fence too.  Without that the
indented opener fell through to the INLINE code-span rule, which took the
third backtick as a span opener and ran across the body to the closer -
two backticks left as prose and a multi-line span claiming a block.  It is
the same over-approximation the thematic-break rule makes: a per-line
matcher cannot tell a container's indent from a stray one, and painting
an indented fence at the top level is the cheaper error."
  (catch 'done
    (while (re-search-forward
            (rx line-start (zero-or-more (in " \t"))
                (group (or (>= 3 ?`) (>= 3 ?~)))
                (zero-or-more not-newline) line-end)
            limit t)
      (let* ((fence (match-string 1))
             (char (aref fence 0))
             (len (length fence))
             (opener-beg (match-beginning 1))
             (opener-end (save-excursion
                           (goto-char opener-beg)
                           (line-end-position)))
             (format-beg (save-excursion
                           (goto-char (+ opener-beg len))
                           (when (looking-at (rx (zero-or-more (in " \t"))
                                                 "=" (one-or-more (any "a-zA-Z0-9_-"))))
                             (skip-chars-forward " \t")
                             (point))))
             (format-end (and format-beg (match-end 0)))
             (closer-re (concat "^[ \t]*" (regexp-quote (make-string len char))
                                (string char) "*[ \t]*$")))
        ;; Find the closing fence (same char, at least as long).
        (if (re-search-forward closer-re limit t)
            (let ((closer-beg (match-beginning 0))
                  (closer-end (match-end 0)))
              ;; Match data: 0=all 1=opener line 2=body 3=closer 4=raw format.
              (set-match-data
               (list opener-beg closer-end
                     opener-beg opener-end                 ; opener line
                     (min (1+ opener-end) closer-beg) closer-beg ; body
                     closer-beg closer-end                 ; closer
                     (or format-beg opener-beg)            ; raw `=FORMAT'
                     (or format-end opener-beg)))
              (throw 'done t))
          ;; Unterminated fence: color to LIMIT and stop.
          (set-match-data
           (list opener-beg limit
                 opener-beg (line-end-position) (point) (point)
                 (point) (point)
                 (or format-beg opener-beg) (or format-end opener-beg)))
          (goto-char limit)
          (throw 'done t))))
    nil))

(defun carve--fontify-comment-blocks (limit)
  "Search for a `%%%\'-fenced comment block between point and LIMIT.
Group 1 is the whole block, opener and closer included.

THE BODY OF A COMMENT FENCE IS NOT CARVE.  The syntax table makes each
`%%%\' line a comment to end of line, which left the lines BETWEEN them
ordinary text: `*b*\' inside a comment block came back bold, so the buffer
claimed an emphasis run inside a block that renders nothing.  A per-line
rule cannot see the pairing, so this walks it the way the fenced-code
matcher does.

THE CLOSER IS AN EXACT LENGTH MATCH, not the code fence\'s at-least-as-long
\(spec PART 9 section 2\), and an UNCLOSED opener is a plain comment line
\(section 28\) - so a run with no closer is left to the line rule rather
than swallowing the rest of the buffer."
  (catch 'done
    (while (re-search-forward
            (rx line-start (zero-or-more (in " \t"))
                (group "%%" (one-or-more "%"))
                (zero-or-more not-newline) line-end)
            limit t)
      (let* ((fence (match-string 1))
             (opener-beg (match-beginning 1))
             (closer-re (concat "^[ \t]*" (regexp-quote fence) "[^%\n]*$")))
        (when (re-search-forward closer-re limit t)
          (set-match-data (list opener-beg (match-end 0)
                                opener-beg (match-end 0)))
          (throw 'done t))
        (goto-char (line-end-position))))
    nil))

(defconst carve--hyphen-run-re
  (rx (group (>= 2 "-")) (not (any "-")))
  "Match a run of two or more hyphens, bounded on the right.")

(defun carve--fontify-hyphen-run (limit)
  "Search for a converting hyphen run between point and LIMIT.

A HYPHEN RUN OPENING A WORD AFTER WHITESPACE IS A FLAG, NOT A DASH
\(markup-carve/carve#1443\): whitespace or start-of-line before the run and
a non-whitespace character after it means the run stays literal, which is
what keeps `git log --oneline\' a flag.  Every other position converts, and
the LENGTH decides into what - which this does not need to know, because
the em dash and the en dash are the same face.

The guard is why this is a function: it is a condition on both sides of the
run at once, and an Emacs regexp has no lookaround to spell it with."
  (catch 'done
    (while (re-search-forward carve--hyphen-run-re limit t)
      (let* ((beg (match-beginning 1))
             (end (match-end 1))
             (before (if (> beg (point-min)) (char-before beg) ?\n))
             (after (char-after end))
             (space-before (memq before '(?\s ?\t ?\n ?\xa0)))
             (word-after (and after (not (memq after '(?\s ?\t ?\n ?\xa0))))))
        (goto-char end)
        (unless (and space-before word-after)
          (set-match-data (list beg end beg end))
          (throw 'done t))))
    nil))

;;;; Font-lock keywords

(defconst carve-font-lock-keywords
  `(
    ;; Code block, raw block, math block.
    ;; The fences, kept early so their bodies are not re-fontified by inline
    ;; rules.  Group 4 is the
    ;; `=FORMAT' token of a RAW block, which is what tells one from a code
    ;; block: its body reaches the output verbatim instead of escaped.  It is
    ;; a group of this matcher rather than a rule of its own so that it can
    ;; only ever fire on a real opener - a rule matching the same shape would
    ;; also match a fence-shaped LINE inside another block's verbatim body.
    (carve--fontify-fenced-blocks
     (1 'carve-code-face)
     (2 'carve-code-face keep)
     (3 'carve-code-face)
     (4 'carve-attribute-face t))

    ;; Comment block: a `%%%' fence and everything between it and its closer.
    ;;
    ;; The syntax table already makes each FENCE line a comment; this is what
    ;; makes the BODY one.  Kept beside the code fence and for the same reason:
    ;; both hold a payload that is not Carve, and an inline rule reaching into
    ;; either paints a claim the document does not make.
    (carve--fontify-comment-blocks
     (1 'font-lock-comment-face keep))

    ;; Frontmatter at document start: ---, ---toml, ---json ... ---
    (carve--fontify-frontmatter
     (0 'carve-frontmatter-face keep))

    ;; ATX headings.
    (,carve--heading-re
     (1 'carve-markup-face)
     (3 'carve-heading-face))

    ;; Comment line.
    ;; A `%%' run at the start of a line, to end of line.  It paints the fence
    ;; lines of the block above too, which is why that one only has to reach
    ;; the body.
    (,(rx line-start (zero-or-more (in " \t"))
          "%%" (zero-or-more not-newline) line-end)
     (0 'font-lock-comment-face))

    ;; Block-attribute line: {#id .class key=val} on its own line.  The payload
    ;; is STRICT (PART 9 S14): each item is .class / #id / key=value / a bare
    ;; key, and an identifier never starts with a digit.  Without that, any
    ;; braced span alone on a line -- a forced `{/a/b/}`, say -- was swallowed
    ;; here as an attribute block.
    (,(let* ((ident '(seq (any "a-zA-Z_") (zero-or-more (any "a-zA-Z0-9_-"))))
             (value '(or (seq "\"" (zero-or-more (not (any ?\"))) "\"")
                         (seq "'" (zero-or-more (not (any ?'))) "'")
                         (one-or-more (not (any " \t\"'{}")))))
             ;; The language attribute (markup-carve/carve#1114): a colon, then
             ;; an optional tag of 1-8 alphanumeric subtags joined by hyphens.
             ;; It is the ONE item that opens with a colon, and the payload here
             ;; is validated as a whole, so an item the alternation does not know
             ;; leaves the entire line unfontified rather than losing one token.
             (lang-item '(seq ":" (opt (seq (repeat 1 8 (any "a-zA-Z0-9"))
                                            (zero-or-more
                                             (seq "-" (repeat 1 8 (any "a-zA-Z0-9"))))))))
             (item `(or ,lang-item
                        (seq (any ".#") ,ident)
                        (seq ,ident (opt "=" ,value)))))
        (rx-to-string
         `(seq line-start (zero-or-more space)
               (group "{" (zero-or-more space) ,item
                      (zero-or-more (seq (one-or-more space) ,item))
                      (zero-or-more space) "}")
               (zero-or-more space) line-end)))
     (1 'carve-attribute-face))

    ;; Composite figure: a BARE `::: figure' opener (PART 9 §4c,
    ;; markup-carve/carve#1215; tracked as markup-carve/carve-grammars#222).
    ;;
    ;; The kind word `figure' is RESERVED among the `:::' types: a bare opener -
    ;; the fence, its separator, the word `figure', and NOTHING else - is ONE
    ;; figure of ordered panels, a different construct from the generic
    ;; container, so it gets its own face.  This sits BEFORE the generic div rule
    ;; because `font-lock-keywords' are applied in order and a later keyword does
    ;; not override a face an earlier one already applied.
    ;;
    ;; THE TAIL OF THE LINE IS THE WHOLE DISTINCTION.  An opener carrying a
    ;; quoted title or a `[label]' (`::: figure "T"', `::: figure [g]') is not
    ;; this production at all and falls through to the rule below, which is the
    ;; generic container the clause says it stays - unchanged, metadata and all.
    ;;
    ;; THE SEPARATOR IS A SPACE RUN, never a tab (grammar.ebnf PART 7, MARKER
    ;; SEPARATORS; corpus 254 renders `:::<TAB>note' as a paragraph).  So it is
    ;; `(one-or-more " ")' and deliberately NOT the `(zero-or-more space)' the
    ;; generic rule below uses - `space' in `rx' is `[[:space:]]', which admits a
    ;; tab.  A tab-separated `:::<TAB>figure' therefore falls to that rule and
    ;; reads exactly as it did before this one existed.  Trailing whitespace
    ;; after the kind word is insignificant and may be a tab.
    ;;
    ;; RESIDUAL, written down rather than left to be rediscovered: GROUPS DO NOT
    ;; NEST - a bare `::: figure' at any depth inside an open group is a generic
    ;; container - and this rule cannot see that, because every rule in this list
    ;; is a flat per-line regexp with no container state, so a nested bare opener
    ;; over-fontifies as a group.  Same limit applies to the group caption: the
    ;; `^ ' line below the CLOSING fence is a caption only for this container
    ;; kind, and the caption rule further down claims it after any `:::' closer.
    ;; It has always done so, which is why the caption position already works
    ;; here; making it exact needs a real container model, which is
    ;; tree-sitter-carve's job rather than font-lock's.
    (,(rx line-start (zero-or-more (in " \t")) (group (>= 3 ?:))
          (one-or-more " ")
          (group "figure")
          (zero-or-more (in " \t")) line-end)
     (1 'carve-figure-group-face)
     (2 'carve-figure-group-face))

    ;; Local hard-break block: `::: \', a RECOGNIZED `:::' type whose body
    ;; turns every soft break in its direct paragraph children into a hard
    ;; break (grammar PART 2, `local_hard_break_block').
    ;;
    ;; It is the one container whose kind word is punctuation, and the generic
    ;; rule below reads its kind word as a run of `[a-zA-Z0-9_|]' - so the
    ;; backslash matched the EMPTY tail of that run and came back as prose,
    ;; indistinguishable from a fence with no type at all.  The separator is a
    ;; space run and never a tab, for the reason spelled out on the figure rule
    ;; above.
    (,(rx line-start (zero-or-more (in " \t")) (group (>= 3 ?:))
          (one-or-more " ")
          (group "\\")
          (zero-or-more (in " \t")) line-end)
     (1 'carve-admonition-face)
     (2 'carve-admonition-face))

    ;; Line block: `::: |', the verse container that keeps its line structure.
    ;;
    ;; Its kind word is inside the generic rule's character class, so the fence
    ;; and the pipe were already painted at column zero - but only there.  An
    ;; INDENTED `::: |' fell through to the table rule, which took the pipe for
    ;; a cell delimiter: a verse container read as a one-column table.
    (,(rx line-start (zero-or-more (in " \t")) (group (>= 3 ?:))
          (one-or-more " ")
          (group "|")
          (zero-or-more (in " \t")) line-end)
     (1 'carve-admonition-face)
     (2 'carve-admonition-face))

    ;; Fenced divs and admonitions: ::: type "Title" [Label]
    (,(rx line-start (zero-or-more (in " \t")) (group (>= 3 ?:))
          (zero-or-more space)
          (group (zero-or-more (any "a-zA-Z0-9_|")))
          (zero-or-more not-newline) line-end)
     (1 'carve-admonition-face)
     (2 'carve-admonition-face))

    ;; Table.
    ;; The header marker |= |=> |=~ and the plain pipes.
    (,(rx (group "|" (opt "=") (opt (any "<>~"))))
     (1 'carve-table-face))

    ;; Blockquote markers and caption lines.
    ;;
    ;; The marker takes a SPACE, or stands alone on its line. Verified against
    ;; carve-rs: `>no space', `>>x', `>> x' and `>\tx' are all paragraphs -
    ;; nesting is written `> > x', a space per marker, and a tab does not
    ;; separate (markup-carve/carve#525). Without the lookahead this fontified
    ;; the marker in `>>= operator' and `>=3 items', which the language calls
    ;; prose.
    (,(rx line-start (zero-or-more (in " \t")) (group ">")
          (or " " line-end))
     (1 'carve-blockquote-face))
    (,(rx line-start (zero-or-more (in " \t")) (group "^") (one-or-more " ")
          (not (any " \t\n")))
     (1 'carve-markup-face))

    ;; Task list items: - [ ] / - [x] (marker + checkbox).
    ;; The checkbox needs content after it, or it does not form: carve-rs and
    ;; carve-js both render `- [ ] ' (nothing after) as `<ul><li>[ ]</li></ul>',
    ;; a plain bullet holding the literal `[ ]'.
    (,(rx line-start (zero-or-more (in " \t"))
          (group (any "-*+")) (one-or-more " ")
          (group "[" (any ?\s ?x ?X ?_ ?- ?> ??) "]")
          (one-or-more " ") (not (any " \t\n")))
     (1 'carve-list-marker-face)
     (2 'carve-markup-face))

    ;; Ordered list markers: 1. 1) a. i., and the BARE DOT.
    ;;
    ;; `.` continues an ordered sequence, and is the only marker allowed to
    ;; drop its VALUE - the number (carve#472). It still needs content:
    ;; carve-rs renders `. ` as `<p>.</p>`, like every content-less marker. The lookahead also admits a marker glued
    ;; to an attribute block - `.{#x}`, `3.{#x k=v}` - which is how the corpus
    ;; writes those.
    (,(rx line-start (zero-or-more space)
          (group (or (seq (or (one-or-more digit) (any "a-zA-Z")) (any ".)"))
                     "."))
          (or (seq (one-or-more " ") (not (any " \t\n"))) "{"))
     (1 'carve-list-marker-face))

    ;; Bullet list markers: - * + followed by a space and content.
    (,(rx line-start (zero-or-more (in " \t")) (group (any "-*+"))
          (one-or-more " ") (not (any " \t\n")))
     (1 'carve-list-marker-face))

    ;; Definition list: :: term  /  :  definition
    (,(rx line-start (zero-or-more (in " \t"))
          (group (or "::" ":")) (one-or-more " ")
          (not (any " \t\n")))
     (1 'carve-markup-face))

    ;; Footnote definition: [^id]:
    (,(rx line-start (zero-or-more (in " \t"))
          (group "[^" (one-or-more (not (any "]"))) "]" ":"))
     (1 'carve-footnote-face))

    ;; Reference definition: [label]: url
    ;;
    ;; Named for the definition and nothing else.  It used to read "Reference /
    ;; link definition", and a rule that matches only a definition line was the
    ;; nearest thing in this file to the words "reference link" - so the
    ;; construct ledger cited it as the evidence that this mode highlights a
    ;; reference LINK, one construct over (markup-carve/emacs-carve#19).
    (,(rx line-start (zero-or-more (in " \t"))
          (group "[" (one-or-more (not (any "]"))) "]" ":"))
     (1 'carve-footnote-face))

    ;; Abbreviation definition: *[TERM]: expansion
    ;;
    ;; An invisible block, like the two definitions above: it renders nothing
    ;; where it sits and supplies the title for every later occurrence of the
    ;; term.  The term is a SINGLE alphanumeric word (grammar PART 5) - a
    ;; bracketed term holding a space or a dot is not a definition and the line
    ;; stays prose, so the character class is what does the rejecting.
    (,(rx line-start (zero-or-more (in " \t"))
          (group "*[" (one-or-more (any "a-zA-Z0-9")) "]" ":")
          (one-or-more " ") (not (any " \t\n")))
     (1 'carve-markup-face))

    ;; Footnote reference.
    ;; [^id], a reference to a footnote defined elsewhere.
    (,(rx (group "[^" (one-or-more (not (any "]"))) "]"))
     (1 'carve-footnote-face))

    ;; Inline footnote.
    ;; `^[content]' carries its own text (markup-carve/carve#404) and had no
    ;; rule: the row read as implemented on the strength of the REFERENCE rule
    ;; above, one construct over, and the run itself came back as prose.
    (,(rx (group "^[") (group (zero-or-more (not (any "]\n")))) (group "]"))
     (1 'carve-footnote-face)
     (2 'carve-link-text-face)
     (3 'carve-footnote-face))

    ;; Reference image and collapsed reference image.
    ;; ![alt][ref] and ![alt][].
    ;;
    ;; An image has the same three spellings a link has, and only the inline
    ;; one had a rule - so `![alt][ref]' was claimed by the reference LINK rule
    ;; below, which starts one character to the right: the `!' was left as
    ;; prose and the whole thing read as a link to a reference.  The label is
    ;; starred, so the collapsed form is the same match with nothing between
    ;; the second pair of brackets.
    (,(rx (group "!" "[") (group (zero-or-more (not (any "]")))) (group "]")
          (group "[") (group (zero-or-more (not (any "]")))) (group "]"))
     (1 'carve-markup-face)
     (2 'carve-link-text-face)
     (3 'carve-markup-face)
     (4 'carve-markup-face)
     (5 'carve-url-face)
     (6 'carve-markup-face))

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

    ;; Inline link.
    ;; [text](url), and the titled form.
    (,(rx (group "[") (group (zero-or-more (not (any "]")))) (group "]")
          (group "(") (group (zero-or-more (not (any ")")))) (group ")"))
     (1 'carve-markup-face)
     (2 'carve-link-text-face)
     (3 'carve-markup-face)
     (4 'carve-markup-face)
     (5 'carve-url-face)
     (6 'carve-markup-face))
    ;; Reference link and collapsed reference link.
    ;; [text][ref] and [text][].
    ;;
    ;; One rule for both: the second label is starred, so an empty one matches
    ;; as readily as a named one.  Written down because the collapsed spelling
    ;; is a construct of its own in the grammar, and a rule nobody names reads
    ;; as a construct nobody implemented.
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

    ;; Inline literal: !`...`  (a `!' prefix on a verbatim span; renders as
    ;; literal prose, not code -- mirrors the `$'-math prefix above).  Kept
    ;; before the inline code span so the `!'+backtick run is claimed as one
    ;; unit and the `!' is not left as stray prose.
    (,(rx (group "!`" (minimal-match (zero-or-more not-newline)) "`"))
     (1 'carve-code-face))

    ;; Raw inline code: `code`{=html}
    (,(rx (group "`" (minimal-match (one-or-more not-newline)) "`")
          (group "{=" (one-or-more (any "a-zA-Z")) "}"))
     (1 'carve-code-face)
     (2 'carve-attribute-face))

    ;; Code span.
    ;; The inline `code` run.
    (,(rx (group "`" (minimal-match (one-or-more (not (any "`")))) "`"))
     (1 'carve-code-face keep))

    ;; Escaped char: a backslash before an ASCII punctuation character.
    ;;
    ;; The pair is markup: the backslash is consumed and the character is
    ;; literal, so `\\*not bold\\*' is four words and no emphasis.  Claiming the
    ;; pair is also what ENFORCES that - font-lock does not override a face an
    ;; earlier keyword set, and a delimiter that already carries this face can
    ;; no longer open a run for the emphasis rules further down.
    ;;
    ;; It sits after the verbatim rules on purpose: inside a code span a
    ;; backslash is content, and those rules have already claimed it.
    (,(rx (group "\\" (any "!-/:-@[-`{-~")))
     (1 'carve-markup-face))

    ;; Hard break: a backslash at the end of a line.
    ;;
    ;; The one inline mark that leaves nothing behind when rendered, which is
    ;; exactly why it wants a face: an accidental trailing backslash and a
    ;; deliberate line break looked identical.  A newline is not punctuation,
    ;; so the escape rule above cannot reach it.
    (,(rx (group "\\") line-end)
     (1 'carve-markup-face))

    ;; Braced comment.
    ;; The delimited comment `{% ... %}' (PART 9 S21a,
    ;; markup-carve/carve#1239).  It hides its payload the way `%%' hides the
    ;; rest of a line, so the whole run takes the comment face and the emphasis
    ;; rules below never reach inside: `{% *not bold* %}' must not colour a bold
    ;; run.  It sits AFTER the inline code span rule on purpose -- font-lock
    ;; applies keywords in order and does not override a face already set, so a
    ;; `{%' inside `` ` `` stays code -- and BEFORE the emphasis rules, so the
    ;; payload is claimed before they see it.
    (,(rx "{%" (minimal-match (zero-or-more not-newline)) "%}")
     (0 'font-lock-comment-face))

    ;; Addition: {+ins+}
    ;;
    ;; The four editorial constructs were one rule under one name, so four rows
    ;; of the construct ledger read as unimplemented while the colour was
    ;; already there (markup-carve/emacs-carve#19).  Splitting them is what
    ;; lets each say what it is; the face stays shared, because the reader's
    ;; question is whether a run is editorial markup at all.
    ;;
    ;; EVERY ONE REQUIRES CONTENT.  An empty brace pair is TEXT, not an empty
    ;; edit (markup-carve/carve#1447): `{++}' and `{##}' render literally, and
    ;; the combined rule painted both as markup because its content was a
    ;; `zero-or-more'.
    (,(rx (group "{+" (minimal-match (one-or-more not-newline)) "+}"))
     (1 'carve-critic-face))

    ;; Deletion: {-del-}
    (,(rx (group "{-" (minimal-match (one-or-more not-newline)) "-}"))
     (1 'carve-critic-face))

    ;; Substitution: {~old~>new~}
    ;;
    ;; A `{~x~}' with NO `~>' arrow is a forced strikethrough, not a
    ;; substitution, so the arrow is required.
    (,(rx (group "{~" (minimal-match (zero-or-more not-newline)) "~>"
                 (minimal-match (zero-or-more not-newline)) "~}"))
     (1 'carve-critic-face))

    ;; Editorial comment: {# comment #}
    (,(rx (group "{#" (minimal-match (one-or-more not-newline)) "#}"))
     (1 'carve-critic-face))

    ;; The BRACED (forced) spellings: `{*x*}' emphasizes intraword, where the
    ;; bare `*x*' obeys the word-boundary rules (PART 9 S22).  Every mark has
    ;; one, and superscript and subscript have ONLY this form - a bare `^' or
    ;; `,' is literal text.
    ;;
    ;; SEVEN RULES RATHER THAN ONE, and the reason is what they paint.  A
    ;; single rule keyed on a back-reference cannot tell which delimiter it
    ;; matched, so all seven took `carve-markup-face': a forced bold read the
    ;; same as a forced strikethrough, and neither read like the bare spelling
    ;; it means.  Split, each one carries the face of the mark it is - and each
    ;; is named, which is what the construct ledger could not see before
    ;; (markup-carve/emacs-carve#19).
    ;;
    ;; The content is `one-or-more', so an empty pair stays text: `{^^}' and
    ;; `{**}' are prose, the same ruling the editorial rules above follow.

    ;; Forced strong: {*...*}
    (,(rx (group "{*" (minimal-match (one-or-more not-newline)) "*}"))
     (1 'carve-bold-face))

    ;; Forced emphasis: {/.../}
    (,(rx (group "{/" (minimal-match (one-or-more not-newline)) "/}"))
     (1 'carve-italic-face))

    ;; Forced underline: {_..._}
    (,(rx (group "{_" (minimal-match (one-or-more not-newline)) "_}"))
     (1 'carve-underline-face))

    ;; Forced strike: {~...~}
    (,(rx (group "{~" (minimal-match (one-or-more not-newline)) "~}"))
     (1 'carve-strike-face))

    ;; Forced highlight: {=...=}
    (,(rx (group "{=" (minimal-match (one-or-more not-newline)) "=}"))
     (1 'carve-highlight-face))

    ;; Superscript: {^...^}
    (,(rx (group "{^" (minimal-match (one-or-more not-newline)) "^}"))
     (1 'carve-markup-face))

    ;; Subscript: {,...,}
    (,(rx (group "{," (minimal-match (one-or-more not-newline)) ",}"))
     (1 'carve-markup-face))

    ;; Inline span.
    ;; `[text]{.c}' - a bracketed run whose only job is to carry the attribute
    ;; block that follows it.  The block itself is the rule below; the brackets
    ;; had nothing, so the row cited the CODE span rule.  The `{' is what
    ;; distinguishes the span from a link, so it is required and not consumed.
    (,(rx (group "[") (group (zero-or-more (not (any "][\n")))) (group "]")
          "{")
     (1 'carve-markup-face)
     (2 'carve-link-text-face)
     (3 'carve-markup-face))

    ;; Inline attribute block attached to a node: {.class #id key=val}
    ;;
    ;; The language branch is spelled out rather than folded into the leading
    ;; `.#' class, because Emacs regexps have no lookahead and the tag has a
    ;; LENGTH limit: a subtag is at most eight characters, so `{:toolongtag}'
    ;; is prose.  Letting the trailing `}' do the anchoring is what rejects it -
    ;; the tag can only be followed by the closing brace or by a further item.
    ;;
    ;; The payload excludes the newline in both branches.  An INLINE block may
    ;; not cross a line (markup-carve/carve#897 - only the standalone attribute
    ;; LINE continues), and without that exclusion an unclosed block ran on
    ;; through the prose below it to the next `}' anywhere in the buffer.
    ;;
    ;; The FIRST character after the `.' or `#' is a strict identifier start,
    ;; the way it is on the attribute LINE above.  Without it `{##}' read as an
    ;; id of `#': an EMPTY BRACE PAIR IS TEXT (markup-carve/carve#1447), and
    ;; this rule was the last one still claiming one.
    (,(let ((lang-item '(seq ":" (opt (seq (repeat 1 8 (any "a-zA-Z0-9"))
                                           (zero-or-more
                                            (seq "-" (repeat 1 8 (any "a-zA-Z0-9")))))))))
        (rx-to-string
         `(group "{" (or (seq (any ".#") (any "a-zA-Z_")
                              (zero-or-more (not (any "}{\n"))))
                         (seq ,lang-item
                              (opt (seq (one-or-more (any " \t"))
                                        (one-or-more (not (any "}{\n")))))))
                 "}")))
     (1 'carve-attribute-face))

    ;; Bold italic: the combined `/*...*/' opener.
    ;;
    ;; One construct, not a bold nested in an italic: the boundary guards apply
    ;; to the outer `/' and the inner `*' is part of a two-character token.  It
    ;; has to precede the bare italic rule below, which matched `/*both*/' as a
    ;; plain italic - a run painted as one mark when the renderer gives it two.
    (,(rx (or bol space (any "([{"))
          (group "/*" (minimal-match (one-or-more (not (any "\n")))) "*/"))
     (1 'carve-bold-italic-face))

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

    ;; Extension inline: :name[content]
    ;;
    ;; The name must start with a letter or `_' (grammar PART 3), so `:1[x]' is
    ;; literal text - which is what the character classes here say.  Distinct
    ;; from the `:name:' symbol below by its closing bracket, and from a
    ;; definition-list line by having no space after the colon.
    (,(rx (group ":" (any "a-zA-Z_") (zero-or-more (any "a-zA-Z0-9_-")))
          (group "[") (group (zero-or-more (not (any "]\n")))) (group "]"))
     (1 'carve-markup-face)
     (2 'carve-markup-face)
     (3 'carve-link-text-face)
     (4 'carve-markup-face))

    ;; Symbol shortcodes :name: (word boundary; first name char is a letter,
    ;; digit, `+` or `-`, so `:+1:` / `:-1:` match but `:_x:` stays literal).
    (,(rx (or bol space (any "([")) (group ":" (any "a-zA-Z0-9+-") (zero-or-more (any "a-zA-Z0-9_+-")) ":"))
     (1 'carve-symbol-face))

    ;; Thematic break.  Leading whitespace is allowed: a break can open inside
    ;; a container, where the content column is not zero, and Carve has no
    ;; indented code block to disambiguate against.
    (,(rx line-start (zero-or-more (in " \t"))
          (group (or (>= 3 ?-) (>= 3 ?*) (>= 3 ?_)))
          (zero-or-more space) line-end)
     (1 'carve-markup-face))

    ;; THE TYPOGRAPHIC REPLACEMENTS (PART 9 S8).  Every rule below matches a run the
    ;; renderer REPLACES with a character the author did not type, so the face
    ;; is on the source spelling rather than on any markup: it is the only way
    ;; the buffer can show that `-->' will not survive as three characters.
    ;;
    ;; They come LAST in this list, after every verbatim and every block rule,
    ;; because font-lock does not override a face an earlier keyword set - so a
    ;; `--' inside a code span, a comment, a URL or a thematic break is already
    ;; claimed and stays claimed.  Longest-first within the family, so `<-->'
    ;; is one arrow rather than an arrow and a dash.

    ;; Braced en dash `{--}'.
    ;; It is an EN DASH, not an empty deletion (markup-carve/carve#1447).
    ;; It exists for the position the flag guard leaves unspellable - a dash
    ;; with whitespace before it and a word after it.  It leads the family
    ;; because it is the longest token in it: the hyphen-run rule below sees a
    ;; `--' left-flanked by the opening brace and would convert that, leaving the
    ;; braces as prose.
    (,(rx (group "{--}"))
     (1 'carve-typographic-face))

    ;; Smart arrows: <--> <-- --> <=> <== ==>, and the deprecated <-> <- ->
    (,(rx (group (or "<-->" "<--" "-->" "<=>" "<==" "==>" "<->" "<-" "->")))
     (1 'carve-typographic-face))

    ;; Comparison: != <= >=
    (,(rx (group (or "!=" "<=" ">=")))
     (1 'carve-typographic-face))

    ;; Em dash, en dash.
    ;; A hyphen run, minus the flag shapes.
    (carve--fontify-hyphen-run
     (1 'carve-typographic-face))

    ;; Ellipsis: ...
    (,(rx (group "..."))
     (1 'carve-typographic-face))

    ;; Typographic symbols: (c) (r) (tm) +-
    (,(rx (group (or "(c)" "(r)" "(tm)" "+-")))
     (1 'carve-typographic-face))
    )
  "Font-lock keywords for `carve-mode'.")

;;;; Constructs this mode does not fontify, and why
;; The rest of the language has a rule above.  These do not, and each line says
;; what the obstacle is rather than that there is one - a construct with no
;; rule and no reason is indistinguishable from one nobody looked at
;; (markup-carve/emacs-carve#19).
;; `paragraph'     - the fallback block.  It has no marker and no delimiter,
;;                   and its content is the default face by definition, so
;;                   there is nothing for a rule to match or to paint.
;; `blank_line'    - carries no marker of its own.
;; `soft_break'    - a newline inside a paragraph; same reason.
;; `smart_quote'   - the construct is EVERY `"' and `'' in prose.  A rule for
;;                   it would put a face on the apostrophe of every
;;                   contraction, and it cannot separate the quote an author
;;                   means from the one inside a word: the information a face
;;                   would add is already in the character.  This is the one
;;                   entry here that is a judgement rather than an obstacle -
;;                   the whole rest of the typographic family IS painted above,
;;                   and adding this one is one regexp.  RULED, not pending:
;;                   markup-carve/emacs-carve#23 settled it as a deliberate
;;                   non-rule, which is why the ledger row is UNSUPPORTED with
;;                   this reason rather than a GAP waiting on someone.  One
;;                   regexp and a row edit overturn it if the call changes.
;; NOT ON THIS LIST, because they are over-approximations rather than gaps:
;; every block opener here allows a leading indent, and a per-line rule cannot
;; tell a container's content column from a stray indent at the top level,
;; where the language says an indented opener is literal text.  See the
;; README's "Known limitations".
;; ONE UNBROKEN COMMENT BLOCK, deliberately.  The construct ledger reads the
;; FIRST line after every gap in a comment run as a rule name, so a blank `;;'
;; line here would put these sentences into this surface's rule vocabulary and
;; seed the very rows they deny - `paragraph' read as implemented, citing the
;; line that says it is not.

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

;;;; Syntax propertizing

;; WHY THIS PASS EXISTS.
;;
;; `%' carries the comment-start flags in the syntax table below, so `%%'
;; opens a comment to end of line ANYWHERE in the buffer, with no regard for
;; what it sits inside.  Syntactic fontification runs BEFORE the font-lock
;; keywords and the keywords are non-override, so the comment face wins a
;; region no later rule can take back: a `%%' in a code span, in a link label
;; or in a fenced body claimed the rest of its line and the span, the link or
;; the block stopped being one (markup-carve/emacs-carve#22).  No ordering of
;; the keywords reaches that, because the face is already there when they run.
;; Only the syntax properties do, which is what this pass writes.
;;
;; WHAT IT WRITES.  Punctuation syntax on a `%' that cannot open a comment
;; where it stands.  A two-character comment opener whose first character is
;; punctuation opens nothing, so clearing the flags on the `%' is the whole
;; mechanism - no other character's syntax is touched, and the comment
;; constructs that ARE comments keep working unchanged.
;;
;; ONE PASS OVER THE WHOLE BUFFER, and that is a deliberate cost.  The state
;; this needs is block state: whether a line sits inside a fence is a fact
;; about every line above it, and there is no cheaper honest place to start
;; than the top.  `carve--syntax-propertize-extend-region' therefore widens
;; every request to the whole buffer, which also means the buffer is scanned
;; ONCE per change rather than once per font-lock chunk.

(defconst carve--verbatim-fence-re
  (rx line-start (zero-or-more (in " \t"))
      (group (or (>= 3 ?`) (>= 3 ?~)))
      (zero-or-more not-newline) line-end)
  "Match a line that opens a code, raw, or math fence.
Group 1 is the delimiter run.  The same shape as the matcher in
`carve--fontify-fenced-blocks\\=', deliberately: the region protected here is
the region that matcher paints, and two spellings of one rule drift.")

(defconst carve--comment-fence-re
  (rx line-start (zero-or-more (in " \t"))
      (group "%%" (one-or-more "%"))
      (zero-or-more not-newline) line-end)
  "Match a line that opens or closes a `%%%\\=' comment fence.")

(defconst carve--blank-line-re
  (rx line-start (zero-or-more (in " \t")) line-end)
  "Match a line with no content.")

(defun carve--inert-percent (beg end)
  "Clear the comment-start flags on every `%\\=' between BEG and END."
  (save-excursion
    (goto-char beg)
    (while (search-forward "%" end t)
      (put-text-property (1- (point)) (point)
                         'syntax-table (string-to-syntax ".")))))

(defun carve--closing-backtick-run (from limit len)
  "Return the start of the first run of exactly LEN backticks in [FROM, LIMIT).
Return nil when there is none.  EXACTLY LEN, because a run of a different
length does not close this one: `a ``x `y` z`` w\\=' is one span whose payload
holds a literal backtick pair."
  (save-excursion
    (goto-char from)
    (catch 'found
      (while (search-forward "`" limit t)
        (let ((run-beg (1- (point))))
          (skip-chars-forward "`" limit)
          (when (= (- (point) run-beg) len)
            (throw 'found run-beg))))
      nil)))

(defun carve--propertize-backtick-run (limit)
  "Point is on the first backtick of a run; protect its payload and step over it.
A backtick run is verbatim - a code span, an inline literal, a math run or a
raw inline - and the spec says so in as many words: code spans protect their
content, and `%%\\=' inside one is literal.  An UNPARTNERED run is a span to the
end of its PARAGRAPH, which is LIMIT here, so its tail is protected rather
than left live."
  (let* ((beg (point))
         (open-end (progn (skip-chars-forward "`" limit) (point)))
         (len (- open-end beg))
         (close (carve--closing-backtick-run open-end limit len)))
    (if (not close)
        (progn (carve--inert-percent open-end limit)
               (goto-char limit))
      (carve--inert-percent open-end close)
      (goto-char (min limit (+ close len))))))

(defun carve--propertize-autolink (limit)
  "Point is on a `<\\='; protect an autolink's payload and step over it.
An autolink's text IS its destination, so nothing in it is markup: the `%%\\='
of a percent-encoded path is part of the URL."
  (if (and (looking-at (rx "<" (or "http" "mailto:"
                                   (seq (one-or-more (any "a-zA-Z0-9._%+-")) "@"))
                           (zero-or-more (not (any "> "))) ">"))
           (<= (match-end 0) limit))
      (progn (carve--inert-percent (point) (match-end 0))
             (goto-char (match-end 0)))
    (forward-char 1)))

(defun carve--propertize-label (limit)
  "Point is on a `[\\='; protect a link, image or span and step over it.
A bracket run that CLOSES and carries a payload which ALSO closes -
`](dest)\\=', `][ref]\\=' or `]{attrs}\\=' - is a link, an image or a span, and
the line goes on after it: the engine renders `a [x %% y](u) z\\=' as a link
followed by `z\\='.  Anything less is not one, and there the comment really does
reach the end of the line: `a [x %% y] z\\=' and `a [x %% y](u z\\=' both render
`a [x\\='.  So the payload\\='s own closer is required, not just its opener."
  (let* ((close (save-excursion
                  (goto-char (1+ (point)))
                  (catch 'found
                    (while (search-forward "]" limit t)
                      (unless (eq (char-before (1- (point))) ?\\)
                        (throw 'found (1- (point)))))
                    nil)))
         (opener (and close (char-after (1+ close))))
         (closer (cdr (assq opener '((?\( . ")") (?\[ . "]") (?{ . "}")))))
         (payload-end (and closer
                           (save-excursion
                             (goto-char (+ 2 close))
                             (search-forward closer limit t)))))
    (if (not payload-end)
        (forward-char 1)
      ;; The payload is verbatim too: `[x](u%%v)' links to `u%%v'.
      (carve--inert-percent (1+ (point)) payload-end)
      (goto-char payload-end))))

(defun carve--propertize-braced-comment (limit)
  "Point is on the `{\\=' of a `{%\\=' or `{#\\=' run; protect it and step over it.
Both hold a payload the reader is not meant to read as markup, so a `%%\\='
inside one must not open a comment that outlives the closer: `a {% x %% y %} z\\='
renders `a  z\\=', with the `%}\\=' still closing and the `z\\=' still prose."
  (let* ((closer (if (eq (char-after (1+ (point))) ?%) "%}" "#}"))
         (close (save-excursion
                  (goto-char (+ 2 (point)))
                  (search-forward closer limit t))))
    (if close
        (progn (carve--inert-percent (point) close)
               (goto-char close))
      (forward-char 1))))

(defun carve--propertize-percent (limit)
  "Point is on a `%\\='; decide whether the run it starts opens a comment.
A `%%\\=' run is a comment marker only when it is PRECEDED BY WHITESPACE or
starts its line (spec, \"Comments\"): `The value is 50%% increase\\=' stays
literal, which is what keeps a percentage safe.  A run that opens a comment
takes the rest of its line and there is nothing inside it left to protect."
  (let* ((beg (point))
         (run-end (progn (skip-chars-forward "%" limit) (point)))
         (before (if (> beg (point-min)) (char-before beg) ?\n)))
    (if (and (>= (- run-end beg) 2)
             (memq before '(?\s ?\t ?\n)))
        (goto-char (line-end-position))
      (carve--inert-percent beg run-end)
      (goto-char run-end))))

(defun carve--propertize-prose (beg end)
  "Protect every verbatim run between BEG and END.
BEG to END is one paragraph's worth of prose: an inline run may cross a soft
line break but not a blank line, so a paragraph is the widest a `\\=`\\=' run can
reach."
  (goto-char beg)
  (while (< (point) end)
    (let ((char (char-after)))
      (cond
       ;; An escaped character is literal, so `\\%%' opens nothing.
       ((eq char ?\\)
        (when (eq (char-after (1+ (point))) ?%)
          (carve--inert-percent (1+ (point)) (min end (+ 2 (point)))))
        (goto-char (min end (+ 2 (point)))))
       ((eq char ?`) (carve--propertize-backtick-run end))
       ((eq char ?<) (carve--propertize-autolink end))
       ((eq char ?\[) (carve--propertize-label end))
       ((and (eq char ?{) (memq (char-after (1+ (point))) '(?% ?#)))
        (carve--propertize-braced-comment end))
       ((eq char ?%) (carve--propertize-percent end))
       (t (forward-char 1))))))

(defun carve--prose-end (limit)
  "The end of the prose run starting at point, bounded by LIMIT.
A blank line ends it because an inline run does not cross one, and a
fence-shaped line ends it because a fence opens a block wherever it stands."
  (save-excursion
    (forward-line 1)
    (while (and (< (point) limit)
                (not (looking-at carve--blank-line-re))
                (not (looking-at carve--verbatim-fence-re))
                (not (looking-at carve--comment-fence-re)))
      (forward-line 1))
    (min (point) limit)))

(defun carve--syntax-propertize (start end)
  "Write this mode's syntax properties over the region START to END.
Walks blocks, because that is the state the question needs: the body of a
fence is verbatim however many lines it runs for, and an inline run reaches
to the end of its paragraph."
  (save-excursion
    (goto-char start)
    (beginning-of-line)
    (while (< (point) end)
      (cond
       ((looking-at carve--verbatim-fence-re)
        (let* ((fence (match-string 1))
               (char (aref fence 0))
               (len (length fence))
               (closer-re (concat "^[ \t]*" (regexp-quote (make-string len char))
                                  (string char) "*[ \t]*$"))
               (body (min end (1+ (line-end-position))))
               (body-end (save-excursion
                           (goto-char body)
                           (if (re-search-forward closer-re end t)
                               (match-beginning 0)
                             end))))
          (carve--inert-percent body body-end)
          (goto-char body-end)
          (forward-line 1)))
       ;; The body of a comment fence is a comment already, so a `%%' inside
       ;; it opening one more changes nothing about how it reads.
       ((looking-at carve--comment-fence-re) (forward-line 1))
       ((looking-at carve--blank-line-re) (forward-line 1))
       (t (let ((stop (carve--prose-end end)))
            (carve--propertize-prose (point) stop)
            (goto-char stop)))))))

(defun carve--syntax-propertize-extend-region (start end)
  "Widen the region START to END to the whole buffer, or nil when it is already.
See the note above: the pass needs block state, so it starts at the top - and
widening the END too means one scan per change instead of one per chunk."
  (unless (and (= start (point-min)) (= end (point-max)))
    (cons (point-min) (point-max))))

;;;; Syntax table

(defvar carve-mode-syntax-table
  (let ((table (make-syntax-table)))
    ;; `%%' begins a line comment; newline ends it.  The two-character
    ;; sequence is expressed with the `1'/`2' comment flags on `%'.
    (modify-syntax-entry ?% ". 12" table)
    (modify-syntax-entry ?\n ">" table)
    ;; Inline comment.
    ;; The same two entries carry the TRAILING `%%' run attached to content,
    ;; which is a construct of its own: `x %% note' hides the rest of its line
    ;; the way a `%%' line does.  It has no font-lock rule and wants none - the
    ;; syntax table has claimed it before the keywords run - so this is where
    ;; the construct is named.  Its payload is inert for the same reason.
    ;; The claim these two entries make is too WIDE on its own - a `%%' inside
    ;; a code span, a link label or a fenced body opened a comment there too -
    ;; and `carve--syntax-propertize' above is what narrows it back to where
    ;; the language has a comment.
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
        ;; Skip a heading inside a verbatim body by checking for the code
        ;; face.
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
  (setq-local syntax-propertize-function #'carve--syntax-propertize)
  (setq-local syntax-propertize-extend-region-functions
              (list #'carve--syntax-propertize-extend-region))
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
