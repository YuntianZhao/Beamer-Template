# Releasing

Tagged releases are the source of runtime assets consumed by
`YuntianZhao/Academic-Beamer-Skill`.

## Runtime Release Files

- `presentation.sty`
- `presentation-minimal.tex`
- `LICENSE.txt`

Do not rename or remove a runtime release file without coordinating a matching
skill synchronization change.

## Verification

Run from the repository root:

```sh
bash tests/template_checks.sh
mkdir -p .engine-check/lualatex .engine-check/pdflatex .engine-check/xelatex .engine-check/minimal-lualatex .engine-check/minimal-pdflatex .engine-check/minimal-xelatex
latexmk -lualatex -interaction=nonstopmode -halt-on-error -outdir=.engine-check/lualatex presentation.tex
latexmk -pdf -interaction=nonstopmode -halt-on-error -outdir=.engine-check/pdflatex presentation.tex
latexmk -xelatex -interaction=nonstopmode -halt-on-error -outdir=.engine-check/xelatex presentation.tex
latexmk -lualatex -interaction=nonstopmode -halt-on-error -outdir=.engine-check/minimal-lualatex presentation-minimal.tex
latexmk -pdf -interaction=nonstopmode -halt-on-error -outdir=.engine-check/minimal-pdflatex presentation-minimal.tex
latexmk -xelatex -interaction=nonstopmode -halt-on-error -outdir=.engine-check/minimal-xelatex presentation-minimal.tex
./compile_all.sh
```

Review all command output and visually inspect the three minimal-starter PDFs.
Treat an engine or variant failure as a release blocker.

## Publish

After verification, create the initial annotated semantic-version tag and push
it. Then create the GitHub release and attach the runtime files:

```sh
git tag -a v1.0.0 -m "v1.0.0"
git push origin v1.0.0
gh release create v1.0.0 presentation.sty presentation-minimal.tex LICENSE.txt --generate-notes --verify-tag
```

Tagging, pushing, and release creation require explicit user approval.
