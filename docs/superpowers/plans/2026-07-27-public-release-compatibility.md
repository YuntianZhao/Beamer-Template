# Public Release And Compatibility Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Publish Beamer Template `v1.1.0` as a public, warning-clean project with the confirmed runtime, metadata, build, release, and documentation failures corrected.

**Architecture:** Preserve the existing single-package structure and add focused shell-driven TeX regression fixtures around it. Make runtime changes locally in `presentation.sty`, keep starter metadata in the document files, make variant publication transactional in `compile_all.sh`, and gate public release on the existing three-engine and variant matrix plus focused regressions.

**Tech Stack:** LaTeX Beamer, LuaLaTeX, pdfLaTeX, XeLaTeX, `latexmk`, Biber, Bash, ripgrep, Poppler command-line tools, Git, GitHub CLI.

## Global Constraints

- Release version is exactly `v1.1.0`; package date is exactly `2026/07/27`.
- Preserve the current minimalist layout and GitHub-inspired light/dark palettes.
- Keep Biber and `biblatex-chicago` as required runtime dependencies.
- Do not add tagged-PDF/accessibility behavior.
- Do not add or change Beamer handout-mode behavior.
- Keep automatic PDF metadata derived from `\title`, `\subtitle`, and `\author`; do not restore duplicated `pdftitle` strings.
- Keep the current 12-entry variant matrix and generated PDFs under `output/test/` only.
- Add a README acknowledgement and link to `pmichaillat/latex-presentation`; per the owner's explicit choice, do not add the upstream MIT notice, while retaining the documented compliance risk in the design spec.
- Do not change repository visibility, push tags, or create the release until every local gate passes and the history audit is clean.
- The user has explicitly approved commits, pushing `main`, public visibility, annotated tag `v1.1.0`, and GitHub release `v1.1.0`.
- Before every commit, inspect `git status --short`, the complete intended diff, and `git log --oneline -5`; after staging, inspect `git diff --cached` and run `git diff --cached --check`.

---

## File Map

**Create:**

- `tests/fixtures/dark-semantic-colors.tex`: renders standard Beamer semantic colors in dark mode.
- `tests/fixtures/pdflatex-compatibility.tex`: exercises multi-token calligraphic math and bold italic under pdfLaTeX.
- `tests/fixtures/beamer-fields.tex`: exercises optional title fields, frame subtitle, and automatic PDF metadata.
- `tests/fixtures/url-fragment.tex`: compiles a raw URL fragment through `\paperurl`.
- `tests/fixtures/presentation-12pt-169.tex`: compiles the full sample with the shortest supported 12pt canvas.
- `tests/runtime_checks.sh`: compiles focused fixtures, inspects logs, text, metadata, fonts, and PDF colors.
- `tests/compile_all_checks.sh`: tests variant-build failure atomicity and locking with a fake `latexmk`.

**Modify:**

- `presentation.sty`: package identity, engine compatibility, semantic colors, optional fields, URL storage, and bibliography options.
- `presentation.tex`: automatic metadata, semantic-color sample coverage, typo correction, and local overflow fixes.
- `presentation-minimal.tex`: automatic metadata.
- `compile_all.sh`: locking, unique temporary directories, warning checks, and transactional publication.
- `tests/template_checks.sh`: robust search status handling and source/documentation invariants.
- `.gitignore`: unique build and lock paths.
- `README.md`: prerequisites, starter commands, public links, and upstream acknowledgement.
- `AGENTS.md`: focused regression commands and maintainer dependencies.
- `RELEASING.md`: clean-tree, tag-derived asset, public-visibility, and `v1.1.0` release procedure.

---

### Task 1: Package Identity And Bibliography Configuration

**Files:**
- Modify: `tests/template_checks.sh:49-57`
- Modify: `presentation.sty:1-13,285-288`

**Interfaces:**
- Consumes: Existing `presentation` package name and `biblatex-chicago` configuration.
- Produces: Package identity `presentation` version `1.1.0`; explicit bibliography uniqueness policy `uniquename=mininit`.

- [ ] **Step 1: Add failing textual checks for package identity and bibliography policy**

Add these checks near the existing `presentation.sty` assertions in `tests/template_checks.sh`:

```bash
check_present '\NeedsTeXFormat{LaTeX2e}' presentation.sty 'presentation.sty should declare its required LaTeX format'
check_present '\ProvidesPackage{presentation}[2026/07/27 v1.1.0' presentation.sty 'presentation.sty should identify release v1.1.0'
check_present 'giveninits=true,uniquename=mininit' presentation.sty 'Chicago initials should use an explicit compatible uniqueness policy'
```

- [ ] **Step 2: Run the textual checks and verify the new assertions fail**

Run:

```sh
bash tests/template_checks.sh
```

Expected: nonzero exit with failures for missing `\NeedsTeXFormat`, missing `\ProvidesPackage`, and missing explicit `uniquename=mininit`.

- [ ] **Step 3: Declare package version and reconcile the Chicago options**

Insert after the LPPL header in `presentation.sty`:

```tex
\NeedsTeXFormat{LaTeX2e}
\ProvidesPackage{presentation}[2026/07/27 v1.1.0 Minimalist academic Beamer template]
```

Change the bibliography options to:

```tex
\usepackage[backend=biber,authordate,sorting=nyt,%
  giveninits=true,uniquename=mininit,%
  isbn=false,url=false,doi=false,eprint=false]{biblatex-chicago}
```

- [ ] **Step 4: Verify textual checks and the final bibliography log**

Run:

```sh
bash tests/template_checks.sh
mkdir -p .engine-check/package-config
latexmk -g -lualatex -interaction=nonstopmode -halt-on-error -outdir=.engine-check/package-config presentation-minimal.tex
```

Then run:

```sh
rg --fixed-strings 'Package: presentation 2026/07/27 v1.1.0' .engine-check/package-config/presentation-minimal.log
```

Expected: all commands exit zero.

Run:

```sh
rg --fixed-strings 'Package biblatex Warning: Conflicting options.' .engine-check/package-config/presentation-minimal.log
```

Expected: exit 1 with no match.

- [ ] **Step 5: Commit the package configuration**

Inspect and commit only the intended files:

```sh
git status --short
git diff -- presentation.sty tests/template_checks.sh
git diff --check
git log --oneline -5
git add presentation.sty tests/template_checks.sh
git diff --cached
git diff --cached --check
git commit -m "fix: identify template package and bibliography policy"
```

---

### Task 2: Dark-Mode Semantic Colors

**Files:**
- Create: `tests/fixtures/dark-semantic-colors.tex`
- Create: `tests/runtime_checks.sh`
- Modify: `presentation.sty:180-208`
- Modify: `presentation.tex:102-117`

