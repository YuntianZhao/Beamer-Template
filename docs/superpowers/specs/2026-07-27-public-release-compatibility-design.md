# Public Release And Compatibility Hardening Design

## Goal

Prepare `YuntianZhao/Beamer-Template` for public use and release `v1.1.0` with
the confirmed compatibility, metadata, build, release, and documentation
weaknesses corrected.

The work will preserve the existing architecture and minimalist visual style.
It will not add PDF accessibility tagging or support Beamer handout mode.

## Scope

The implementation will address:

- Dark-mode Beamer semantic colors inherited as black from `seagull`.
- pdfLaTeX failures for multi-token calligraphic math arguments.
- pdfLaTeX bold-italic Libertinus Sans substitution.
- Missing title subtitle, institute, title graphic, and frame subtitle output.
- Duplicated or missing PDF title and author metadata.
- `\paperurl` failures for URLs containing fragments.
- The `biblatex-chicago` option conflict and undocumented Biber requirement.
- Sample content that intrudes into the footline in supported variants.
- Non-transactional and concurrency-unsafe variant builds.
- Textual regression checks that conflate absent content with read errors.
- Missing package name/version metadata.
- Release assets that can differ from their tag.
- The instructional `\varphi`/`\varpsi` typo.
- README onboarding, prerequisites, attribution, and public-project links.
- Public repository visibility and a verified `v1.1.0` release.

Explicitly excluded:

- Tagged-PDF, PDF/UA, alternative-text, or other accessibility work.
- Beamer `handout` mode and its overlay-flattening behavior.

## Runtime Template Design

### Colors

Keep the GitHub-inspired palettes. Explicitly assign every standard semantic
Beamer color used by the theme instead of inheriting black values from
`seagull`:

- Normal and title text use `GitHubFg`.
- Structure text uses `GitHubBlue`.
- Alerted text uses `GitHubRed`.
- Example text uses `GitHubGreen`.
- Alerted and example block variants use matching foreground colors with the
  existing subtle canvas backgrounds.

The sample deck will include standard semantic commands so this behavior is
exercised by normal builds.

### Engine Compatibility

Remove the pdfLaTeX math-alphabet implementation that inspects the first input
token with `\ifnum`. Use the math packages' robust alphabet commands so
`\mathcal`, `\mathbcal`, and related commands accept arbitrary normal math
arguments, including multiple letters.

Correct the pdfLaTeX Libertinus Sans bold-italic shape mapping rather than
allowing LaTeX to substitute bold upright text. LuaLaTeX and XeLaTeX behavior
will remain unchanged except where tests require engine-consistent output.

### Standard Beamer Fields

Preserve the custom minimalist title page while conditionally inserting:

- `\insertsubtitle` below the title.
- `\insertinstitute` with the author information.
- `\inserttitlegraphic` when supplied.
- `\insertframesubtitle` below a frame title.

Empty fields will add no visible space. Existing decks that do not use these
fields will retain their current composition as closely as possible.
The title-page order will be title, subtitle, rule, author, institute, date,
URL, and title graphic. Frame subtitles will use a smaller muted style directly
below the frame title.

### Metadata And URLs

Use Beamer's automatic PDF title and author metadata derived from `\title` and
`\author`. Remove duplicated hard-coded `pdftitle` values from both starters.
Existing viewer preferences and hidden-link behavior will remain.

Store the paper URL without creating a nested macro definition from raw URL
tokens. `\paperurl{...}` will continue to be the public interface and will
accept ordinary URL fragments such as `#section`.

### Bibliography And Package Identity

Retain `biblatex-chicago` with Biber as the template's bibliography backend.
Remove or reconcile the `giveninits`/`uniquename` conflict so final logs are
warning-free. Add `\NeedsTeXFormat` and a versioned `\ProvidesPackage` entry
for `presentation` version `1.1.0` dated 2026-07-27.

## Sample And Documentation Design

Adjust overflowing sample content without weakening the global sparse-slide
defaults. Local font size, spacing, or content reductions may be used on the
affected frames. Supported output must not place body content in the footline.
Correct the displayed command for `\varphi`.

Update `README.md` to include:

