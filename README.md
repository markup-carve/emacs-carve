# carve-mode

An Emacs major mode for [Carve](https://github.com/markup-carve/carve), a post-Markdown
markup language whose mnemonic is "the markup looks like its output."

`carve-mode` provides syntax highlighting, a `%%` comment syntax, an imenu
index of headings, outline support, and an optional preview command for `.crv`
files.

## Features

- Optional language-server support via
  [carve-lsp](https://github.com/markup-carve/carve-lsp): diagnostics, hover,
  completion, go-to-definition, workspace-wide rename, find-references, code
  actions and formatting. See below - it is opt-in and does nothing unless
  you ask for it.
- ATX headings (`#` through `######`) with imenu and `outline-minor-mode`
  support.
- The full mnemonic inline family: `/italic/`, `*bold*`, `_underline_`,
  `~strike~`, `=highlight=`, plus the brace forms `{*...*}`, `{/.../}`,
  `{_..._}`, `{~...~}`, `{=...=}` and the brace-only superscript `{^super^}`
  and subscript `{,sub,}` (a bare `^` or `,` is literal text).
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

Files ending in `.crv` then open in `carve-mode` automatically.

### use-package

```elisp
(use-package carve-mode
  :load-path "/path/to/carve-emacs"
  :mode "\\.crv\\'")
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

## Language server (optional)

`carve-mode` is font-lock: per-line regular expressions with no container
state. That is a reading aid, and the limitations section below names the two
places it costs something. Those are not fixable with a better regexp - they
need a real parse of the document, which is what
[carve-lsp](https://github.com/markup-carve/carve-lsp) has.

What it adds is the class of question no font-lock rule can answer: which
`[^note]` has no definition, which `</#id>` cross-reference points at nothing,
and that `**bold**` is a Markdown habit that renders in Carve as two literal
asterisks around bold text. Plus workspace-wide rename, go-to-definition,
find-references, completion, code actions and formatting.

```sh
npm i -g @markup-carve/carve-lsp
```

```elisp
(require 'carve-lsp)
(carve-lsp-setup)
```

Nothing starts on its own. Loading `carve-lsp.el` registers no hook and starts
no process - attaching a server spawns one, and that is your decision rather
than a side effect of installing a major mode. If the server is not on
`exec-path`, `carve-lsp-setup` is a no-op that RETURNS a reason instead of
signalling, so an init file that calls it stays loadable on a machine that has
never installed it.

Both clients are supported, because Emacs has two and neither is the obvious
default across versions:

| Client | When |
| --- | --- |
| eglot | built in from Emacs 29, a package before that |
| lsp-mode | when eglot is absent and lsp-mode is installed |

`carve-lsp-setup` returns which one it registered with (`eglot` or `lsp-mode`),
or `nil` and a reason.

The workspace root is found by walking up for `.git`. That matters rather than
being a detail: rename and find-references are workspace-wide, so renaming a
heading id updates every cross-reference that points at it - and a server rooted
at the file's own directory would silently narrow that to one folder.

Options:

```elisp
(setq carve-lsp-command '("carve-lsp" "--stdio")) ; the server command
(setq carve-lsp-settings nil)                     ; sent as the `carve' section
(setq carve-lsp-autostart t)                      ; nil registers without hooking
```

Setting `carve-lsp-autostart` to `nil` registers the server with the client but
leaves starting it to you - registration alone is enough if you want it
available rather than automatic.

## Known limitations

Carve's bare-delimiter emphasis obeys context-sensitive word-boundary rules
(see `docs/examples.md` in the Carve repo) that a regexp-based font-lock cannot
fully reproduce. `carve-mode` approximates them by requiring an opener to sit
at the start of a line or after whitespace or an opening bracket, so a handful
of edge cases (intraword literals, unmatched openers spanning lines) may be
highlighted slightly more or less eagerly than the renderer would parse them.
The fontification is a reading aid, not a parser.

Every rule here is a per-line regexp with no container state, which shows up in
two places around composite figures (`::: figure`, PART 9 §4c). A bare
`::: figure` nested inside an open figure group is a generic container in the
language, but `carve-mode` fontifies it as a group. And the `^ ` caption line
below a closing fence is a caption only after a `::: figure` closer; the mode
fontifies it after any `:::` closer. Both are over-approximations rather than
missing highlighting, and both need a real container model to fix - which is
what the language server above has, so enabling it is the answer to this
section rather than a better regexp.
