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

Update `version` for every later release. Release files must never be taken
directly from a dirty working tree; the procedure below extracts them from the
verified tag instead.

Before making the repository public, audit its complete Git history for secrets
and other material that must not be published. Tagging, pushing, changing
visibility, and release creation require explicit user approval.

```bash
set -euo pipefail

version=v1.1.0
if ! worktree_status=$(git status --porcelain); then
  printf 'ERROR: unable to inspect working tree status.\n' >&2
  exit 1
fi
if [ -n "$worktree_status" ]; then
  printf 'ERROR: working tree is dirty.\n' >&2
  exit 1
fi
git rev-parse --verify HEAD
if git rev-parse --verify "$version" >/dev/null 2>&1; then
  printf 'ERROR: tag %s already exists.\n' "$version" >&2
  exit 1
fi

git tag -a "$version" -m "$version"
git cat-file -e "$version^{tag}"

release_dir=$(mktemp -d "${TMPDIR:-/tmp}/beamer-template-release.XXXXXX")
trap 'rm -rf "$release_dir"' EXIT
git archive "$version" presentation.sty presentation-minimal.tex LICENSE.txt | tar -x -C "$release_dir"
for file in presentation.sty presentation-minimal.tex LICENSE.txt; do
  git show "$version:$file" | cmp - "$release_dir/$file"
done

gh repo edit YuntianZhao/Beamer-Template --visibility public --accept-visibility-change-consequences
git push origin "$version"

gh release create "$version" \
  "$release_dir/presentation.sty" \
  "$release_dir/presentation-minimal.tex" \
  "$release_dir/LICENSE.txt" \
  --generate-notes \
  --verify-tag
```
