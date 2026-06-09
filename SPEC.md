# Flatten SPEC — nix-lefthook-tcl-syntax

## Goal
Remove the `nix-dev-shell-agentic` flake input (and its transitive
explosion) from `flake.nix`, preserving the `lefthook-tcl-syntax` package
output and keeping CI (`nix develop .#ci` + remote lefthook hooks) and bats
green.

## Before
- flake.lock: 59 nodes.
- Inputs: nixpkgs-lock, nixpkgs(follows), nix-dev-shell-agentic(flake).
- Outputs: packages.<sys>.default = lefthook-tcl-syntax
  (writeShellApplication, runtimeInputs = [ pkgs.tcl ]); devShells ci/default
  via nix-dev-shell-agentic.lib.mkShells.

## Consumption of the agentic devShell here
- `.envrc` = `use flake` → devShells.<sys>.default.
- CI default devshell = ci: enters `nix develop .#ci` and runs lefthook
  install / pre-commit / pre-push --all-files.
- lefthook.yml `remotes:` invoke wrapper binaries that must be on PATH in
  the ci shell: lefthook-{nixfmt,shellcheck,shfmt,deadnix,bats-unit,yamllint,
  typos,trailing-whitespace,missing-final-newline,git-conflict-markers,
  editorconfig-checker,git-no-local-paths,file-size-check,statix,
  nix-no-embedded-shell}; bare `bats` (bats-parse); bare `nix flake check`
  (nix-flake-check); plus lefthook, git, coreutils, parallel.
- bats unit tests need BATS_LIB_PATH + (dev.sh-driven) lefthook-tcl-syntax.

## Delta vs proven statix template
tcl-syntax's lefthook.yml has TWO extra remotes beyond the statix template:
  - nix-lefthook-statix          → wrapper `lefthook-statix` (runtimeInputs statix)
  - nix-lefthook-nix-no-embedded-shell → wrapper `lefthook-nix-no-embedded-shell`
    (special: SCANNER= prefix pointing at scan-nix-no-embedded-shell.sh in src,
    mirrored verbatim from nix-dev-shell-agentic).
The package runtimeInputs stays `pkgs.tcl` (NOT statix). Everything else
mirrors the statix template.

## Changes
### Inputs
Remove nix-dev-shell-agentic. Add `flake = false` `-src` inputs for each
sibling wrapper the remotes invoke (15 leaves: the 13 from statix template +
nix-lefthook-statix-src + nix-lefthook-nix-no-embedded-shell-src). Result
inputs: nixpkgs-lock, nixpkgs(follows), + 15 flake=false leaves. No flake
input → no dep-tree explosion.

### packages (UNCHANGED logic)
packages.<sys>.default = writeShellApplication { name="lefthook-tcl-syntax";
runtimeInputs=[pkgs.tcl]; text=readFile ./lefthook-tcl-syntax.sh; }.

### devShells (plain mkShell)
- lefthookWrappersFor helper (from proven template): bats-unit +
  file-size-check special multi-input handling, nix-no-embedded-shell special
  SCANNER prefix, rest via `wrap`.
- batsWithLibsFor helper. ciCommon = [self pkg, batsWithLibs, bats, coreutils,
  git, lefthook, nix, parallel, statix] ++ wrappers.
- ci = mkShell { packages = ciCommon; BATS_LIB_PATH = "${batsWithLibs}/share/bats"; }
- default = mkShell { packages = ciCommon; shellHook = dev.sh expanded; }

### Side changes required to land a flattened flake green
- config/lefthook/file_size_limits.yml: nix 4096 -> 10240. The flattened
  flake.nix exceeds 4096 bytes (15 inline wrappers); the proven template repo
  uses nix:10240. Pure config, no logic.
- lefthook-tcl-syntax.sh: reformat 4-space -> 2-space because the
  nix-lefthook-shfmt remote (ref: main) now defaults to `-i 2`.
  Whitespace-only; wrapper behavior identical. Done via `shfmt -w -i 2 -ci`.

## Validation gate (all must pass)
- nix flake check — PASS.
- nix flake show — packages.<sys>.default = lefthook-tcl-syntax;
  devShells ci+default. UNCHANGED set.
- nix build .#default + smoke (no-arg -> 0).
- bats tests/unit/ inside nix develop .#ci — PASS.
- lefthook run pre-commit --all-files inside .#ci — PASS.
- lock nodes << 59.

## Then
Branch flatten-drop-agentic, commit, push, DRAFT PR.
Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
