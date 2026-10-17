#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT_DIR"

if ! command -v rg >/dev/null 2>&1; then
  printf 'ERROR: rg is required by tests/template_checks.sh.\n' >&2
  exit 1
fi

fail=0

check_absent() {
  local pattern="$1"
  local file="$2"
  local message="$3"
  local status

  if rg --fixed-strings --quiet -- "$pattern" "$file"; then
    printf 'FAIL: %s\n' "$message" >&2
    fail=1
  else
    status=$?
    if [ "$status" -ne 1 ]; then
      printf 'FAIL: unable to inspect %s for: %s\n' "$file" "$message" >&2
      fail=1
    fi
  fi
}

check_present() {
  local pattern="$1"
  local file="$2"
  local message="$3"
  local status

  if rg --fixed-strings --quiet -- "$pattern" "$file"; then
    return
  else
    status=$?
  fi

  if [ "$status" -eq 1 ]; then
    printf 'FAIL: %s\n' "$message" >&2
  else
    printf 'FAIL: unable to inspect %s for: %s\n' "$file" "$message" >&2
  fi
  fail=1
}

check_present_multiline() {
  local pattern="$1"
  local file="$2"
  local message="$3"
  local status

  if rg --fixed-strings --multiline --quiet -- "$pattern" "$file"; then
    return
  else
    status=$?
  fi

  if [ "$status" -eq 1 ]; then
    printf 'FAIL: %s\n' "$message" >&2
  else
    printf 'FAIL: unable to inspect %s for: %s\n' "$file" "$message" >&2
  fi
  fail=1
}

check_before() {
  local first_pattern="$1"
  local second_pattern="$2"
  local file="$3"
  local message="$4"
  local first_match
  local second_match
  local first_line
  local second_line
  local status

  if first_match=$(rg --fixed-strings --line-number --max-count 1 -- "$first_pattern" "$file"); then
    :
  else
    status=$?
    if [ "$status" -eq 1 ]; then
      printf 'FAIL: %s (missing first command)\n' "$message" >&2
    else
      printf 'FAIL: unable to inspect %s for: %s (first command)\n' "$file" "$message" >&2
    fi
    fail=1
    return
  fi
  if second_match=$(rg --fixed-strings --line-number --max-count 1 -- "$second_pattern" "$file"); then
    :
  else
    status=$?
    if [ "$status" -eq 1 ]; then
      printf 'FAIL: %s (missing second command)\n' "$message" >&2
    else
      printf 'FAIL: unable to inspect %s for: %s (second command)\n' "$file" "$message" >&2
    fi
    fail=1
    return
  fi

  first_line=${first_match%%:*}
  second_line=${second_match%%:*}
  if [ "$first_line" -ge "$second_line" ]; then
    printf 'FAIL: %s\n' "$message" >&2
    fail=1
  fi
}

check_absent_regex() {
  local pattern="$1"
  local file="$2"
  local message="$3"
  local status

  if rg --quiet -- "$pattern" "$file"; then
    printf 'FAIL: %s\n' "$message" >&2
    fail=1
  else
    status=$?
    if [ "$status" -ne 1 ]; then
      printf 'FAIL: unable to inspect %s for: %s\n' "$file" "$message" >&2
      fail=1
    fi
  fi
}

check_file_absent() {
  local file="$1"
  local message="$2"

  if [ -e "$file" ]; then
    printf 'FAIL: %s\n' "$message" >&2
    fail=1
  fi
}

