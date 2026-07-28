# Releasing

Tagged releases are the source of runtime assets consumed by
`YuntianZhao/Academic-Beamer-Skill`.

## Runtime Release Files

- `presentation.sty`
- `presentation-minimal.tex`
- `LICENSE.txt`

Do not rename or remove a runtime release file without coordinating a matching
skill synchronization change.

## Prepare Reviewed Main

The independent whole-branch review must identify the exact commit approved for
release. Set `REVIEWED_COMMIT` to that full SHA, then integrate it into local
`main` before verification. The fast-forward-only merge prevents an unreviewed
merge commit from becoming the release target.

```bash
export REVIEWED_COMMIT=FULL_SHA_FROM_APPROVED_REVIEW
git switch main
git merge --ff-only "$REVIEWED_COMMIT"
```

## Verification

Run from the repository root. Keep these Biber-dependent builds serial.

```bash
set -euo pipefail

bash tests/template_checks.sh
bash tests/template_checks_checks.sh
bash tests/runtime_checks.sh all
bash tests/compile_all_checks.sh

mkdir -p \
  .engine-check/lualatex \
  .engine-check/pdflatex \
  .engine-check/xelatex \
  .engine-check/minimal-lualatex \
  .engine-check/minimal-pdflatex \
  .engine-check/minimal-xelatex
latexmk -g -lualatex -interaction=nonstopmode -halt-on-error -outdir=.engine-check/lualatex presentation.tex
latexmk -g -pdf -interaction=nonstopmode -halt-on-error -outdir=.engine-check/pdflatex presentation.tex
latexmk -g -xelatex -interaction=nonstopmode -halt-on-error -outdir=.engine-check/xelatex presentation.tex
latexmk -g -lualatex -interaction=nonstopmode -halt-on-error -outdir=.engine-check/minimal-lualatex presentation-minimal.tex
latexmk -g -pdf -interaction=nonstopmode -halt-on-error -outdir=.engine-check/minimal-pdflatex presentation-minimal.tex
latexmk -g -xelatex -interaction=nonstopmode -halt-on-error -outdir=.engine-check/minimal-xelatex presentation-minimal.tex

warning_pattern='Overfull \\[hv]box|LaTeX Font Warning|Package biblatex Warning: Conflicting options|There were undefined references|Please rerun LaTeX|Please \(re\)run Biber|Missing character'
for final_log in \
  .engine-check/lualatex/presentation.log \
  .engine-check/pdflatex/presentation.log \
  .engine-check/xelatex/presentation.log \
  .engine-check/minimal-lualatex/presentation-minimal.log \
  .engine-check/minimal-pdflatex/presentation-minimal.log \
  .engine-check/minimal-xelatex/presentation-minimal.log; do
  if [ ! -f "$final_log" ]; then
    printf 'ERROR: final engine log was not produced: %s\n' "$final_log" >&2
    exit 1
  fi
  if rg --quiet -- "$warning_pattern" "$final_log"; then
    printf 'ERROR: final engine log contains a release-blocking warning: %s\n' "$final_log" >&2
    rg -- "$warning_pattern" "$final_log" >&2
    exit 1
  else
    scan_status=$?
    if [ "$scan_status" -ne 1 ]; then
      printf 'ERROR: unable to inspect final engine log: %s\n' "$final_log" >&2
      exit 1
    fi
  fi
done

./compile_all.sh
```

Review all command output, confirm exactly the 12 documented PDFs under
`output/test/`, and visually inspect the three minimal-starter PDFs. Treat any
focused-check, engine, final-log, or variant failure as a release blocker.

## Publish

Update `version` for every later release. Release files must never be taken
directly from a dirty working tree; the procedure below extracts them from the
verified tag instead.

Before making the repository public, audit its complete Git history for secrets
and other material that must not be published. Tagging, pushing, changing
visibility, and release creation require explicit user approval. Run the entire
block in the same shell used to export `REVIEWED_COMMIT` above.

