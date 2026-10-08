# Changelog

All notable changes to carve-mode are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Releases before 0.1.5 are described on the
[releases page](https://github.com/markup-carve/emacs-carve/releases).

## [Unreleased]

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

- The bundled `sample.crv` matches its cross-reference against the id's own
  case. `</#plan>` was written as though it reached a heading `{#Plan}`; names
  compare case exactly from carve 0.1.8, so it did not (#47).
