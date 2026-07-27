# AGENTS.md

## Build Presentation Test Matrix

Run the one-click build script from the repository root:

```sh
./compile_all.sh
```

This regenerates the supported compile-test PDFs under `output/test/`:

- `presentation_10pt_43_light.pdf`
- `presentation_10pt_1610_light.pdf`
- `presentation_10pt_169_light.pdf`
- `presentation_11pt_43_light.pdf`
- `presentation_11pt_1610_light.pdf`
- `presentation_11pt_169_light.pdf`
- `presentation_12pt_43_light.pdf`
- `presentation_12pt_1610_light.pdf`
- `presentation_12pt_169_light.pdf`
- `presentation_12pt_43_dark.pdf`
- `presentation_12pt_1610_dark.pdf`
- `presentation_12pt_169_dark.pdf`

The script uses `latexmk` when available and falls back to `lualatex` plus `biber`.
It writes generated PDFs only under `output/test/`; do not add separate root-level generated PDFs.

## Preamble Options

`presentation.tex` exposes the supported document-level options:

```tex
\providecommand{\presentationaspectratio}{43}
\providecommand{\presentationmode}{light}
\providecommand{\presentationfontsize}{12pt}
```

Supported values are `43`, `1610`, and `169` for aspect ratio; `light` and `dark` for mode; and `10pt`, `11pt`, and `12pt` for font size.

## Verification

After changes to the Beamer template, especially font or package changes, compile `presentation.tex` with all supported engines using `latexmk` so bibliography processing and required reruns are included:

```sh
mkdir -p .engine-check/lualatex .engine-check/pdflatex .engine-check/xelatex
latexmk -lualatex -interaction=nonstopmode -halt-on-error -outdir=.engine-check/lualatex presentation.tex
latexmk -pdf -interaction=nonstopmode -halt-on-error -outdir=.engine-check/pdflatex presentation.tex
latexmk -xelatex -interaction=nonstopmode -halt-on-error -outdir=.engine-check/xelatex presentation.tex
```

Do not replace these with single `lualatex`, `pdflatex`, or `xelatex` calls; single engine passes do not resolve `biblatex`/`biber` output or cross-reference reruns.

Run the focused runtime and transactional build checks:

```sh
bash tests/runtime_checks.sh
bash tests/compile_all_checks.sh
```

The focused runtime checks require Poppler tools (`pdfinfo`, `pdftotext`, `pdftohtml`, and `pdffonts`) in addition to the TeX, Biber, and ripgrep tools.

Run the textual regression checks after documentation, build-script, or template changes:

```sh
bash tests/template_checks.sh
```

Also run the all-variant build script when changes affect presentation options, colors, aspect ratio, font size, or generated PDFs:

```sh
./compile_all.sh
```

Treat failures in any engine or variant as compatibility regressions to fix before completion.

Generated PDFs and temporary build directories are ignored by git. Never edit generated PDFs manually; update the source and regenerate.

## Releases

Follow `RELEASING.md` for the required runtime files, compatibility matrix, and
GitHub release procedure. Never tag, push, or create a release without explicit
user approval.