- Repository and release links suitable for a public project.
- Full and minimal starter quick-start commands.
- Runtime prerequisites, including `latexmk`, Biber, and the required LaTeX
  package collection. A complete TeX Live installation will be the simplest
  recommendation; package-level guidance will name Beamer, Libertinus and XITS
  fonts, Source Code Pro, `unicode-math`, `mathalpha`, `biblatex-chicago`,
  `listings`, `algorithmicx`, `adjustbox`, `booktabs`, `multirow`, and `xtab`.
- The primary and compatible TeX engines.
- Acknowledgement and thanks to Pascal Michaillat's
  `pmichaillat/latex-presentation` project with a direct link.

The upstream project is MIT-licensed and this template retains substantial
upstream structure. The owner has chosen README acknowledgement only and has
declined preserving the complete upstream MIT notice. MIT is not a copyleft
license, but its text requires preservation of its copyright and permission
notice in copies or substantial portions. This remains a known public-release
compliance risk and is not resolved by this design.

Document Biber as required even for the minimal starter because the style
loads the bibliography backend unconditionally.

## Build And Test Design

### Transactional Variant Builds

`compile_all.sh` will use a single-run lock and unique temporary build and
staging directories. It will compile all variants into staging and publish a
new `output/test/` directory only after every build succeeds. Cleanup traps
will remove temporary state on normal failures. A failed run will leave the
previous complete output matrix intact, and a concurrent run will fail with a
clear diagnostic instead of sharing files.

Final logs will be checked for the known warning classes fixed by this work,
including conflicting bibliography options, missing font shapes, unresolved
references, and overfull boxes in the shipped sample.

### Regression Coverage

Tests will be added before each behavioral fix and will cover:

- Explicit non-black semantic colors in dark mode.
- Multi-token `\mathcal` and `\mathbcal` under pdfLaTeX.
- pdfLaTeX bold-italic text without font substitution.
- Conditional title, institute, title-graphic, and frame-subtitle rendering.
- Automatic PDF title and author metadata.
- A paper URL containing a fragment.
- Clean final bibliography logs.
- Warning-free supported sample variants.

`tests/template_checks.sh` will distinguish ripgrep's no-match status from
I/O or invocation errors and will verify the new package, documentation,
build, and release invariants.

## Release And Publication Design

`RELEASING.md` will require a clean working tree, accept a version variable,
and build release assets from the tagged tree rather than mutable working-tree
paths. The procedure will verify asset hashes against the tag before release.

Before changing repository visibility, inspect current tracked files and Git
history for credentials, secrets, or private material. Publication proceeds
only if that audit is clean.

The rollout sequence is:

1. Complete all implementation and verification locally.
2. Commit the intended source, tests, documentation, and design artifacts.
3. Push the verified main-branch commit.
4. Change `YuntianZhao/Beamer-Template` from private to public visibility.
5. Create and push annotated tag `v1.1.0` at the verified commit.
6. Extract `presentation.sty`, `presentation-minimal.tex`, and `LICENSE.txt`
   from the tag and upload those exact files to GitHub release `v1.1.0`.
7. Verify public repository and release access without private credentials,
   asset/tag correspondence, and downstream release discoverability.

Making the upstream repository public removes the authentication blocker in
the public downstream synchronization workflow. The new release gives that
workflow a version containing these fixes to import.

## Verification Gates

The release is blocked unless all of the following succeed:

```sh
bash tests/template_checks.sh
latexmk -lualatex -interaction=nonstopmode -halt-on-error -outdir=.engine-check/lualatex presentation.tex
latexmk -pdf -interaction=nonstopmode -halt-on-error -outdir=.engine-check/pdflatex presentation.tex
latexmk -xelatex -interaction=nonstopmode -halt-on-error -outdir=.engine-check/xelatex presentation.tex
latexmk -lualatex -interaction=nonstopmode -halt-on-error -outdir=.engine-check/minimal-lualatex presentation-minimal.tex
latexmk -pdf -interaction=nonstopmode -halt-on-error -outdir=.engine-check/minimal-pdflatex presentation-minimal.tex
latexmk -xelatex -interaction=nonstopmode -halt-on-error -outdir=.engine-check/minimal-xelatex presentation-minimal.tex
./compile_all.sh
```

Focused runtime regressions and final warning checks must also pass. After
publication, GitHub API checks must report public visibility and release
`v1.1.0` with the expected three runtime assets.