**Interfaces:**
- Consumes: `GitHubFg`, `GitHubBlue`, `GitHubRed`, `GitHubGreen`, and `GitHubCanvasSubtle` from `presentation.sty`.
- Produces: `bash tests/runtime_checks.sh dark`; reusable `compile_fixture`, `assert_present`, and `assert_absent` shell functions for later tasks.

- [ ] **Step 1: Create a focused dark-mode fixture**

Create `tests/fixtures/dark-semantic-colors.tex`:

```tex
\documentclass[12pt,aspectratio=169]{beamer}
\usepackage[dark]{presentation}

\begin{document}

\begin{frame}
  \frametitle{Dark semantic colors}
  Normal probe.
  \alert{Alert probe.}
  \structure{Structure probe.}
  {\usebeamercolor[fg]{example text}Example probe.}
  \begin{alertblock}{Alert block probe}
    Alert block body probe.
  \end{alertblock}
  \begin{exampleblock}{Example block probe}
    Example block body probe.
  \end{exampleblock}
\end{frame}

\end{document}
```

- [ ] **Step 2: Create the initial runtime regression runner**

Create executable `tests/runtime_checks.sh` with this initial content:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
BUILD_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/beamer-runtime-checks.XXXXXX")
FILTER=${1:-all}

cleanup() {
  rm -rf "$BUILD_ROOT"
}
trap cleanup EXIT

cd "$ROOT_DIR"

for command_name in latexmk biber pdftohtml rg; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    printf 'ERROR: %s is required by tests/runtime_checks.sh.\n' "$command_name" >&2
    exit 1
  fi
done

assert_present() {
  local pattern="$1"
  local file="$2"
  local message="$3"

  if ! rg --fixed-strings --quiet -- "$pattern" "$file"; then
    printf 'FAIL: %s\n' "$message" >&2
    exit 1
  fi
}

assert_absent() {
  local pattern="$1"
  local file="$2"
  local message="$3"
  local status

  if rg --fixed-strings --quiet -- "$pattern" "$file"; then
    printf 'FAIL: %s\n' "$message" >&2
    exit 1
  else
    status=$?
    if [ "$status" -ne 1 ]; then
      printf 'FAIL: unable to inspect %s for: %s\n' "$file" "$message" >&2
      exit 1
    fi
  fi
}

compile_fixture() {
  local name="$1"
  local engine="$2"
  local engine_flag
  local output_dir="$BUILD_ROOT/$name"

  case "$engine" in
    lualatex) engine_flag=-lualatex ;;
    pdflatex) engine_flag=-pdf ;;
    xelatex) engine_flag=-xelatex ;;
    *)
      printf 'ERROR: unsupported fixture engine %s.\n' "$engine" >&2
      exit 1
      ;;
  esac

  mkdir -p "$output_dir"
  latexmk -g "$engine_flag" -interaction=nonstopmode -halt-on-error \
    -jobname="$name" -outdir="$output_dir" "tests/fixtures/$name.tex"
}

check_dark() {
  local name=dark-semantic-colors
  local output_dir="$BUILD_ROOT/$name"
  local xml="$output_dir/$name.xml"

  compile_fixture "$name" lualatex
  pdftohtml -xml -stdout "$output_dir/$name.pdf" > "$xml"
  assert_present 'color="#f85149"' "$xml" 'dark alerted text should use GitHubRed'
  assert_present 'color="#2f81f7"' "$xml" 'dark structure text should use GitHubBlue'
  assert_present 'color="#3fb950"' "$xml" 'dark example text should use GitHubGreen'
}

case "$FILTER" in
  all|dark) check_dark ;;
  *)
    printf 'ERROR: unknown runtime check %s.\n' "$FILTER" >&2
    exit 1
    ;;
esac

printf 'Runtime checks passed (%s).\n' "$FILTER"
```

Run:

```sh
chmod +x tests/runtime_checks.sh
```

- [ ] **Step 3: Run the dark check and verify it fails on inherited black colors**

Run:

```sh
bash tests/runtime_checks.sh dark
```

Expected: nonzero exit reporting that the expected red, blue, or green semantic color is absent.

- [ ] **Step 4: Explicitly set all standard semantic colors**

Add after the normal-text color in `presentation.sty`:

```tex
\setbeamercolor{structure}{fg=GitHubBlue}
\setbeamercolor{alerted text}{fg=GitHubRed}
\setbeamercolor{example text}{fg=GitHubGreen}
```

Extend the block colors with:

```tex
\setbeamercolor{block title alerted}{fg=GitHubRed,bg=GitHubCanvasSubtle}
\setbeamercolor{block body alerted}{fg=GitHubFg,bg=GitHubCanvasSubtle}
\setbeamercolor{block title example}{fg=GitHubGreen,bg=GitHubCanvasSubtle}
\setbeamercolor{block body example}{fg=GitHubFg,bg=GitHubCanvasSubtle}
```

In the sample alert frame, replace the first direct blue alert with standard semantic commands so normal builds exercise them:

```tex
\item Here is a standard alert: \alert{important text}
\item Here is structured text: \structure{important structure}
```

Keep the remaining direct-color overlay examples to demonstrate the GitHub palette.

- [ ] **Step 5: Run focused and textual checks**

Run:

```sh
bash tests/runtime_checks.sh dark
bash tests/template_checks.sh
```

Expected: both commands exit zero and the generated XML includes red, blue, and green rendered font colors.

- [ ] **Step 6: Commit dark-mode semantics**

```sh
git status --short
git diff -- presentation.sty presentation.tex tests/fixtures/dark-semantic-colors.tex tests/runtime_checks.sh
git diff --check
git log --oneline -5
git add presentation.sty presentation.tex tests/fixtures/dark-semantic-colors.tex tests/runtime_checks.sh
git diff --cached
git diff --cached --check
git commit -m "fix: restore beamer semantic colors in dark mode"
```

---

### Task 3: pdfLaTeX Math And Bold-Italic Compatibility

**Files:**
- Create: `tests/fixtures/pdflatex-compatibility.tex`
- Modify: `tests/runtime_checks.sh`
- Modify: `presentation.sty:57-72`

**Interfaces:**
- Consumes: `compile_fixture`, `assert_present`, and `assert_absent` from Task 2.
- Produces: `bash tests/runtime_checks.sh pdflatex`; robust package-provided `\mathcal` and `\mathbcal`; explicit italic-preserving fallback for unavailable Libertinus Sans bold italic.

- [ ] **Step 1: Add the pdfLaTeX compatibility fixture**

Create `tests/fixtures/pdflatex-compatibility.tex`:

```tex
\documentclass[12pt]{beamer}
\usepackage{presentation}

