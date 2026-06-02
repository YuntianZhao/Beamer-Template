# AGENTS.md

## Verification

After changes to the Beamer template, especially font or package changes, compile `presentation.tex` with all supported engines:

```sh
lualatex presentation.tex
pdflatex presentation.tex
xelatex presentation.tex
```

Treat failures in any engine as compatibility regressions to fix before completion.
