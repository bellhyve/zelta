# Zelta Documentation Layout

This directory keeps editable documentation separate from generated manpage output.

## Manpage Sources

The Markdown files in this directory are Pandoc-compatible manpage sources:

- `zelta.md` and `zelta-*.md` build section 8 command manpages.
- `*.7.md` files build section 7 overview manpages.

Edit these Markdown files, then run `make` from this directory.

## Generated Manpages

Generated manpages are written under section directories:

- `man7/` for section 7 pages.
- `man8/` for section 8 pages.

Do not edit generated files directly. They are rebuilt from the Markdown sources.

`ZELTA_DOC` should point at this directory, not at `man7/` or `man8/` directly. For example:

```sh
export ZELTA_DOC="$HOME/.local/share/zelta/doc"
man -M "$ZELTA_DOC" 8 zelta-backup
```

## Wiki Articles

Use `wiki/` for teaching, workflow, and journey articles that do not belong in manpages. Website publishing is handled outside this repository.
