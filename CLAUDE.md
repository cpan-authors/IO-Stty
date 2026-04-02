# IO::Stty Development Notes

## Build

```
perl Makefile.PL
make
make test
```

## README

README.md is generated from the POD in `lib/IO/Stty.pm` via `pod2markdown`.
The CI badge is embedded in the POD using `=for markdown` so it survives
regeneration. After changing any POD, run:

```
make readme
```

This requires `Pod::Markdown` (`cpanm Pod::Markdown` to install).

## MANIFEST

When adding new files to the repo — especially test files in `t/` — update
`MANIFEST` so they are included in the distribution tarball. Files missing
from `MANIFEST` will not ship to CPAN. Conversely, files that should *not*
ship (e.g. `CLAUDE.md`, `.github/`, `.gitignore`, `.*rc` config files, and `cpanfile`) belong in `MANIFEST.SKIP`.

## Tests

- `t/00-load.t` — module loads
- `t/01-baud-rate.t` — baud rate setting, warnings, and regression guard (requires IO::Pty)
- `t/01-functional.t` — pty-based functional tests (requires IO::Pty)
- `t/01-cc-to-hat.t` — hat notation for control chars
- `t/01-parse-char-value.t` — special character value parsing
- `t/02-show-me-the-crap.t` — `-a` output format
- `t/02-single-arg.t` — single-arg stty behavior
- `t/baud-rates.t` — baud rate display via show_me_the_crap
- `t/99-pod.t`, `t/99-pod-coverage.t` — POD validation

## Release

Releases are **human-only**. Automated agents (Claude Code, Kōan, etc.) must
**never** bump `$VERSION`, update `Changes`, run `make dist`, or perform any
other release-preparation step. These are manual, intentional acts.

The human release process is:

1. Update `Changes` with new version and entries.
2. Bump `$VERSION` in `lib/IO/Stty.pm` (only place it's set; `Makefile.PL` reads it via `VERSION_FROM`).
3. Run `make readme` to regenerate `README.md`.
4. Run `make test` to verify.
5. Run `make dist` to build the tarball.