```bash
set -euo pipefail

: "${REVIEWED_COMMIT:?Set REVIEWED_COMMIT to the full commit SHA approved by the final review}"
version=v1.1.0

for command_name in gh curl tar cmp rg; do
  command -v "$command_name" >/dev/null
done

current_branch=$(git branch --show-current)
if [ "$current_branch" != main ]; then
  printf 'ERROR: release must run from local main, not %s.\n' "$current_branch" >&2
  exit 1
fi
if ! worktree_status=$(git status --porcelain); then
  printf 'ERROR: unable to inspect working tree status.\n' >&2
  exit 1
fi
if [ -n "$worktree_status" ]; then
  printf 'ERROR: working tree is dirty.\n' >&2
  exit 1
fi

reviewed_commit=$(git rev-parse --verify "$REVIEWED_COMMIT^{commit}")
head_commit=$(git rev-parse HEAD)
main_commit=$(git rev-parse refs/heads/main)
if [ "$head_commit" != "$reviewed_commit" ] || [ "$main_commit" != "$reviewed_commit" ]; then
  printf 'ERROR: HEAD and local main must both equal reviewed commit %s.\n' "$reviewed_commit" >&2
  exit 1
fi
if git rev-parse --verify "$version" >/dev/null 2>&1; then
  printf 'ERROR: tag %s already exists.\n' "$version" >&2
  exit 1
fi

git tag -a "$version" -m "$version"
git cat-file -e "$version^{tag}"
tag_commit=$(git rev-list -n 1 "$version")
if [ "$tag_commit" != "$reviewed_commit" ]; then
  printf 'ERROR: local tag target does not equal reviewed commit %s.\n' "$reviewed_commit" >&2
  exit 1
fi

release_dir=$(mktemp -d "${TMPDIR:-/tmp}/beamer-template-release.XXXXXX")
trap 'rm -rf "$release_dir"' EXIT
git archive "$version" presentation.sty presentation-minimal.tex LICENSE.txt | tar -x -C "$release_dir"
for file in presentation.sty presentation-minimal.tex LICENSE.txt; do
  git show "$version:$file" | cmp - "$release_dir/$file"
done # tag-derived byte gate

git push origin HEAD:main
git fetch origin main
head_commit=$(git rev-parse HEAD)
main_commit=$(git rev-parse refs/heads/main)
remote_main_commit=$(git rev-parse refs/remotes/origin/main)
tag_commit=$(git rev-list -n 1 "$version")
if [ "$head_commit" != "$reviewed_commit" ] || \
   [ "$main_commit" != "$reviewed_commit" ] || \
   [ "$remote_main_commit" != "$reviewed_commit" ] || \
   [ "$tag_commit" != "$reviewed_commit" ]; then
  printf 'ERROR: HEAD, local main, remote main, and tag target must equal reviewed commit %s.\n' "$reviewed_commit" >&2
  exit 1
fi

gh repo edit YuntianZhao/Beamer-Template --visibility public --accept-visibility-change-consequences
git push origin "$version"
remote_tag_record=$(git ls-remote --exit-code origin "refs/tags/$version^{}")
remote_tag_commit=${remote_tag_record%%[[:space:]]*}
if [ "$remote_tag_commit" != "$reviewed_commit" ]; then
  printf 'ERROR: remote tag target does not equal reviewed commit %s.\n' "$reviewed_commit" >&2
  exit 1
fi

gh release create "$version" \
  "$release_dir/presentation.sty" \
  "$release_dir/presentation-minimal.tex" \
  "$release_dir/LICENSE.txt" \
  --generate-notes \
  --verify-tag

repo_state=$(gh repo view YuntianZhao/Beamer-Template --json visibility,url --jq '.visibility + " " + .url')
if [ "$repo_state" != 'PUBLIC https://github.com/YuntianZhao/Beamer-Template' ]; then
  printf 'ERROR: repository publication postcondition failed: %s\n' "$repo_state" >&2
  exit 1
fi

public_api_url="https://api.github.com/repos/YuntianZhao/Beamer-Template/releases/tags/$version"
curl --fail --silent --show-error "$public_api_url" > "$release_dir/public-release.json"
if ! rg --quiet -- "\"tag_name\"[[:space:]]*:[[:space:]]*\"$version\"" "$release_dir/public-release.json"; then
  printf 'ERROR: unauthenticated release API did not return tag %s.\n' "$version" >&2
  exit 1
fi

download_dir=$(mktemp -d "$release_dir/download.XXXXXX")
for file in presentation.sty presentation-minimal.tex LICENSE.txt; do
  if ! rg --quiet -- "\"name\"[[:space:]]*:[[:space:]]*\"$file\"" "$release_dir/public-release.json"; then
    printf 'ERROR: unauthenticated release API did not list asset %s.\n' "$file" >&2
    exit 1
  fi
  curl --fail --location --silent --show-error \
    "https://github.com/YuntianZhao/Beamer-Template/releases/download/$version/$file" \
    --output "$download_dir/$file"
  cmp "$release_dir/$file" "$download_dir/$file"
done

printf 'Published and verified %s at reviewed main commit %s.\n' "$version" "$reviewed_commit"
```

## Release Record

Record the reviewed/main/tag commit SHA, repository and release URLs, public
visibility, unauthenticated API result, all three downloaded byte comparisons,
focused checks, six engine builds and logs, and the 12-variant result. Also
record that accessibility and handout behavior remain excluded and that the
owner-selected README-only upstream MIT notice concern remains unresolved.