\begin{document}

\begin{frame}
  \frametitle{pdfLaTeX compatibility}
  Multi-token math: $\mathcal{AB}+\mathbcal{AB}$.

  \textbf{\textit{Bold italic probe.}}
\end{frame}

\end{document}
```

- [ ] **Step 2: Extend the runtime runner with the pdfLaTeX check**

Add `pdffonts` to the required command loop. Add:

```bash
check_pdflatex() {
  local name=pdflatex-compatibility
  local output_dir="$BUILD_ROOT/$name"
  local log="$output_dir/$name.log"
  local fonts="$output_dir/$name.fonts"

  compile_fixture "$name" pdflatex
  pdffonts "$output_dir/$name.pdf" > "$fonts"
  assert_absent 'Missing = inserted for \ifnum' "$log" 'multi-token calligraphic math should compile under pdfLaTeX'
  assert_absent 'Font shape `T1/LibertinusSans-TLF/b/it' "$log" 'pdfLaTeX should use an explicit italic-preserving fallback'
  assert_absent 'Some font shapes were not available' "$log" 'pdfLaTeX should not finish with font substitutions'
  assert_present 'LibertinusSans-Italic' "$fonts" 'bold-italic fallback should preserve italic emphasis'
}
```

Replace the filter dispatch with:

```bash
case "$FILTER" in
  all)
    check_dark
    check_pdflatex
    ;;
  dark) check_dark ;;
  pdflatex) check_pdflatex ;;
  *)
    printf 'ERROR: unknown runtime check %s.\n' "$FILTER" >&2
    exit 1
    ;;
