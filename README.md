# carve-mode

An Emacs major mode for [Carve](https://markup-carve.org), a post-Markdown
markup language whose mnemonic is "the markup looks like its output."

`carve-mode` provides syntax highlighting, a `%%` comment syntax, an imenu
index of headings, outline support, and an optional preview command for `.crv`
and `.carve` files.

## Features

- ATX headings (`#` through `######`) with imenu and `outline-minor-mode`
  support.
- The full mnemonic inline family: `/italic/`, `*bold*`, `_underline_`,
  `~strike~`, `=highlight=`, `^super^`, `,,sub,,`, plus the forced brace forms
  `{^...^}`, `{,...,}`, `{*...*}`, `{/.../}`, `{_..._}`, `{~...~}`, `{=...=}`.
- Inline code `` `code` `` and raw inline `` `x`{=html} ``.
- Links `[text](url)`, titled links, autolinks `<url>` / `<email>`, reference
  links `[text][ref]`, collapsed `[ref][]`, link definitions `[ref]: url`,
  images `![alt](src)`, and cross-references `</#id>`.
- Lists: `-` `*` `+` bullets, `1.` / `1)` / `a.` ordered, task items
  `- [ ]` / `- [x]`, and definition lists (`:: term` / `:  def`).
- Blockquotes `>` and caption / attribution lines `^ ...`.
- Fenced code (` ``` ` and `~~~`) with an optional language, quoted
  `"header"`, and `[label]`; raw fences ` ```=FORMAT `.
- Comments: line comments `%%` and `%%%`-fenced block comments.
- Fenced divs and admonitions `:::` with type words and optional title/label.
- Block-attribute lines `{#id .class key=val}` and inline attribute blocks.
- Tables: `|`, header `|=`, alignment `|=>` / `|=~`, rowspan `^`, colspan `<`.
- Footnotes `[^id]` and definitions `[^id]: ...`.
- Math: inline `` $`...` ``, display `` $$`...` ``, and fenced ` ```math `.
- Frontmatter blocks (`---`, `---toml`, `---json`, ...) at the document start.
- Mentions `@name`, tags `#tag`, and CriticMarkup `{+ins+}` `{-del-}`
  `{~old~>new~}` `{# comment #}`.

## Installation

### Manual

Put `carve-mode.el` on your `load-path` and require it:

```elisp
(add-to-list 'load-path "/path/to/carve-emacs")
(require 'carve-mode)
```

Files ending in `.crv` or `.carve` then open in `carve-mode` automatically.

### use-package

```elisp
(use-package carve-mode
  :load-path "/path/to/carve-emacs"
  :mode ("\\.crv\\'" "\\.carve\\'"))
```

When installed from a package archive, drop the `:load-path`.

## Optional CLI preview

If a `carve` command-line tool is on your `exec-path`, two commands render
Carve to its output format:

- `C-c C-c` (`carve-preview-buffer`) renders the whole buffer.
- `C-c C-r` (`carve-compile-region`) renders the active region.

The mode loads and works fully without the CLI; the preview commands simply
report that the tool is missing. Set `carve-command` to point at a specific
binary if it is not named `carve`.

## Customization

`M-x customize-group RET carve RET` exposes `carve-command` and the faces
(`carve-heading-face`, `carve-bold-face`, `carve-italic-face`, and the rest),
which inherit sensible defaults from the standard font-lock faces.

## Known limitations

Carve's bare-delimiter emphasis obeys context-sensitive word-boundary rules
(see `docs/examples.md` in the Carve repo) that a regexp-based font-lock cannot
fully reproduce. `carve-mode` approximates them by requiring an opener to sit
at the start of a line or after whitespace or an opening bracket, so a handful
of edge cases (intraword literals, unmatched openers spanning lines) may be
highlighted slightly more or less eagerly than the renderer would parse them.
The fontification is a reading aid, not a parser.

## License

MIT. See [LICENSE](LICENSE). Copyright (c) 2026 markup-carve.
