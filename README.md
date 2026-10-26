# carve-mode

An Emacs major mode for Carve `.crv` files. Package version 0.1.10 requires Emacs 27.1 or later. See the [Carve documentation](https://markup-carve.github.io/carve/) for the markup language.

## Features

- Syntax highlighting and heading navigation.
- Optional CLI preview and `carve-lsp` support.

## Install

Add this repository to `load-path`:

```elisp
(add-to-list 'load-path "/path/to/emacs-carve")
(require 'carve-mode)
```

## Usage

Open a `.crv` file to enter `carve-mode`.

## Documentation

- [Carve documentation](https://markup-carve.github.io/carve/)
- [Setup and full guide](docs/guide.md)
- [Documentation index](docs/README.md)

## License

[MIT](LICENSE)
