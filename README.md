# Beamer Template for Academic Presentations

A minimalist LaTeX Beamer template designed for research presentations, lectures, and seminar slides in economics, finance, and the social sciences.

The template philosophy is intentionally opinionated:

- Separate style and content.
- Keep the visual style fixed.
- Give users a small number of durable preamble controls instead of many local styling choices.
- Prefer sparse, readable slides, with local escape hatches for dense derivations or robustness material.

## Quick Start

Edit `presentation.tex` and build one presentation with `latexmk` using LuaLaTeX:

```sh
latexmk -lualatex presentation.tex
```

This handles the required LaTeX reruns and bibliography processing for the sample `references.bib` file.

## Preamble Controls

The supported presentation options are defined at the top of `presentation.tex`:

```tex
\providecommand{\presentationaspectratio}{43}
\providecommand{\presentationmode}{light}
\providecommand{\presentationfontsize}{12pt}
```

Supported values:

- `\presentationfontsize`: `10pt`, `11pt`, `12pt`
- `\presentationaspectratio`: `43`, `1610`, `169`
- `\presentationmode`: `light`, `dark`

LuaLaTeX is the primary engine. The template also aims to compile with pdfLaTeX and XeLaTeX for portability.

## Build Matrix

Maintainers can run the full compile test matrix with:

```sh
./compile_all.sh
```

This generates:

- `output/test/presentation_10pt_43_light.pdf`
- `output/test/presentation_10pt_1610_light.pdf`
- `output/test/presentation_10pt_169_light.pdf`
- `output/test/presentation_11pt_43_light.pdf`
- `output/test/presentation_11pt_1610_light.pdf`
- `output/test/presentation_11pt_169_light.pdf`
- `output/test/presentation_12pt_43_light.pdf`
- `output/test/presentation_12pt_1610_light.pdf`
- `output/test/presentation_12pt_169_light.pdf`
- `output/test/presentation_12pt_43_dark.pdf`
- `output/test/presentation_12pt_1610_dark.pdf`
- `output/test/presentation_12pt_169_dark.pdf`

The matrix tests all mainstream font sizes and aspect ratios in light mode, plus dark mode at the default `12pt` size.

## Content Patterns

The sample deck demonstrates common research-seminar slide types:

- Lists and nested lists
- References with `biblatex-chicago`
- Code and algorithms
- Two- and three-column layouts
- Equations and math alphabets
- Figures with captions and notes
- Tables and long tables
- Theorems, lemmas, propositions, assumptions, and remarks
- Backup slides with navigation buttons

Use `\begin{singlespace} ... \end{singlespace}` locally for dense slides. The default spacing remains generous to encourage sparse slides.

## Bibliography

The style file loads `biblatex-chicago`; the document owns the bibliography database:

```tex
\addbibresource{references.bib}
```

Keep local Zotero file paths out of shared `.bib` files.

## Generated Files

Generated PDFs and temporary build files are ignored by git. Do not edit generated PDFs manually; edit `presentation.tex`, `presentation.sty`, or the build script and regenerate outputs instead.
