# SPEC — nix-lefthook-tcl-syntax

## §G Goal

Lefthook-compatible Tcl syntax checker. Validates every staged `.tcl`/`.exp` file for completeness (balanced braces, brackets, quotes) and rejects `#` lines that masquerade as comments inside `set { }` literal blocks. Non-Tcl files are skipped silently. Nix flake pkg via `writeShellApplication`. Opensource-safe: zero credentials, zero local paths, zero private refs.

## §C Constraints

- C1: Pure bash wrapper driving `tclsh` — no Python/Ruby/etc runtime deps; Tcl is the only language runtime
- C2: Nix flake — `writeShellApplication` pkg (`runtimeInputs = [ pkgs.tcl ]`), devShells as plain `mkShell` with inlined lefthook wrappers
- C3: MIT license
- C4: Multi-platform: `aarch64-darwin`, `x86_64-darwin`, `x86_64-linux`, `aarch64-linux`
- C5: Detached from parent project — no credential leaks, no hardcoded local paths, no private repo refs
- C6: All config via env vars — no config files beyond baseline (`config/lefthook/file_size_limits.yml`)
- C7: Exit non-zero on syntax violations — hard enforcement, blocks commit/push

## §I Interfaces

- I.cli: `lefthook-tcl-syntax file1.tcl [file2.exp ...]` — main binary; exit 1 if any file fails Tcl validation (blocks commit/push), exit 0 on pass or no matching files
- I.env: `LEFTHOOK_TCL_SYNTAX_TIMEOUT` (seconds, default `30`) — wraps the hook invocation via `timeout` in `lefthook.yml`/`lefthook-remote.yml`
- I.remote: `lefthook-remote.yml` — consumers add as a lefthook remote; pre-commit on `{staged_files}`, pre-push on `{push_files}`, both globbed to `*.tcl`
- I.flake: `packages.${system}.default` — the `lefthook-tcl-syntax` Nix pkg output
- I.devshell: `devShells.${system}.default` (direnv `use flake`, `dev.sh` shellHook) + `.#ci` (sets `BATS_LIB_PATH`) — both bundle the self pkg plus 15 inlined lefthook wrapper binaries
- I.ci: `.github/workflows/ci.yml` — linux + macos via `nix-lefthook-ci-action`; `.github/workflows/update-pins.yml` — automated flake input pin refresh

## §V Invariants

- V1: Each `.tcl`/`.exp` argument is parsed by `tclsh`; `info complete` failure (unclosed braces, brackets, or quotes) → exit 1
- V2: A `#`-prefixed line inside an open `set <name> { ... }` brace block is a literal list element, not a comment — flagged as an error, exit 1
- V3: `#` inside a proc body (or any non-`set`-brace context) is a legitimate comment — must pass
- V4: `set { }` brace depth is tracked across lines via `{`/`}` counts; the block closes only when depth returns to zero
- V5: Files whose extension is neither `.tcl` nor `.exp` are skipped silently (continue, no error)
- V6: Non-existent path arguments are skipped silently (`[ -f "$f" ] || continue`) — no crash
- V7: No arguments → immediate exit 0
- V8: Multiple files are checked independently; one failing file fails the run while passing files are still reported, final exit reflects any failure
- V9: `.exp` (Expect) files are accepted on the same Tcl-completeness basis as `.tcl`
- V10: `LEFTHOOK_TCL_SYNTAX_TIMEOUT` bounds wall-clock time per hook invocation (default 30s) via `timeout`
- V11: No credentials, secrets, tokens, API keys, or private paths in any tracked file
- V12: No hardcoded local filesystem paths (enforced by `nix-lefthook-git-no-local-paths` hook)
- V13: `dev.sh` sets `BATS_LIB_PATH` and auto-installs lefthook when `.git/hooks/pre-commit` is absent
- V14: Flattened flake — inputs are `nixpkgs-lock`, `nixpkgs` (follows), plus 15 `flake = false` `-src` leaves; no `nix-dev-shell-agentic`, so no transitive dep-tree explosion
- V15: `packages.${system}.default` pins `runtimeInputs = [ pkgs.tcl ]` (Tcl, not statix) and reads `./lefthook-tcl-syntax.sh` verbatim
- V16: CI runs lefthook pre-commit and pre-push (`--all-files`) on linux + macos
- V17: All linters pass: shellcheck, shfmt (`-i 2`), nixfmt, statix, deadnix, yamllint, typos, editorconfig-checker, bats-parse, bats-unit, nix-flake-check, nix-no-embedded-shell, trailing-whitespace, missing-final-newline, git-conflict-markers, git-no-local-paths, file-size-check
- V18: `config/lefthook/file_size_limits.yml` raises the `nix` limit to `10240` (15-wrapper flattened `flake.nix`) and the `md` limit to `8192` (full SPEC.md), keeping both under the size gate

## §T Tasks

| id | status | task | cites |
|----|--------|------|-------|
| T1 | x | core checker: `tclsh` `info complete` validation per `.tcl`/`.exp` file | V1,V9,I.cli |
| T2 | x | `set { }` literal-block `#` detection with cross-line brace-depth tracking | V2,V3,V4 |
| T3 | x | skip non-Tcl extensions and non-existent paths silently | V5,V6 |
| T4 | x | no-arg fast exit and independent multi-file failure aggregation | V7,V8 |
| T5 | x | `timeout` wrapping via `LEFTHOOK_TCL_SYNTAX_TIMEOUT` in hook configs | V10,I.env |
| T6 | x | Nix flake pkg (`writeShellApplication`, `runtimeInputs = [ pkgs.tcl ]`) | C1,C2,V15,I.flake |
| T7 | x | flattened devShells (`default` + `ci`) as plain `mkShell` with 15 inlined wrappers | C2,V14,I.devshell |
| T8 | x | `lefthook-remote.yml` for consumers (pre-commit + pre-push) | I.remote |
| T9 | x | `dev.sh` — `BATS_LIB_PATH` + lefthook auto-install | V13 |
| T10 | x | unit tests: `lefthook-tcl-syntax.bats` (11 tests, assert_failure for bad syntax) | V1-V9 |
| T11 | x | unit tests: `dev.bats` (3 tests) | V13 |
| T12 | x | GitHub Actions CI: linux + macos via nix-lefthook-ci-action | V16,I.ci |
| T13 | x | linter suite via lefthook remotes | V17 |
| T14 | x | `config/lefthook/file_size_limits.yml`: raise `nix` to 10240, `md` to 8192 | V18,C6 |
| T15 | x | opensource audit: no credentials/local-paths/private-refs in tracked files | V11,V12,C5 |
