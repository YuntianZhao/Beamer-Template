# Beamer Template for Academic Presentations

A minimalist LaTeX Beamer template designed for research presentations, lectures, and seminar slides in economics, finance, and the social sciences.

Find the source in the [public project repository](https://github.com/YuntianZhao/Beamer-Template) and download packaged files from [GitHub Releases](https://github.com/YuntianZhao/Beamer-Template/releases).

The template philosophy is intentionally opinionated:

- Separate style and content.
- Keep the visual style fixed.
- Give users a small number of durable preamble controls instead of many local styling choices.
- Prefer sparse, readable slides, with local escape hatches for dense derivations or robustness material.

## Quick Start

Clone the repository, edit `presentation.tex`, and build the full example with LuaLaTeX:

```sh
latexmk -lualatex presentation.tex
```

For a new presentation, start from the smaller released template:

```sh
latexmk -lualatex presentation-minimal.tex
```

## Prerequisites

Biber is required, including for the minimal starter, because `presentation.sty` loads the `biblatex-chicago` backend. Use `latexmk` so Biber and all required LaTeX reruns are invoked automatically.

A complete TeX Live installation is the simplest setup. Package-level installations need Beamer, `iftex`, Libertinus and XITS fonts, Cascadia Code, `unicode-math`, `mathalpha`, `setspace`, `microtype`, `etoolbox`, `biblatex-chicago`, `listings`, `algorithm`, `algorithmicx`, `adjustbox`, `booktabs`, `multirow`, and `xtab`.

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

Code listings and other monospaced text use Cascadia Code with ligatures disabled on all supported engines. Operators such as `!=`, `<=`, and `->` remain separate characters.

Inline code written with `\texttt{...}` is scaled to 90% of the surrounding text size. Code listings use `\small`, one standard size below normal text, and URL fonts are unchanged.

Use `\begin{singlespace} ... \end{singlespace}` locally for dense slides. The default spacing remains generous to encourage sparse slides.

## Bibliography

The style file loads `biblatex-chicago`; the document owns the bibliography database:

```tex
\addbibresource{references.bib}
```

Keep local Zotero file paths out of shared `.bib` files.

## Generated Files

Generated PDFs and temporary build files are ignored by git. Do not edit generated PDFs manually; edit `presentation.tex`, `presentation.sty`, or the build script and regenerate outputs instead.

## Acknowledgements

Thank you to Pascal Michaillat for the excellent [Minimalist LaTeX Template for Academic Presentations](https://github.com/pmichaillat/latex-presentation), which inspired and provided the foundation for this template.

## License

The runtime template work consists of `presentation.sty` and
`presentation-minimal.tex`. It is distributed under the LaTeX Project Public
License, version 1.3c or later, with author-maintained status. The Current
Maintainer is Yuntian Zhao. See `LICENSE.txt` for the complete license.
