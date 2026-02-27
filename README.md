# Rust Dev Flake

[![Nix Flake](https://img.shields.io/badge/Nix-Flake-blue.svg)](https://nixos.org/nix/flakes)
[![Rust](https://img.shields.io/badge/Rust-stable-orange.svg)](https://www.rust-lang.org)
[![MIT License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

A reusable Nix flake for Rust project development that provides:

- Automatic code checks (formatting, clippy, tests, docs)
- Dev shells with Rust stable/nightly toolchains
- CI automation scripts
- Cross-platform development support

## Table of Contents

- [Installation](#installation)
- [Usage](#usage)
- [Features](#features)
- [Configuration](#configuration)
- [Commands](#commands)
- [Git Hooks](#git-hooks)
- [Dependencies](#dependencies)
- [Example](#example)

## Installation

Add the flake as an input in your project's `flake.nix`:

```nix
{
  inputs = {
    dev-flake.url = "github:wildboarder/rust-dev-flake";
  };
}
```

## Usage

In your project's `flake.nix`:

```nix
{
  inputs.dev-flake.url = "github:wildboarder/rust-dev-flake";

  outputs = { self, dev-flake }:
    dev-flake.lib.mkRustProject {
      inherit self;
      msrv = { name = "1.85.1"; sha256 = "sha256-..."; };
    };
}
```

## Features

### Project Structure Automation

- One-stop solution for Rust project setup
- Standardized development environment across platforms
- Built-in checks and validation

### Automatic Checks

- Rust formatting with treefmt
- Linting with clippy
- Test execution (unit, integration, doc tests)
- Documentation building
- Benchmark execution

### Development Tools

- Dev shells with stable/nightly Rust
- Cargo Nextest integration
- Semantic version checks
- Publishing dry-runs

## Configuration

### Required Attributes

| Attribute | Type | Description                                         |
| --------- | ---- | --------------------------------------------------- |
| `msrv`    | attr | Minimum supported Rust version with name and sha256 |

### Optional Attributes

| Attribute            | Type | Description                    |
| -------------------- | ---- | ------------------------------ |
| `treefmt`            | set  | Treefmt program configurations |
| `buildInputs`        | list | Additional build dependencies  |
| `devShellInputs`     | list | Additional dev shell packages  |
| `extraPackages`      | set  | Additional runnable packages   |
| `extraRuntimeChecks` | set  | Additional runtime checks      |

### Example Configuration

```nix
dev-flake.lib.mkRustProject {
  inherit self;
  msrv = { name = "1.85.1"; sha256 = "sha256-..."; };

  treefmt = {
    rustfmt.enable = true;
    nixfmt.enable = true;
    deno.enable = true;
  };

  devShellInputs = [ pkgs.rust-analyzer ];
};
```

## Commands

### General Project Management

| Command           | Description              |
| ----------------- | ------------------------ |
| `nix flake check` | Run all project checks   |
| `nix fmt`         | Format all project files |

### Project Checks

| Command                       | Description                     |
| ----------------------------- | ------------------------------- |
| `nix build .#check-clippy`    | Run Rust clippy checks          |
| `nix build .#check-tests`     | Run tests (no default features) |
| `nix build .#check-tests-all` | Run tests with all features     |
| `nix build .#check-doc`       | Build documentation             |
| `nix build .#check-doc-tests` | Run doc tests                   |
| `nix build .#check-fmt`       | Check formatting                |

### Runtime Operations

| Command                         | Description                          |
| ------------------------------- | ------------------------------------ |
| `nix run .#benchmarks`          | Run project benchmarks               |
| `nix run .#runtime-checks`      | Run all runtime checks               |
| `nix run .#check-semver`        | Check semantic version compatibility |
| `nix run .#check-cargo-publish` | Dry-run cargo publish                |

### Development Environments

| Command                 | Description                       |
| ----------------------- | --------------------------------- |
| `nix develop`           | Enter dev shell with stable Rust  |
| `nix develop .#nightly` | Enter dev shell with nightly Rust |

## Git Hooks

The flake includes automated git hooks:

```bash
nix run .#git-install-hooks
```

This installs hooks that:

- Format code on pre-commit
- Run all project checks on pre-push

## License

This project is licensed under MIT License - see the [LICENSE](LICENSE) file for
details.