check_present '\NeedsTeXFormat{LaTeX2e}' presentation.sty 'presentation.sty should declare its required LaTeX format'
check_present 'giveninits=true,uniquename=mininit' presentation.sty 'Chicago initials should use an explicit compatible uniqueness policy'
check_absent '\MakeLowercase' presentation.sty 'presentation.sty must not mutate title or heading text case'
check_absent '\addbibresource{references.bib}' presentation.sty 'bibliography database belongs in presentation content, not style'
check_absent '\renewcommand{\includegraphics}' presentation.sty 'presentation.sty must not globally redefine \includegraphics'
check_absent 'file = {' references.bib 'sample bibliography must not contain local Zotero file paths'
check_absent 'corrolary' presentation.tex 'sample deck must spell corollary correctly'
check_present '\addbibresource{references.bib}' presentation.tex 'presentation.tex should declare its bibliography database'
check_present '\begin{singlespace}' presentation.tex 'sample deck should illustrate switching dense content to single spacing'
check_present '\providecommand{\presentationfontsize}{12pt}' presentation.tex 'presentation.tex should expose a default presentation font size'
check_present '\presentationfontsize,aspectratio=\presentationaspectratio' presentation.tex 'presentation.tex should use \presentationfontsize in document class options'
check_absent 'usepdftitle=false' presentation.tex 'full starter should use automatic Beamer PDF metadata'
check_absent 'usepdftitle=false' presentation-minimal.tex 'minimal starter should use automatic Beamer PDF metadata'
check_absent 'pdftitle=' presentation.tex 'full starter should not duplicate its visible title in PDF metadata'
check_absent 'pdftitle=' presentation-minimal.tex 'minimal starter should not duplicate its visible title in PDF metadata'
check_absent 'OUTPUT_DIR="$ROOT_DIR/output"' compile_all.sh 'compile_all.sh should not build separate normal output PDFs'
check_present 'TEST_OUTPUT_DIR="$ROOT_DIR/output/test"' compile_all.sh 'compile_all.sh should write every generated PDF under output/test/'
check_absent 'build_variant presentation_light 12pt 43 light' compile_all.sh 'compile_all.sh should not build a separate normal light 4:3 PDF'
check_absent 'build_variant presentation_dark 12pt 43 dark' compile_all.sh 'compile_all.sh should not build a separate normal dark 4:3 PDF'
check_absent 'build_variant presentation_wide 12pt 169 light' compile_all.sh 'compile_all.sh should not build a separate normal light 16:9 PDF'
check_absent 'build_variant presentation_wide_dark 12pt 169 dark' compile_all.sh 'compile_all.sh should not build a separate normal dark 16:9 PDF'
check_present '--input-directory "$BUILD_DIR"' compile_all.sh 'compile_all.sh fallback should run biber for bibliography resolution'
check_present 'presentation_10pt_43_light' compile_all.sh 'compile_all.sh should build 10pt 4:3 light test PDF'
check_present 'presentation_10pt_1610_light' compile_all.sh 'compile_all.sh should build 10pt 16:10 light test PDF'
check_present 'presentation_10pt_169_light' compile_all.sh 'compile_all.sh should build 10pt 16:9 light test PDF'
check_present 'presentation_11pt_43_light' compile_all.sh 'compile_all.sh should build 11pt 4:3 light test PDF'
check_present 'presentation_11pt_1610_light' compile_all.sh 'compile_all.sh should build 11pt 16:10 light test PDF'
check_present 'presentation_11pt_169_light' compile_all.sh 'compile_all.sh should build 11pt 16:9 light test PDF'
check_present 'presentation_12pt_43_light' compile_all.sh 'compile_all.sh should build 12pt 4:3 light test PDF'
check_present 'presentation_12pt_1610_light' compile_all.sh 'compile_all.sh should build 12pt 16:10 light test PDF'
check_present 'presentation_12pt_169_light' compile_all.sh 'compile_all.sh should build 12pt 16:9 light test PDF'
check_present 'presentation_12pt_43_dark' compile_all.sh 'compile_all.sh should build 12pt 4:3 dark test PDF'
check_present 'presentation_12pt_1610_dark' compile_all.sh 'compile_all.sh should build 12pt 16:10 dark test PDF'
check_present 'presentation_12pt_169_dark' compile_all.sh 'compile_all.sh should build 12pt 16:9 dark test PDF'
check_file_absent 'output/presentation_light.pdf' 'normal light PDF should not be left directly under output/'
check_file_absent 'output/presentation_dark.pdf' 'normal dark PDF should not be left directly under output/'
check_file_absent 'output/presentation_wide.pdf' 'normal wide PDF should not be left directly under output/'
check_file_absent 'output/presentation_wide_dark.pdf' 'normal wide dark PDF should not be left directly under output/'
check_file_absent 'presentation.pdf' 'default generated PDF should not be left at repository root'
check_file_absent 'presentation_light.pdf' 'normal light PDF should not be left at repository root'
check_file_absent 'presentation_dark.pdf' 'normal dark PDF should not be left at repository root'
check_file_absent 'presentation_wide.pdf' 'normal wide PDF should not be left at repository root'
check_file_absent 'presentation_wide_dark.pdf' 'normal wide dark PDF should not be left at repository root'
check_present 'latexmk -lualatex presentation.tex' README.md 'README quick start should build one user-facing deck with latexmk and LuaLaTeX'
check_present 'latexmk -lualatex presentation-minimal.tex' README.md 'README should document the released minimal starter command'
check_present 'Biber is required' README.md 'README should explicitly document the Biber dependency'
check_present 'https://github.com/pmichaillat/latex-presentation' README.md 'README should acknowledge the upstream presentation project'
check_present 'https://github.com/YuntianZhao/Beamer-Template/releases' README.md 'README should link to public releases'
check_absent_regex '^lualatex presentation\.tex$' README.md 'README should not recommend raw lualatex for the bibliography-using sample deck'
check_present 'output/test/' README.md 'README should document output/test as the generated PDF directory'
check_present 'presentation_10pt_43_light.pdf' README.md 'README should list the font-size/aspect-ratio build matrix'
check_present 'presentation_12pt_169_dark.pdf' README.md 'README should list the dark-mode build matrix entries'
check_present 'output/test/' AGENTS.md 'AGENTS.md should document output/test as the generated PDF directory'
check_present 'bash tests/template_checks.sh' AGENTS.md 'AGENTS.md should require textual regression checks'
check_present 'presentation_12pt_169_dark.pdf' AGENTS.md 'AGENTS.md should list the current build matrix'
check_present 'latexmk -lualatex' AGENTS.md 'AGENTS.md engine verification should use latexmk for LuaLaTeX'
check_present 'latexmk -pdf' AGENTS.md 'AGENTS.md engine verification should use latexmk for pdfLaTeX'
check_present 'latexmk -xelatex' AGENTS.md 'AGENTS.md engine verification should use latexmk for XeLaTeX'
check_present 'biblatex' AGENTS.md 'AGENTS.md should explain why single raw engine passes are insufficient'
check_present '.engine-check/' .gitignore 'engine compatibility build directories should be ignored by git'
check_present '\providecommand{\presentationaspectratio}{43}' presentation-minimal.tex 'minimal starter should default to 4:3'
check_present '\providecommand{\presentationmode}{light}' presentation-minimal.tex 'minimal starter should default to light mode'
check_present '\providecommand{\presentationfontsize}{12pt}' presentation-minimal.tex 'minimal starter should default to 12pt'
check_present '\expandafter\usepackage\expandafter[\presentationpackageoptions]{presentation}' presentation-minimal.tex 'minimal starter should load presentation.sty'
check_present '\frame{\titlepage}' presentation-minimal.tex 'minimal starter should include a title frame'
check_present '\lastslide' presentation-minimal.tex 'minimal starter should demonstrate the template closing slide'
check_absent '\addbibresource{references.bib}' presentation-minimal.tex 'minimal starter should compile before bibliography content is added'

