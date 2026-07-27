#!/usr/bin/env bash
set -euo pipefail

fail=0

check_absent() {
  local pattern="$1"
  local file="$2"
  local message="$3"

  if rg --fixed-strings --quiet -- "$pattern" "$file"; then
    printf 'FAIL: %s\n' "$message" >&2
    fail=1
  fi
}

check_present() {
  local pattern="$1"
  local file="$2"
  local message="$3"

  if ! rg --fixed-strings --quiet -- "$pattern" "$file"; then
    printf 'FAIL: %s\n' "$message" >&2
    fail=1
  fi
}

check_absent_regex() {
  local pattern="$1"
  local file="$2"
  local message="$3"

  if rg --quiet -- "$pattern" "$file"; then
    printf 'FAIL: %s\n' "$message" >&2
    fail=1
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

check_absent '\MakeLowercase' presentation.sty 'presentation.sty must not mutate title or heading text case'
check_absent '\addbibresource{references.bib}' presentation.sty 'bibliography database belongs in presentation content, not style'
check_absent '\renewcommand{\includegraphics}' presentation.sty 'presentation.sty must not globally redefine \includegraphics'
check_absent 'file = {' references.bib 'sample bibliography must not contain local Zotero file paths'
check_absent 'corrolary' presentation.tex 'sample deck must spell corollary correctly'
check_present '\addbibresource{references.bib}' presentation.tex 'presentation.tex should declare its bibliography database'
check_present '\begin{singlespace}' presentation.tex 'sample deck should illustrate switching dense content to single spacing'
check_present '\providecommand{\presentationfontsize}{12pt}' presentation.tex 'presentation.tex should expose a default presentation font size'
check_present '\presentationfontsize,aspectratio=\presentationaspectratio' presentation.tex 'presentation.tex should use \presentationfontsize in document class options'
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

exit "$fail"
