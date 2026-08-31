# rust-dev-flake

[![Nix Flake](https://img.shields.io/badge/Nix-Flake-blue.svg)](https://nixos.org/nix/flakes)
[![Rust](https://img.shields.io/badge/Rust-stable-orange.svg)](https://www.rust-lang.org)
[![MIT License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

A collection of Nix helpers to simplify Rust project maintenance and ensure
reproducible tooling — both locally and in CI.

## Source filtering

The default overlay provides `gitignoreSource`. It applies the root `.gitignore`
before selecting a relative subdirectory, preserving the meaning of its
patterns:

```nix
src = pkgs.gitignoreSource {
  projectRoot = ./.;
  src = "crates";
};
```

Omit `src` or use `""` to keep the whole filtered root. Nested `.gitignore`
files are not read.

## Git hooks

Inside `flake-parts.lib.mkFlake`:

```nix
{
  imports = [ inputs.rust-dev-flake.flakeModules.gitHooks ];

  perSystem = { pkgs, system, ... }: {
    gitHooks = {
      pre-commit = pkgs.writeShellScript "pre-commit" ''
        exec nix build .#checks.${system}.formatter -L
      '';
      pre-push = pkgs.writeShellScript "pre-push" ''
        exec nix flake check -L
      '';
    };
  };
}
```

Run `nix run .#install-git-hooks` to install the configured scripts. Hooks from
different modules are merged by name. An empty map creates no installer;
importing the module does not modify `.git`.

## Nushell scripts

The default overlay provides `writeNuShellScript name text`, which returns an
executable file with a Nushell shebang, suitable for Git hooks:

```nix
pkgs.writeNuShellScript "pre-push" ''
  print "Checking..."
  nix flake check -L
''
```

## Nushell applications

Inside `flake-parts.lib.mkFlake`:

```nix
{
  perSystem = { pkgs, system, ... }: {
    _module.args.pkgs = import inputs.nixpkgs {
      inherit system;
      overlays = [ inputs.rust-dev-flake.overlays.default ];
    };
    packages.demo = pkgs.writeNuShellApplication {
      name = "demo";
      script = ./tools/demo.nu;
      runtimeInputs = [ pkgs.hello ];
      env = { DEMO_VALUE = "0"; };
    };
  };
}
```

Create `tools/demo.nu`:

```nu
print $env.DEMO_VALUE
^hello
```

Run it with `nix run .#demo`.

## Packages

`diplomat-tool` is available through the default overlay and
`nix run .#diplomat-tool`. `nix flake check` builds it on the current system.

## Flake input layout

Group inputs by their role in the consuming project, in this order:

1. **Nix** — package sets and flake framework (`nixpkgs`, `flake-parts`).
2. **System configuration** — OS and user modules (`nix-darwin`,
   `home-manager`).
3. **Build** — toolchains and builders (`fenix`, `crane`).
4. **Development** — shared helpers, formatters and checks (`rust-dev-flake`,
   `treefmt-nix`).

Skip empty groups. Keep related inputs together and `follows` inside each input.
Group by purpose, not ownership or URL type. In `imports`, keep external modules
before local modules; preserve any order required by their behavior.

## License

MIT — see [LICENSE](LICENSE).
