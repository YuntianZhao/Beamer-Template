# AGENTS.md

## Build All Presentation Variants

Run the one-click build script from the repository root:

```sh
./compile_all.sh
```

This regenerates all supported presentation outputs:

- `presentation_light.pdf`: 4:3, light mode
- `presentation_dark.pdf`: 4:3, dark mode
- `presentation_wide.pdf`: 16:9, light mode
- `presentation_wide_dark.pdf`: 16:9, dark mode

The script uses `latexmk` when available and falls back to `lualatex`.

## Verification

After changes to the Beamer template, especially font or package changes, compile `presentation.tex` with all supported engines:

```sh
lualatex presentation.tex
pdflatex presentation.tex
xelatex presentation.tex
```

Also run the all-variant build script when changes affect presentation options, colors, aspect ratio, or generated PDFs:

```sh
./compile_all.sh
```

Treat failures in any engine or variant as compatibility regressions to fix before completion.
