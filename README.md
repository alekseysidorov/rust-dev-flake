# nix-devtools

Reusable Nix development tooling built around a small set of composable
package-set capabilities and flake modules.

The project follows a simple split:

- `overlays.default` exposes package-set capabilities and tools.
- `modules.flake.*` exposes reusable flake integration.
- `flake.nix` contains this repository's own development policy.

## Installation

Add `nix-devtools` as a flake input:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    nix-devtools = {
      url = "github:alekseysidorov/rust-dev-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
```

## Overlay

`overlays.default` is the main package-set API.

```nix
pkgs = import inputs.nixpkgs {
  inherit system;

  overlays = [
    inputs.nix-devtools.overlays.default
  ];
};
```

It exposes development helpers and concrete packages directly through `pkgs`.

Examples:

```nix
pkgs.mkRustDevHelpers
pkgs.mkGitHooks
pkgs.writeNushellApplication
pkgs.writeNushellScript
pkgs.projectSource

pkgs.diplomat-tool
pkgs.comchan
```

The default overlay also includes `rust-overlay`, so Rust toolchains are
available through:

```nix
pkgs.rust-bin
```

## Rust development

`mkRustDevHelpers` provides shared Crane configuration and reusable Rust checks.

Minimal usage:

```nix
let
  rustDev = pkgs.mkRustDevHelpers {
    inherit pkgs;

    src = pkgs.projectSource {
      projectRoot = ./.;
    };
  };
in
{
  checks = {
    test = rustDev.checks.test "--workspace";
    clippy = rustDev.checks.clippy "--workspace --all-targets";
    doc = rustDev.checks.doc "--workspace";
    audit = rustDev.checks.audit "";
  };
}
```

Without an explicit toolchain, Crane uses Rust from the supplied nixpkgs package
set.

### Custom Rust toolchain

A custom toolchain may be supplied as either a derivation or a function from a
package set to a derivation.

For example, using `rust-overlay`:

```nix
let
  rustDev = pkgs.mkRustDevHelpers {
    inherit pkgs;

    src = pkgs.projectSource {
      projectRoot = ./.;
    };

    toolchain =
      p:
      p.rust-bin.stable."1.97.1".minimal;
  };
in
{
  checks.test =
    rustDev.checks.test "--workspace";
}
```

Available check builders:

```nix
rustDev.checks.nextest
rustDev.checks.clippy
rustDev.checks.test
rustDev.checks.doc
rustDev.checks.audit
```

Each builder accepts additional Cargo arguments:

```nix
rustDev.checks.nextest "--workspace --all-features"
```

The helpers share vendored dependencies and Crane build artifacts between checks
where possible.

## Project sources

`projectSource` applies the project's `.gitignore` before optionally selecting a
subdirectory.

```nix
src = pkgs.projectSource {
  projectRoot = ./.;
  sourceDir = "crates/server";
};
```

For the whole project:

```nix
src = pkgs.projectSource {
  projectRoot = ./.;
};
```

## Nushell applications

`writeNushellApplication` creates executable Nushell applications with managed
runtime dependencies and environment variables.

```nix
pkgs.writeNushellApplication {
  name = "hello";

  runtimeInputs = [
    pkgs.git
  ];

  runtimeEnv = {
    MESSAGE = "hello";
  };

  text = ''
    print $env.MESSAGE
    git --version
  '';
}
```

For small standalone scripts:

```nix
pkgs.writeNushellScript "hello" ''
  print "hello"
''
```

## Git hooks

The reusable Git hooks flake module turns named executable scripts into an
installer package.

Import the module:

```nix
{
  imports = [
    inputs.nix-devtools.modules.flake.gitHooks
  ];

  perSystem =
    { pkgs, ... }:
    {
      gitHooks = {
        pre-commit =
          pkgs.writeNushellScript "pre-commit" ''
            nix fmt -- --fail-on-change
          '';

        pre-push =
          pkgs.writeNushellScript "pre-push" ''
            nix flake check -L
          '';
      };
    };
}
```

This exposes:

```text
packages.install-git-hooks
```

Install the configured hooks with:

```bash
nix run .#install-git-hooks
```

The hook values are executable files, not inline script bodies.

## Reusable flake modules

The project exposes reusable flake-parts modules through `modules.flake`.

Currently available integrations include:

```nix
inputs.nix-devtools.modules.flake.packages
inputs.nix-devtools.modules.flake.gitHooks
```

The modules are intended to be independently reusable. Importing a module should
provide the capabilities required by that module without requiring consumers to
know about internal wiring.

## Development

This repository uses its own tooling through the same public interfaces it
exposes to consumers.

Formatting:

```bash
nix fmt
```

Run all checks:

```bash
nix flake check -L
```

Install repository Git hooks:

```bash
nix run .#install-git-hooks
```

## Design

The architecture intentionally keeps three concerns separate:

```text
overlay API
    package-set capabilities

flake modules
    reusable integration mechanisms

flake.nix
    repository-specific development policy
```

Package definitions depend on explicit package-set capabilities rather than the
flake `inputs` object wherever possible.

Reusable helpers live in the package set when they require a `pkgs` universe.
Pure Nix functions belong in `lib`.

The goal is to keep the public surface small, composable, and unsurprising.