for file in presentation.sty presentation-minimal.tex; do
  check_present 'Copyright 2026 Yuntian Zhao' "$file" "$file should identify the copyright holder"
  check_present 'LaTeX Project Public License' "$file" "$file should identify the LPPL"
  check_present "maintenance status 'author-maintained'" "$file" "$file should identify maintenance status"
  check_present 'Current Maintainer of this work is Yuntian Zhao' "$file" "$file should identify the current maintainer"
  check_present 'presentation.sty and presentation-minimal.tex' "$file" "$file should identify the complete LPPL work"
done
check_present '## License' README.md 'README should explain template licensing'
check_present 'presentation.sty' README.md 'README license section should name the runtime work'
check_present 'presentation-minimal.tex' README.md 'README license section should name the runtime work'

check_present 'presentation.sty' RELEASING.md 'release instructions should list presentation.sty'
check_present 'presentation-minimal.tex' RELEASING.md 'release instructions should list presentation-minimal.tex'
check_present 'LICENSE.txt' RELEASING.md 'release instructions should list LICENSE.txt'
check_present 'bash tests/template_checks.sh' RELEASING.md 'release instructions should require textual checks'
check_present 'bash tests/template_checks_checks.sh' RELEASING.md 'release instructions should require textual harness checks'
check_present 'bash tests/runtime_checks.sh all' RELEASING.md 'release instructions should require focused runtime checks'
check_present 'bash tests/compile_all_checks.sh' RELEASING.md 'release instructions should require transactional build checks'
check_present './compile_all.sh' RELEASING.md 'release instructions should require the variant matrix'
check_present 'latexmk -g -pdf' RELEASING.md 'release instructions should require forced pdfLaTeX verification'
check_present 'Missing character' RELEASING.md 'release instructions should keep missing characters release-blocking'
check_present 'gh release create' RELEASING.md 'release instructions should document GitHub release creation'
check_present 'git merge --ff-only "$REVIEWED_COMMIT"' RELEASING.md 'release instructions should integrate the reviewed commit into local main'
check_present 'refs/heads/main' RELEASING.md 'release instructions should verify the local main ref'
check_present 'git push origin HEAD:main' RELEASING.md 'release instructions should push the reviewed HEAD explicitly to remote main'
check_present 'git fetch origin main' RELEASING.md 'release instructions should refresh remote main before comparing refs'
check_present 'refs/remotes/origin/main' RELEASING.md 'release instructions should verify the fetched remote main ref'
check_present 'gh repo view YuntianZhao/Beamer-Template --json visibility,url' RELEASING.md 'release postconditions should verify public visibility'
check_present 'https://api.github.com/repos/YuntianZhao/Beamer-Template/releases/tags/$version' RELEASING.md 'release postconditions should use the unauthenticated release API'
check_present 'releases/download/$version/$file' RELEASING.md 'release postconditions should download each public asset'
check_present 'cmp "$release_dir/$file" "$download_dir/$file"' RELEASING.md 'release postconditions should compare downloaded and tag-derived bytes'
check_present_multiline '```bash
set -euo pipefail' RELEASING.md 'release procedure should enable fail-fast behavior at the start of its executable block'
check_present_multiline 'if ! worktree_status=$(git status --porcelain); then
  printf '\''ERROR: unable to inspect working tree status.\n'\'' >&2
  exit 1
