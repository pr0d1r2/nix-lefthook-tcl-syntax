# nix-lefthook-tcl-syntax

<!-- hallucinogen:autonomy-disclaimer start -->
> Read [LLM-DISCLAIMER](docs/LLM-DISCLAIMER.md) first. This repository is
> tended by an autonomous loop, and that file says what the loop may do here,
> what it may not, and what to check before trusting anything in this tree.
<!-- hallucinogen:autonomy-disclaimer end -->

[![CI](https://github.com/pr0d1r2/nix-lefthook-tcl-syntax/actions/workflows/ci.yml/badge.svg)](https://github.com/pr0d1r2/nix-lefthook-tcl-syntax/actions/workflows/ci.yml) [![NixOS 26.05](https://img.shields.io/badge/NixOS-26.05-blue.svg?logo=nixos)](https://nixos.org)

> This code is LLM-generated and validated through an automated integration process using [lefthook](https://github.com/evilmartians/lefthook) git hooks, [bats](https://github.com/bats-core/bats-core) unit tests, and GitHub Actions CI.

Lefthook-compatible [Tcl](https://www.tcl.tk/) wrapper, packaged as a Nix flake.

Filters `.tcl` files from staged arguments and checks Tcl syntax. Exits 0 when no matching files are found.

## Architecture

```mermaid
flowchart LR
  consumer["consumer lefthook.yml"] -->|"remotes"| remote["lefthook-remote.yml"]
  remote -->|"pre-commit: *.{tcl,exp} → {staged_files}"| lefthook_tcl_syntax["lefthook-tcl-syntax"]
  remote -->|"pre-push: *.{tcl,exp} → {push_files}"| lefthook_tcl_syntax["lefthook-tcl-syntax"]
  lefthook_tcl_syntax -->|"runs"| tool["Tcl"]
  lefthook_tcl_syntax -->|"exit status"| consumer
```

## Usage

### Option A: Lefthook remote (recommended)

Add to your `lefthook.yml` — no flake input needed, just the wrapper binary in your devShell:

```yaml
remotes:
  - git_url: https://github.com/pr0d1r2/nix-lefthook-tcl-syntax
    ref: main
    configs:
      - lefthook-remote.yml
```

### Option B: Flake input

Add as a flake input:

```nix
inputs.nix-lefthook-tcl-syntax = {
  url = "github:pr0d1r2/nix-lefthook-tcl-syntax";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Add to your devShell:

```nix
nix-lefthook-tcl-syntax.packages.${pkgs.stdenv.hostPlatform.system}.default
```

Add to `lefthook.yml`:

```yaml
pre-commit:
  commands:
    tcl-syntax:
      glob: "*.{tcl,exp}"
      run: timeout ${LEFTHOOK_TCL_SYNTAX_TIMEOUT:-30} lefthook-tcl-syntax {staged_files}
```

### Configuring timeout

The default timeout is 30 seconds. Override per-repo via environment variable:

```bash
export LEFTHOOK_TCL_SYNTAX_TIMEOUT=60
```

## Development

The repo includes an `.envrc` for [direnv](https://direnv.net/) — entering the directory automatically loads the devShell with all dependencies:

```bash
cd nix-lefthook-tcl-syntax  # direnv loads the flake
bats tests/unit/
```

If not using direnv, enter the shell manually:

```bash
nix develop
bats tests/unit/
```

### Development architecture

```mermaid
flowchart LR
  envrc[".envrc"] -->|"use flake"| flake["flake.nix"]
  flake -->|"mkConsumerFlake"| sas["set-and-setting"]
  flake -->|"devShell"| shell["dev shell"]
  shell -->|"on entry"| devsh["dev.sh"]
  sas -->|"assembled hooks"| lh["lefthook.yml"]
  lh -->|"pre-commit / pre-push"| checks["linters, bats, nix flake check"]
  ci[".github/workflows/ci.yml"] -->|"guardrails.yml"| checks
```

## License

MIT
