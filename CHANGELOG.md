# Changelog

All notable changes to carve-mode are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Releases before 0.1.5 are described on the
[releases page](https://github.com/markup-carve/emacs-carve/releases).

## [Unreleased]

## [0.1.9] - 2026-10-23

### Fixed

- On Emacs 27 and 28, fontifying a block-attribute line no longer fails with
  `void-function string-empty-p`; `subr-x` is now loaded (#70).

### Changed

- Faces that set their own weight, slant or underline now inherit `bold`,
  `italic` or `link` instead, so a theme or customization of the parent face
  carries through (#70).
## [0.1.8] - 2026-10-23

### Added

- `csv` and `tsv` fence bodies are highlighted: every field takes a value face
  and the separator the operator face (#64, #65, #66).

### Fixed

- A lone `+` is painted as a continuation marker only at column 0 of its
  container or right after a block opener, where the engine reads one (#67).
- A quote opened on a list item line takes its first-block `+` where the
  engine does (markup-carve/carve#3421): `- > +` is a marker when the next
  line starts a non-list block at column 0, at the line's indent or at the
  quote's column, and `-  > +` is text (#69).
- Every quote marker in a line's opener run is painted: the second `>` of
  `> > q` and the `>` of `- > q` (#69).
- The inline attribute face goes only to an attribute block the engine
  attaches, glued to an element closer; `{.x}` elsewhere in prose is text
  (#63).

## [0.1.7] - 2026-10-15

### Fixed

- `M-q` no longer joins block lines: every block opener starts a paragraph,
  single-line blocks (headings, table rows, fences, container fences, comment
  and attribute lines, thematic breaks) separate, code and comment block
  bodies are left alone, a quote is filled behind its markers and a list item
  wraps under its text (#59).
- A list marker or `^ ` line after a paragraph line is text, and a caption is
  painted only below a block that takes one. A marker after a list item's
  lazy continuation still opens the next item (#59).
- Headings, list markers, definitions, tables and container fences are
  painted inside `> ` quotes (#59).
- A link or image label may wrap inside its paragraph but no longer reaches
  past it, a citation label stays on its line, and a line of unclosed
  brackets is no longer quadratic (#59, #60).
- A `%%` at the start of a label or after a space inside one hides the rest
  of the label only, so the link still forms and the text after it stays
  live; `::: note [%% hidden]` hides its label (#59).
- A tab before `%%` no longer opens a comment, except as indentation (#59).
- An escaped backtick, bracket, `<` or `$` no longer opens a code span, a
  link, an autolink or inline math (#59).
- `|` is table punctuation only on a row that opens and closes with a pipe (#59).
- An emphasis run encloses the runs inside it (`/it *b* it/`), may cross one
  line break, and needs a flanking closer (`*a*b` is text) (#59).
- imenu and outline skip headings inside code and comment blocks, and
  outline no longer matches seven or more `#` (#59).
- Editing a large buffer no longer re-propertizes and re-scans it from the
  top on every keystroke: fence state is cached up to the first change (#59).

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