fi
if [ -n "$worktree_status" ]; then
  printf '\''ERROR: working tree is dirty.\n'\'' >&2
  exit 1
fi' RELEASING.md 'release instructions should fail closed before testing the captured worktree status'
check_present 'git tag -a "$version" -m "$version"' RELEASING.md 'release procedure should create a parameterized annotated tag locally'
check_present 'git cat-file -e "$version^{tag}"' RELEASING.md 'release procedure should verify the local annotated tag object'
check_present 'git archive "$version" presentation.sty presentation-minimal.tex LICENSE.txt' RELEASING.md 'all release assets should be extracted from the tag'
check_present_multiline 'for file in presentation.sty presentation-minimal.tex LICENSE.txt; do
  git show "$version:$file" | cmp - "$release_dir/$file"
done' RELEASING.md 'all three tagged-file comparisons should remain in one contiguous loop'
check_present 'gh repo edit YuntianZhao/Beamer-Template --visibility public --accept-visibility-change-consequences' RELEASING.md 'release instructions should document the exact public visibility command'
check_absent 'git tag -a v1.0.0' RELEASING.md 'release instructions should not hard-code the initial tag command'
check_before 'git tag -a "$version" -m "$version"' 'git cat-file -e "$version^{tag}"' RELEASING.md 'release procedure should verify the annotated tag after creating it'
check_before 'git cat-file -e "$version^{tag}"' 'git archive "$version"' RELEASING.md 'release procedure should verify the annotated tag before extracting assets'
check_before 'git archive "$version"' 'for file in presentation.sty presentation-minimal.tex LICENSE.txt; do' RELEASING.md 'release procedure should extract assets before byte-comparing them'
check_before 'done # tag-derived byte gate' 'git push origin HEAD:main' RELEASING.md 'tag-derived byte gates should finish before pushing reviewed main'
check_before 'git push origin HEAD:main' 'git fetch origin main' RELEASING.md 'release procedure should fetch remote main after pushing reviewed main'
check_before 'remote_main_commit=$(git rev-parse refs/remotes/origin/main)' 'gh repo edit YuntianZhao/Beamer-Template --visibility public' RELEASING.md 'release procedure should verify remote main before changing visibility'
check_before 'done # tag-derived byte gate' 'gh repo edit YuntianZhao/Beamer-Template --visibility public' RELEASING.md 'the complete comparison loop should finish before changing visibility'
check_before 'done # tag-derived byte gate' 'git push origin "$version"' RELEASING.md 'the complete comparison loop should finish before pushing the tag'
check_before 'done # tag-derived byte gate' 'gh release create "$version"' RELEASING.md 'the complete comparison loop should finish before creating the release'
check_before 'git push origin "$version"' 'gh release create "$version"' RELEASING.md 'the verified tag should be pushed before creating the release'
check_present_multiline 'gh release create "$version" \
  "$release_dir/presentation.sty" \
  "$release_dir/presentation-minimal.tex" \
  "$release_dir/LICENSE.txt" \
  --generate-notes \
  --verify-tag' RELEASING.md 'GitHub release assets should all come from the tag-derived release directory'
check_present 'RELEASING.md' AGENTS.md 'agent instructions should point to the release checklist'

exit "$fail"
