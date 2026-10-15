# Changelog

All notable changes to carve-mode are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Releases before 0.1.5 are described on the
[releases page](https://github.com/markup-carve/emacs-carve/releases).

## [Unreleased]

### Fixed

- `M-q` no longer joins block lines: every block opener starts a paragraph,
  single-line blocks (headings, table rows, fences, container fences, comment
  and attribute lines, thematic breaks) separate, code and comment block
  bodies are left alone, a quote is filled behind its markers and a list item
  wraps under its text.
- A list marker or `^ ` line after a paragraph line is text, and a caption is
  painted only below a block that takes one. A marker after a list item's
  lazy continuation still opens the next item.
- Headings, list markers, definitions, tables and container fences are
  painted inside `> ` quotes.
- A link or image label may wrap inside its paragraph but no longer reaches
  past it, a citation label stays on its line, and a line of unclosed
  brackets is no longer quadratic.
- A `%%` at the start of a label or after a space inside one hides the rest
  of the label only, so the link still forms and the text after it stays
  live; `::: note [%% hidden]` hides its label.
- A tab before `%%` no longer opens a comment, except as indentation.
- An escaped backtick, bracket, `<` or `$` no longer opens a code span, a
  link, an autolink or inline math.
- `|` is table punctuation only on a row that opens and closes with a pipe.
- An emphasis run encloses the runs inside it (`/it *b* it/`), may cross one
  line break, and needs a flanking closer (`*a*b` is text).
- imenu and outline skip headings inside code and comment blocks, and
  outline no longer matches seven or more `#`.
- Editing a large buffer no longer re-propertizes and re-scans it from the
  top on every keystroke: fence state is cached up to the first change.

## [0.1.6] - 2026-10-14

### Fixed

- A `^ text` line before the first block remains prose, including after
  leading blank lines (#57).
- Both package headers declare the release they ship in. 0.1.5 reported
  itself as 0.1.4 to package managers (#56).

## [0.1.5] - 2026-10-08

### Added

- `M-x carve-import-file` converts a Markdown, HTML, Djot or BBCode file to a
  sibling `.crv` and visits it. It takes the format from the extension, asks
  before overwriting, and reports CLI errors in `*Carve Import*` (#42).
- Fence bodies are fontified by their language's own major mode, the way
  `markdown-fontify-code-blocks-natively` does it. Plain body text still reads
  as code and the inline Carve rules stay out.
  `carve-fontify-code-blocks-natively` turns that off, and
  `carve-code-lang-modes` maps language words to modes (#44).

### Fixed

- A block quote reads at document contrast, with a stronger border and its
  attribution aligned to the body it credits (#50).

- The bundled `sample.crv` matches its cross-reference against the id's own
  case. `</#plan>` was written as though it reached a heading `{#Plan}`; names
  compare case exactly from carve 0.1.8, so it did not (#47).
