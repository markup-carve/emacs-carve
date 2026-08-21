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

;;;; Helper matchers

(defconst carve--heading-re
  ;; MARKER REQUIRES CONTENT, and a RUN of spaces is not content: carve-rs
  ;; renders `#<space><space>' as `<p>#</p>'.  `one-or-more not-newline'
  ;; happily matched those spaces, so the separator was doing the content's
  ;; job.  `(in " \t")' for the separator and `(not (any " \t\n"))' for the
  ;; first content character - the newline in that set is what makes it bite.
  (rx line-start (group (** 1 6 ?#)) (group (one-or-more " "))
      (group (not (any " \t\n")) (zero-or-more not-newline)) line-end)
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
    (,(rx line-start (group (>= 3 ?:))
          (one-or-more " ")
          (group "figure")
          (zero-or-more (in " \t")) line-end)
     (1 'carve-figure-group-face)
     (2 'carve-figure-group-face))

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
    (,(rx line-start (group (or "::" ":")) (one-or-more " ")
          (not (any " \t\n")))
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

    ;; Inline code span: `code`
    (,(rx (group "`" (minimal-match (one-or-more (not (any "`")))) "`"))
     (1 'carve-code-face keep))

    ;; A DELIMITED INLINE COMMENT, `{% ... %}' (PART 9 S21a,
    ;; markup-carve/carve#1239).  It hides its payload the way `%%' hides the
    ;; rest of a line, so the whole run takes the comment face and the emphasis
    ;; rules below never reach inside: `{% *not bold* %}' must not colour a bold
    ;; run.  It sits AFTER the inline code span rule on purpose -- font-lock
    ;; applies keywords in order and does not override a face already set, so a
    ;; `{%' inside `` ` `` stays code -- and BEFORE the emphasis rules, so the
    ;; payload is claimed before they see it.
    (,(rx "{%" (minimal-match (zero-or-more not-newline)) "%}")
     (0 'font-lock-comment-face))

    ;; CriticMarkup: {+ins+} {-del-} {~old~>new~} {# comment #}
    ;; The delimiter set is the literal chars + - ~ # (list each member
    ;; separately so `-' is not read as a range that would also swallow
    ;; brace emphasis such as `{^..^}', `{,..,}', `{=..=}').
    ;; A `{~x~}` with NO `~>` arrow is a forced strikethrough, not a
    ;; substitution, so the tilde form requires the arrow.
    (,(rx (group "{" (or (seq (any "+" "-" "#") (minimal-match (zero-or-more not-newline))
                              (any "+" "-" "#"))
                         (seq "~" (minimal-match (zero-or-more not-newline)) "~>"
                              (minimal-match (zero-or-more not-newline)) "~"))
                 "}"))
     (1 'carve-critic-face))

    ;; Brace emphasis, superscript, and subscript: {^...^} {,...,} {*...*}
    ;; {/.../} {_..._} {~...~} {=...=}.  Superscript and subscript exist only
    ;; in these braced forms; a bare `^' or `,' is literal text.
    (,(rx "{" (group (any "*/_~^,=")) (minimal-match (one-or-more not-newline))
          (backref 1) "}")
     (0 'carve-markup-face))

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
    (,(let ((lang-item '(seq ":" (opt (seq (repeat 1 8 (any "a-zA-Z0-9"))
                                           (zero-or-more
                                            (seq "-" (repeat 1 8 (any "a-zA-Z0-9")))))))))
        (rx-to-string
         `(group "{" (or (seq (any ".#") (one-or-more (not (any "}{\n"))))
                         (seq ,lang-item
                              (opt (seq (one-or-more (any " \t"))
                                        (one-or-more (not (any "}{\n")))))))
                 "}")))
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