esac
```

- [ ] **Step 3: Run the pdfLaTeX check and verify the math failure**

Run:

```sh
bash tests/runtime_checks.sh pdflatex
```

Expected: nonzero exit from pdfLaTeX with `Missing = inserted for \ifnum` at `\mathcal{AB}`.

- [ ] **Step 4: Remove fragile math overrides and add an explicit font fallback**

Delete these pdfLaTeX-only definitions from `presentation.sty`:

```tex
\let\origmathcal\mathcal
\renewcommand{\mathcal}[1]{\ifnum`#1>`Z \mathscr{#1}\else\origmathcal{#1}\fi}
\renewcommand{\mathbcal}[1]{\ifnum`#1>`Z \mathbfscr{#1}\else\mbox{\boldmath$\origmathcal{#1}$}\fi}
```

Keep the robust `\mathcal` from `mathalpha` and `\mathbcal` from `libertinust1math`. After selecting `LibertinusSans-TLF`, explicitly preserve italic emphasis when the font family's unavailable bold-italic combination is requested:

```tex
\DeclareFontShape{T1}{LibertinusSans-TLF}{b}{it}{%
  <-> ssub * LibertinusSans-TLF/m/it}{}
```

- [ ] **Step 5: Verify the focused pdfLaTeX behavior**

Run:

```sh
bash tests/runtime_checks.sh pdflatex
bash tests/runtime_checks.sh all
```

Expected: both commands exit zero; the PDF embeds `LibertinusSans-Italic`; the log contains no missing-number or unavailable-shape warning.

- [ ] **Step 6: Commit pdfLaTeX compatibility**

```sh
git status --short
git diff -- presentation.sty tests/runtime_checks.sh tests/fixtures/pdflatex-compatibility.tex
git diff --check
git log --oneline -5
git add presentation.sty tests/runtime_checks.sh tests/fixtures/pdflatex-compatibility.tex
git diff --cached
git diff --cached --check
git commit -m "fix: make pdflatex math and emphasis robust"
```

---

### Task 4: Standard Beamer Fields, Automatic Metadata, And URL Fragments

**Files:**
- Create: `tests/fixtures/beamer-fields.tex`
- Create: `tests/fixtures/url-fragment.tex`
- Modify: `tests/runtime_checks.sh`
- Modify: `tests/template_checks.sh`
- Modify: `presentation.sty:113-128,180-227`
- Modify: `presentation.tex:1-20`
- Modify: `presentation-minimal.tex:13-30`

**Interfaces:**
- Consumes: Beamer `\insertsubtitle`, `\insertinstitute`, `\inserttitlegraphic`, `\insertframesubtitle`, and automatic `usepdftitle=true` behavior.
- Produces: `bash tests/runtime_checks.sh fields`; `bash tests/runtime_checks.sh url`; public `\paperurl{...}` backed by `\presentationurltoks` and `\ifpresentationurlset`.

- [ ] **Step 1: Add the optional-field and metadata fixture**

Create `tests/fixtures/beamer-fields.tex`:

```tex
\documentclass[12pt,aspectratio=169]{beamer}
\usepackage{presentation}
\hypersetup{pdfpagemode=UseNone,hidelinks,pdfdisplaydoctitle=true}

\title{Metadata Title}
\subtitle{Metadata Subtitle}
\author{Metadata Author}
\institute{Institute Probe}
\date{Location -- Date}
\titlegraphic{\fbox{Title Graphic Probe}}

\begin{document}

\frame{\titlepage}

\begin{frame}
  \frametitle{Frame Title Probe}
  \framesubtitle{Frame Subtitle Probe}
  Frame body probe.
\end{frame}

\end{document}
```

- [ ] **Step 2: Add the raw URL-fragment fixture**

Create `tests/fixtures/url-fragment.tex`:

```tex
\documentclass[12pt]{beamer}
\usepackage{presentation}

\title{URL Fragment Probe}
\author{Runtime Author}
\date{Location -- Date}
\paperurl{https://example.test/paper#section}

\begin{document}
\frame{\titlepage}
\end{document}
```

- [ ] **Step 3: Extend runtime checks for fields, metadata, and URLs**

Add `pdfinfo` and `pdftotext` to the required command loop. Add a regex helper:

```bash
assert_regex() {
  local pattern="$1"
  local file="$2"
  local message="$3"

  if ! rg --quiet -- "$pattern" "$file"; then
    printf 'FAIL: %s\n' "$message" >&2
    exit 1
  fi
}
```

Add these checks:

```bash
check_fields() {
  local name=beamer-fields
  local output_dir="$BUILD_ROOT/$name"
  local text="$output_dir/$name.txt"
  local info="$output_dir/$name.info"

  compile_fixture "$name" lualatex
  pdftotext "$output_dir/$name.pdf" "$text"
  pdfinfo "$output_dir/$name.pdf" > "$info"
  assert_present 'Metadata Subtitle' "$text" 'title subtitle should render'
  assert_present 'Institute Probe' "$text" 'institute should render'
  assert_present 'Title Graphic Probe' "$text" 'title graphic should render'
  assert_present 'Frame Subtitle Probe' "$text" 'frame subtitle should render'
  assert_regex '^Title:[[:space:]]+Metadata Title - Metadata Subtitle$' "$info" 'PDF title should follow title and subtitle'
  assert_regex '^Author:[[:space:]]+Metadata Author$' "$info" 'PDF author should follow the Beamer author'
}

check_url() {
  compile_fixture url-fragment lualatex
}
```

Extend the filter so `all` runs `check_fields` and `check_url`, with individual `fields` and `url` branches.

- [ ] **Step 4: Add starter-source metadata assertions**

Add to `tests/template_checks.sh`:

```bash
check_absent 'usepdftitle=false' presentation.tex 'full starter should use automatic Beamer PDF metadata'
check_absent 'usepdftitle=false' presentation-minimal.tex 'minimal starter should use automatic Beamer PDF metadata'
check_absent 'pdftitle=' presentation.tex 'full starter should not duplicate its visible title in PDF metadata'
check_absent 'pdftitle=' presentation-minimal.tex 'minimal starter should not duplicate its visible title in PDF metadata'
```

- [ ] **Step 5: Run new checks and verify current behavior fails**

Run:

```sh
bash tests/runtime_checks.sh fields
bash tests/runtime_checks.sh url
bash tests/template_checks.sh
```

Expected: fields check fails because subtitle/institute/title graphic/frame subtitle are absent; URL check aborts with `Illegal parameter number`; textual checks fail on manual metadata controls.

- [ ] **Step 6: Add optional-field fonts, colors, and frame-title rendering**

Add font settings in `presentation.sty`:

```tex
\setbeamerfont{subtitle}{size=\large}
\setbeamerfont{institute}{size=\normalsize}
\setbeamerfont{framesubtitle}{size=\small}
```

Replace the frame-title template with:

```tex
\setbeamertemplate{frametitle}{%
  \vskip3mm%
  \insertframetitle\par%
  \ifx\insertframesubtitle\@empty\else%
    {\usebeamerfont{framesubtitle}\usebeamercolor[fg]{framesubtitle}\insertframesubtitle\par}%
  \fi}
```

Add colors with the existing title colors:

```tex
\setbeamercolor{subtitle}{fg=GitHubMuted}
\setbeamercolor{institute}{fg=GitHubMuted}
\setbeamercolor{framesubtitle}{fg=GitHubMuted}
\setbeamercolor{titlegraphic}{fg=GitHubFg}
```

- [ ] **Step 7: Replace URL storage and extend the title-page template**

Replace the URL definitions with token-register storage:

```tex
\newif\ifpresentationurlset
\newtoks\presentationurltoks
\newcommand*{\inserturl}{\the\presentationurltoks}
\newcommand*{\paperurl}[1]{%
  \global\presentationurltoks={#1}%
  \global\presentationurlsettrue}
```

Replace the title-page template with this conditional order:

```tex
\setbeamertemplate{title page}{%
  {\usebeamerfont{title}\usebeamercolor[fg]{title}\inserttitle\par}%
  \ifx\insertsubtitle\@empty\else%
    \vspace{2mm}%
    {\usebeamerfont{subtitle}\usebeamercolor[fg]{subtitle}\insertsubtitle\par}%
  \fi%
  {\color{GitHubFg}\rule{\textwidth}{1.5pt}\par}%
  \vspace{1.5cm}%
  {\usebeamerfont{author}\insertauthor\par}%
  \ifx\insertinstitute\@empty\else%
    \vspace{2mm}%
    {\usebeamerfont{institute}\usebeamercolor[fg]{institute}\insertinstitute\par}%
  \fi%
  \vspace{5mm}%
  {\usebeamerfont{date}\insertdate\par}%
  \ifpresentationurlset%
    \vspace{5mm}%
    {\color{GitHubMuted}\footnotesize Available at \url{\inserturl}\par}%
  \fi%
  \ifx\inserttitlegraphic\@empty\else%
    \vspace{5mm}%
    {\usebeamercolor[fg]{titlegraphic}\inserttitlegraphic\par}%
  \fi%
  \vfill}
```

- [ ] **Step 8: Restore automatic metadata in both starters**

In both `presentation.tex` and `presentation-minimal.tex`, remove `usepdftitle=false` from `\presentationclassoptions`. Keep:

```tex
\edef\presentationclassoptions{\presentationfontsize,aspectratio=\presentationaspectratio,xcolor={dvipsnames}}
```

Remove the manual `pdftitle` entry and its associated comment from each `\hypersetup` block. Preserve `pdfpagemode`, `hidelinks`, and `pdfdisplaydoctitle`.

- [ ] **Step 9: Verify fields, URL fragments, and starter metadata**

Run:

```sh
bash tests/runtime_checks.sh fields
bash tests/runtime_checks.sh url
bash tests/runtime_checks.sh all
bash tests/template_checks.sh
```

Expected: all commands exit zero. `pdfinfo` reports `Metadata Title - Metadata Subtitle` and `Metadata Author`; extracted text includes every optional field; raw `#section` compiles.

- [ ] **Step 10: Commit fields, metadata, and URL handling**

```sh
git status --short
git diff -- presentation.sty presentation.tex presentation-minimal.tex tests/template_checks.sh tests/runtime_checks.sh tests/fixtures/beamer-fields.tex tests/fixtures/url-fragment.tex
git diff --check
git log --oneline -5
git add presentation.sty presentation.tex presentation-minimal.tex tests/template_checks.sh tests/runtime_checks.sh tests/fixtures/beamer-fields.tex tests/fixtures/url-fragment.tex
git diff --cached
git diff --cached --check
git commit -m "fix: restore beamer fields and automatic metadata"
```

---

### Task 5: Warning-Clean Sample Content

**Files:**
- Create: `tests/fixtures/presentation-12pt-169.tex`
- Modify: `tests/runtime_checks.sh`
- Modify: `presentation.tex:163-225,254-263,315-323,357-380,427-441`

**Interfaces:**
- Consumes: Existing full sample and `compile_fixture` infrastructure.
- Produces: `bash tests/runtime_checks.sh sample`; default and 12pt 16:9 full-sample logs without overfull boxes, bibliography conflicts, font warnings, or unresolved final-pass references.

- [ ] **Step 1: Add the 12pt 16:9 sample wrapper**

Create `tests/fixtures/presentation-12pt-169.tex`:

```tex
\newcommand{\presentationfontsize}{12pt}
\newcommand{\presentationaspectratio}{169}
\newcommand{\presentationmode}{light}
\input{presentation.tex}
```

- [ ] **Step 2: Generalize source compilation and add clean-log assertions**

Replace `compile_fixture` in `tests/runtime_checks.sh` with:

```bash
compile_source() {
  local name="$1"
  local engine="$2"
  local source="$3"
  local engine_flag
  local output_dir="$BUILD_ROOT/$name"

  case "$engine" in
    lualatex) engine_flag=-lualatex ;;
    pdflatex) engine_flag=-pdf ;;
    xelatex) engine_flag=-xelatex ;;
    *)
      printf 'ERROR: unsupported fixture engine %s.\n' "$engine" >&2
      exit 1
      ;;
  esac

  mkdir -p "$output_dir"
  latexmk -g "$engine_flag" -interaction=nonstopmode -halt-on-error \
    -jobname="$name" -outdir="$output_dir" "$source"
}

compile_fixture() {
  local name="$1"
  local engine="$2"
  compile_source "$name" "$engine" "tests/fixtures/$name.tex"
}
```

Add:

```bash
assert_clean_log() {
  local log="$1"
  local message="$2"
  local pattern='Overfull \\[hv]box|LaTeX Font Warning|Package biblatex Warning: Conflicting options|There were undefined references|Please rerun LaTeX|Please \(re\)run Biber'
  local status

  if rg --quiet -- "$pattern" "$log"; then
    printf 'FAIL: %s\n' "$message" >&2
    rg -- "$pattern" "$log" >&2
    exit 1
  else
    status=$?
    if [ "$status" -ne 1 ]; then
      printf 'FAIL: unable to inspect %s for warnings.\n' "$log" >&2
      exit 1
    fi
  fi
}

check_sample() {
  compile_source presentation-default lualatex presentation.tex
  assert_clean_log "$BUILD_ROOT/presentation-default/presentation-default.log" 'default LuaLaTeX sample should be warning-clean'

  compile_source presentation-default-pdf pdflatex presentation.tex
  assert_clean_log "$BUILD_ROOT/presentation-default-pdf/presentation-default-pdf.log" 'default pdfLaTeX sample should be warning-clean'

  compile_source presentation-12pt-169 lualatex tests/fixtures/presentation-12pt-169.tex
  assert_clean_log "$BUILD_ROOT/presentation-12pt-169/presentation-12pt-169.log" '12pt 16:9 sample should be warning-clean'
}
```

Extend the filter with `sample) check_sample ;;` and run `check_sample` from `all`.

- [ ] **Step 3: Run the sample check and verify current overfull boxes fail it**

Run:

```sh
bash tests/runtime_checks.sh sample
```

Expected: nonzero exit showing overfull boxes from the default or 12pt 16:9 sample.

- [ ] **Step 4: Apply local spacing and sizing fixes only to affected frames**

Make these concrete sample changes in `presentation.tex`:

1. Add `\small` before the equation in the right column of the two-column frame so the pdfLaTeX equation fits.
2. Add `\small` before `\begin{columns}` in the three-column frame.
3. Correct the phi command label:

```tex
\item a variant for phi: \texttt{\textbackslash varphi} gives $\varphi \neq \phi$
```

4. Reduce the captioned figure maximum height from `.70\textheight` to `.62\textheight`.
5. In the table-with-note frame, add `\footnotesize` before `\begin{table}`, wrap the table in `\begin{singlespace}`/`\end{singlespace}`, and delete the unrelated `Something here.` line.
6. Wrap the corollary and its following list in `\begin{singlespace}`/`\end{singlespace}`.

- [ ] **Step 5: Verify focused sample logs and all runtime fixtures**

Run:

```sh
bash tests/runtime_checks.sh sample
bash tests/runtime_checks.sh all
bash tests/template_checks.sh
```

Expected: all commands exit zero with no matched warning class.

- [ ] **Step 6: Commit the warning-clean sample**

```sh
git status --short
git diff -- presentation.tex tests/runtime_checks.sh tests/fixtures/presentation-12pt-169.tex
git diff --check
git log --oneline -5
git add presentation.tex tests/runtime_checks.sh tests/fixtures/presentation-12pt-169.tex
git diff --cached
git diff --cached --check
git commit -m "fix: keep sample content inside supported frames"
```

---

### Task 6: Transactional Variant Builds And Robust Shell Checks

**Files:**
- Create: `tests/compile_all_checks.sh`
- Modify: `compile_all.sh`
- Modify: `tests/template_checks.sh:1-37`
- Modify: `.gitignore:18-22`
- Modify: `AGENTS.md:41-68`

**Interfaces:**
- Consumes: The 12 existing `build_variant` calls and `tests/runtime_checks.sh`.
- Produces: lock directory `.build-presentation-variants.lock`; unique build directories `.build-presentation-variants.*`; staged output directories under `output/`; `bash tests/compile_all_checks.sh`.

- [ ] **Step 1: Create a fake-latexmk transactional build test**

Create executable `tests/compile_all_checks.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/compile-all-checks.XXXXXX")
TEST_REPO="$TEST_ROOT/repo"
FAKE_BIN="$TEST_ROOT/bin"

if ! command -v rg >/dev/null 2>&1; then
  printf 'ERROR: rg is required by tests/compile_all_checks.sh.\n' >&2
  exit 1
fi

cleanup() {
  if [ -n "${FIRST_PID:-}" ]; then
    kill "$FIRST_PID" >/dev/null 2>&1 || true
  fi
  rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

mkdir -p "$TEST_REPO/output/test" "$FAKE_BIN"
cp "$ROOT_DIR/compile_all.sh" "$TEST_REPO/compile_all.sh"
chmod +x "$TEST_REPO/compile_all.sh"

cat > "$FAKE_BIN/latexmk" <<'FAKE_LATEXMK'
#!/usr/bin/env bash
set -euo pipefail

jobname=
outdir=
for argument in "$@"; do
  case "$argument" in
    -jobname=*) jobname=${argument#-jobname=} ;;
    -outdir=*) outdir=${argument#-outdir=} ;;
  esac
done

if [ -z "$jobname" ] || [ -z "$outdir" ]; then
  printf 'fake latexmk did not receive jobname and outdir\n' >&2
  exit 2
fi

count=0
if [ -f "$FAKE_COUNT_FILE" ]; then
  count=$(<"$FAKE_COUNT_FILE")
fi
count=$((count + 1))
printf '%s\n' "$count" > "$FAKE_COUNT_FILE"

if [ -n "${FAKE_FAIL_AT:-}" ] && [ "$count" -eq "$FAKE_FAIL_AT" ]; then
  exit 42
fi

mkdir -p "$outdir"
printf 'fake pdf for %s\n' "$jobname" > "$outdir/$jobname.pdf"
: > "$outdir/$jobname.log"
sleep "${FAKE_SLEEP:-0}"
FAKE_LATEXMK
chmod +x "$FAKE_BIN/latexmk"

export PATH="$FAKE_BIN:$PATH"
export FAKE_COUNT_FILE="$TEST_ROOT/count"

printf 'previous complete output\n' > "$TEST_REPO/output/test/sentinel.pdf"
export FAKE_FAIL_AT=2
if "$TEST_REPO/compile_all.sh"; then
  printf 'FAIL: an injected variant failure should fail compile_all.sh\n' >&2
  exit 1
fi
unset FAKE_FAIL_AT

if [ ! -f "$TEST_REPO/output/test/sentinel.pdf" ]; then
  printf 'FAIL: a failed run should preserve the previous output directory\n' >&2
  exit 1
fi
if compgen -G "$TEST_REPO/output/test/presentation_*.pdf" >/dev/null; then
  printf 'FAIL: a failed run should not publish a partial matrix\n' >&2
  exit 1
fi

rm -f "$FAKE_COUNT_FILE"
"$TEST_REPO/compile_all.sh"
set -- "$TEST_REPO"/output/test/presentation_*.pdf
if [ "$#" -ne 12 ]; then
  printf 'FAIL: successful run published %s PDFs instead of 12\n' "$#" >&2
  exit 1
fi
if [ -e "$TEST_REPO/output/test/sentinel.pdf" ]; then
  printf 'FAIL: successful publication should replace stale output\n' >&2
  exit 1
fi

rm -f "$FAKE_COUNT_FILE"
export FAKE_SLEEP=0.2
"$TEST_REPO/compile_all.sh" > "$TEST_ROOT/first.log" 2>&1 &
FIRST_PID=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do
  [ -d "$TEST_REPO/.build-presentation-variants.lock" ] && break
  sleep 0.05
done
if [ ! -d "$TEST_REPO/.build-presentation-variants.lock" ]; then
  printf 'FAIL: compile_all.sh should create a single-run lock\n' >&2
  exit 1
fi
if "$TEST_REPO/compile_all.sh" > "$TEST_ROOT/second.log" 2>&1; then
  printf 'FAIL: a concurrent compile_all.sh invocation should fail\n' >&2
  exit 1
fi
if ! rg --fixed-strings --quiet 'another compile_all.sh run is active' "$TEST_ROOT/second.log"; then
  printf 'FAIL: concurrent-run failure should be actionable\n' >&2
  exit 1
fi
wait "$FIRST_PID"
FIRST_PID=

printf 'compile_all.sh checks passed.\n'
```

Run:

```sh
chmod +x tests/compile_all_checks.sh
```

- [ ] **Step 2: Run the build-script test and verify current publication is partial**

Run:

```sh
bash tests/compile_all_checks.sh
```

Expected: nonzero exit because the existing script publishes at least one PDF before the injected failure or does not create the lock.

- [ ] **Step 3: Make build and staging paths unique and locked**

Replace the fixed path setup at the top of `compile_all.sh` with:

```bash
ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
LOCK_DIR="$ROOT_DIR/.build-presentation-variants.lock"
TEST_OUTPUT_DIR="$ROOT_DIR/output/test"
BUILD_DIR=
STAGING_DIR=

cd "$ROOT_DIR"

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  printf 'ERROR: another compile_all.sh run is active.\n' >&2
  exit 1
fi

cleanup() {
  if [ -n "$BUILD_DIR" ]; then
    rm -rf "$BUILD_DIR"
  fi
  if [ -n "$STAGING_DIR" ]; then
    rm -rf "$STAGING_DIR"
  fi
  rmdir "$LOCK_DIR" 2>/dev/null || true
}
trap cleanup EXIT

mkdir -p "$ROOT_DIR/output"
BUILD_DIR=$(mktemp -d "$ROOT_DIR/.build-presentation-variants.XXXXXX")
STAGING_DIR=$(mktemp -d "$ROOT_DIR/output/.test.XXXXXX")
```

Pass `"$STAGING_DIR"` to every `build_variant` call instead of `"$TEST_OUTPUT_DIR"`.

- [ ] **Step 4: Reject warning-bearing final logs and publish only a complete matrix**

Add after each engine invocation and before copying its PDF:

```bash
  local warning_pattern='Overfull \\[hv]box|LaTeX Font Warning|Package biblatex Warning: Conflicting options|There were undefined references|Please rerun LaTeX|Please \(re\)run Biber'
  local grep_status
  if [ ! -f "$BUILD_DIR/$jobname.log" ]; then
    printf 'ERROR: %s.log was not produced.\n' "$jobname" >&2
    exit 1
  fi
  if grep -Eq "$warning_pattern" "$BUILD_DIR/$jobname.log"; then
    printf 'ERROR: %s.log contains a release-blocking warning.\n' "$jobname" >&2
    grep -E "$warning_pattern" "$BUILD_DIR/$jobname.log" >&2
    exit 1
  else
    grep_status=$?
    if [ "$grep_status" -ne 1 ]; then
      printf 'ERROR: unable to inspect %s.log.\n' "$jobname" >&2
      exit 1
    fi
  fi
```

After all 12 `build_variant` calls, publish the staging directory:

```bash
rm -rf "$TEST_OUTPUT_DIR"
mv "$STAGING_DIR" "$TEST_OUTPUT_DIR"
STAGING_DIR=
```

Keep the final success message after the move.

In the no-`latexmk` branch, preflight both fallback commands before the first engine invocation:

```bash
if ! command -v lualatex >/dev/null 2>&1; then
  printf 'ERROR: latexmk not found and lualatex is required for fallback builds.\n' >&2
  exit 1
fi
if ! command -v biber >/dev/null 2>&1; then
  printf 'ERROR: latexmk not found and biber is required for bibliography builds.\n' >&2
  exit 1
fi
```

- [ ] **Step 5: Make textual search errors explicit and root-independent**

At the top of `tests/template_checks.sh`, resolve and enter the root and preflight ripgrep:

```bash
ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT_DIR"

if ! command -v rg >/dev/null 2>&1; then
  printf 'ERROR: rg is required by tests/template_checks.sh.\n' >&2
  exit 1
fi
```

Replace `check_absent` with status-aware handling:

```bash
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
```

Apply the same `status == 1` distinction to `check_absent_regex`. Update `check_present` so status 1 reports the existing missing-pattern message and any other nonzero status reports `unable to inspect FILE`.

Use these complete implementations:

```bash
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
```

- [ ] **Step 6: Ignore unique build and lock paths and document focused checks**

Replace the fixed temporary ignore entry in `.gitignore` with:

```gitignore
.build-presentation-variants*
```

Add these required checks to `AGENTS.md`:

```sh
bash tests/runtime_checks.sh
bash tests/compile_all_checks.sh
```

Document that the focused runtime checks require Poppler tools (`pdfinfo`, `pdftotext`, `pdftohtml`, and `pdffonts`) in addition to the existing TeX/Biber/ripgrep tools.

- [ ] **Step 7: Run shell, transactional, runtime, and textual checks**

Run:

```sh
bash -n compile_all.sh
bash -n tests/template_checks.sh
bash -n tests/runtime_checks.sh
bash -n tests/compile_all_checks.sh
bash tests/compile_all_checks.sh
bash tests/runtime_checks.sh all
bash tests/template_checks.sh
```

Expected: every command exits zero; the injected failure preserves the sentinel-only prior output; success publishes exactly 12 PDFs; the second concurrent run fails with the lock diagnostic.

- [ ] **Step 8: Commit transactional builds and test robustness**

```sh
git status --short
git diff -- compile_all.sh tests/compile_all_checks.sh tests/template_checks.sh .gitignore AGENTS.md
git diff --check
git log --oneline -5
git add compile_all.sh tests/compile_all_checks.sh tests/template_checks.sh .gitignore AGENTS.md
git diff --cached
git diff --cached --check
git commit -m "fix(build): publish complete isolated variant matrices"
```

---

### Task 7: Public README And Reproducible Release Procedure

**Files:**
- Modify: `tests/template_checks.sh:86-125`
- Modify: `README.md`
- Modify: `RELEASING.md`
- Modify: `AGENTS.md`

**Interfaces:**
- Consumes: runtime commands from Tasks 1-6 and release files `presentation.sty`, `presentation-minimal.tex`, `LICENSE.txt`.
- Produces: public onboarding; README-only upstream acknowledgement; parameterized tag-derived release process for `v1.1.0`.

- [ ] **Step 1: Add failing documentation and release invariants**

Add to `tests/template_checks.sh`:

```bash
check_present 'latexmk -lualatex presentation-minimal.tex' README.md 'README should document the released minimal starter command'
check_present 'Biber is required' README.md 'README should explicitly document the Biber dependency'
check_present 'https://github.com/pmichaillat/latex-presentation' README.md 'README should acknowledge the upstream presentation project'
check_present 'https://github.com/YuntianZhao/Beamer-Template/releases' README.md 'README should link to public releases'
check_present 'test -z "$(git status --porcelain)"' RELEASING.md 'release instructions should reject a dirty tree'
check_present 'git archive "$version"' RELEASING.md 'release assets should be extracted from the tag'
check_present 'gh repo edit YuntianZhao/Beamer-Template --visibility public' RELEASING.md 'release instructions should document public visibility'
check_absent 'git tag -a v1.0.0' RELEASING.md 'release instructions should not hard-code the initial tag command'
```

- [ ] **Step 2: Run textual checks and verify documentation assertions fail**

Run:

```sh
bash tests/template_checks.sh
```

Expected: nonzero exit for the new README and release-provenance assertions.

- [ ] **Step 3: Expand README onboarding and prerequisites**

Revise `README.md` so the Quick Start has both repository and release workflows:

````markdown
## Quick Start

Clone the repository, edit `presentation.tex`, and build the full example with LuaLaTeX:

```sh
latexmk -lualatex presentation.tex
```

For a new presentation, start from the smaller released template:

```sh
latexmk -lualatex presentation-minimal.tex
```
````

Add a prerequisites section containing this exact operational requirement:

```markdown
## Prerequisites

Biber is required, including for the minimal starter, because `presentation.sty` loads the `biblatex-chicago` backend. Use `latexmk` so Biber and all required LaTeX reruns are invoked automatically.

A complete TeX Live installation is the simplest setup. Package-level installations need Beamer, `iftex`, Libertinus and XITS fonts, Source Code Pro, `unicode-math`, `mathalpha`, `setspace`, `microtype`, `etoolbox`, `biblatex-chicago`, `listings`, `algorithm`, `algorithmicx`, `adjustbox`, `booktabs`, `multirow`, and `xtab`.
```

Add public project links and the requested acknowledgement:

```markdown
## Acknowledgements

Thank you to Pascal Michaillat for the excellent [Minimalist LaTeX Template for Academic Presentations](https://github.com/pmichaillat/latex-presentation), which inspired and provided the foundation for this template.
```

Link `https://github.com/YuntianZhao/Beamer-Template` and `https://github.com/YuntianZhao/Beamer-Template/releases` near the introduction or Quick Start.

- [ ] **Step 4: Replace the one-shot release commands with a clean, tag-derived procedure**

In `RELEASING.md`, retain the existing local verification commands and replace the publish block with:

```bash
version=v1.1.0
test -z "$(git status --porcelain)"
git rev-parse --verify HEAD
if git rev-parse --verify "$version" >/dev/null 2>&1; then
  printf 'ERROR: tag %s already exists.\n' "$version" >&2
  exit 1
fi

git tag -a "$version" -m "$version"
git push origin "$version"

release_dir=$(mktemp -d "${TMPDIR:-/tmp}/beamer-template-release.XXXXXX")
trap 'rm -rf "$release_dir"' EXIT
git archive "$version" presentation.sty presentation-minimal.tex LICENSE.txt | tar -x -C "$release_dir"
for file in presentation.sty presentation-minimal.tex LICENSE.txt; do
  git show "$version:$file" | cmp - "$release_dir/$file"
done

gh release create "$version" \
  "$release_dir/presentation.sty" \
  "$release_dir/presentation-minimal.tex" \
  "$release_dir/LICENSE.txt" \
  --generate-notes \
  --verify-tag
rm -rf "$release_dir"
trap - EXIT
```

Add the public visibility command immediately before tagging, with a warning that history must be audited first:

```sh
gh repo edit YuntianZhao/Beamer-Template --visibility public --accept-visibility-change-consequences
```

State that `version` must be updated for every later release and that release files must never be taken directly from a dirty working tree.

- [ ] **Step 5: Update maintainer instructions**

In `AGENTS.md`, document that a public release requires:

- A clean worktree and reviewed Git history.
- Package version matching the tag.
- Assets extracted from the tag.
- Verification of public asset access after release.

Keep the explicit prohibition on tagging, pushing, changing visibility, or creating releases without user approval.

- [ ] **Step 6: Verify documentation invariants and rendered Markdown references**

Run:

```sh
bash tests/template_checks.sh
rg --fixed-strings 'Biber is required' README.md
rg --fixed-strings 'https://github.com/pmichaillat/latex-presentation' README.md
rg --fixed-strings 'git archive "$version"' RELEASING.md
git diff --check
```

Expected: every command exits zero.

- [ ] **Step 7: Commit public documentation and release provenance**

```sh
git status --short
git diff -- README.md RELEASING.md AGENTS.md tests/template_checks.sh
git diff --check
git log --oneline -5
git add README.md RELEASING.md AGENTS.md tests/template_checks.sh
git diff --cached
git diff --cached --check
git commit -m "docs: prepare public v1.1.0 release"
```

---

### Task 8: Full Verification, Security Audit, Publication, And Release

**Files:**
- Verify: all tracked source, test, documentation, and history files.
- Generate only ignored artifacts under `.engine-check/` and `output/test/`.
- External changes: GitHub repository visibility, tag `v1.1.0`, release `v1.1.0`.

**Interfaces:**
- Consumes: all prior task commits and the user-approved external publication actions.
- Produces: public repository, pushed main branch, annotated `v1.1.0` tag, three-asset GitHub release, publicly discoverable release API response.

- [ ] **Step 1: Run all focused and textual regressions from a clean command context**

Run:

```sh
bash tests/template_checks.sh
bash tests/template_checks_checks.sh
bash tests/runtime_checks.sh all
bash tests/compile_all_checks.sh
```

Expected: all commands exit zero.

- [ ] **Step 2: Force fresh full-deck builds on all supported engines**

Run serially so macOS Biber extraction does not race:

```sh
mkdir -p .engine-check/lualatex .engine-check/pdflatex .engine-check/xelatex
latexmk -g -lualatex -interaction=nonstopmode -halt-on-error -outdir=.engine-check/lualatex presentation.tex
latexmk -g -pdf -interaction=nonstopmode -halt-on-error -outdir=.engine-check/pdflatex presentation.tex
latexmk -g -xelatex -interaction=nonstopmode -halt-on-error -outdir=.engine-check/xelatex presentation.tex
```

Expected: all three commands exit zero.

- [ ] **Step 3: Force fresh minimal-starter builds on all supported engines**

Run serially:

```sh
mkdir -p .engine-check/minimal-lualatex .engine-check/minimal-pdflatex .engine-check/minimal-xelatex
latexmk -g -lualatex -interaction=nonstopmode -halt-on-error -outdir=.engine-check/minimal-lualatex presentation-minimal.tex
latexmk -g -pdf -interaction=nonstopmode -halt-on-error -outdir=.engine-check/minimal-pdflatex presentation-minimal.tex
latexmk -g -xelatex -interaction=nonstopmode -halt-on-error -outdir=.engine-check/minimal-xelatex presentation-minimal.tex
```

Expected: all three commands exit zero.

- [ ] **Step 4: Verify final engine logs are clean**

Run:

```sh
rg 'Overfull \\[hv]box|LaTeX Font Warning|Package biblatex Warning: Conflicting options|There were undefined references|Please rerun LaTeX|Please \(re\)run Biber|Missing character' .engine-check -g '*.log'
```

Expected: exit 1 with no matches.

- [ ] **Step 5: Build and verify the complete variant matrix**

Run:

```sh
./compile_all.sh
```

Expected: exit zero with `Built all presentation test variants.` and exactly the 12 documented PDFs under `output/test/`.

- [ ] **Step 6: Request an independent code review before publication**

Invoke `superpowers:requesting-code-review`. Give the reviewer:

- Base commit: `1280bd8`.
- Head commit: current `HEAD`.
- Requirements: the approved design spec at `docs/superpowers/specs/2026-07-27-public-release-compatibility-design.md`.
- Explicit exclusions: accessibility and handout mode.
- Evidence commands from Steps 1-5.

Resolve every Critical or Important finding, rerun affected focused checks, and create a new non-amended fix commit when needed.

- [ ] **Step 7: Audit all public history for secrets and private filenames**

First inspect repository state and reachable file history:

```sh
git status --short --branch
git remote -v
git log --all --name-only --pretty=format: | sort -u
```

Search reachable history for high-confidence credential patterns:

```sh
git log -p --all | rg -n 'AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----|xox[baprs]-[A-Za-z0-9-]+'
```

Expected: exit 1 with no matches.

Search historical filenames:

```sh
git log --all --name-only --pretty=format: | rg -i '(^|/)(\.env($|\.)|id_rsa|credentials|secrets?\.(json|ya?ml|txt)|.*\.(pem|p12|key))$'
```

Expected: exit 1 with no matches. Stop publication and ask the user if either audit produces a match or if any tracked PDF/source contains private material.

- [ ] **Step 8: Inspect the final commit set before pushing**

Run:

```sh
git status --short --branch
git diff origin/main...HEAD --stat
git diff origin/main...HEAD
git log --oneline --decorate origin/main..HEAD
git diff --check origin/main...HEAD
```

Expected: clean worktree; only the design, plan, runtime, tests, build tooling, and documentation changes described above; no secrets or generated PDFs.

- [ ] **Step 9: Hand publication off to the authoritative checklist**

Do not run remote publication commands from this plan.
`RELEASING.md` is the single authoritative publication procedure and supersedes
the former remote-first Steps 9-15.

After the owner approves remote mutation, follow `RELEASING.md` from **Prepare
Reviewed Main** through **Release Record** without reordering or selecting only
individual commands. That procedure binds the reviewed SHA to local `main`,
runs all focused and engine gates, creates and byte-checks the local annotated
tag before remote mutation, pushes and verifies reviewed `HEAD:main` before
changing visibility, and checks public API discovery and downloaded bytes after
release creation.

Expected before approval: no push, visibility change, tag creation/deletion, or
release operation has occurred. Expected after an approved publication run: all
`RELEASING.md` preconditions, ordering gates, and postconditions pass.

- [ ] **Step 10: Report verification and publication evidence**

Before publication, report the reviewed commit, focused suites, six serial
engine builds and final-log scan, 12-variant matrix, clean-history audit, and
the explicit no-remote-mutation state.

After an owner-approved publication run, add the local/remote main and tag
target SHA agreement, repository URL and `PUBLIC` visibility, release URL,
unauthenticated API result, all three public asset byte comparisons, and any
failed/retried gate. Keep accessibility and handout mode explicitly excluded
and retain the owner-selected README-only upstream MIT notice concern.
