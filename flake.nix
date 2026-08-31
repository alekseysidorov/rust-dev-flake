{
  inputs = {
    # Nix
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    flake-parts.url = "github:hercules-ci/flake-parts";

    # Build
    crane.url = "github:ipetkov/crane";

    # Development
    treefmt-nix.url = "github:numtide/treefmt-nix";
    rust-advisory-db = {
      url = "github:rustsec/advisory-db";
      flake = false;
    };
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      # Declared systems that your flake supports. These will be enumerated in perSystem
      systems = inputs.nixpkgs.lib.systems.flakeExposed;
      imports = [ ./flake-modules/git-hooks.nix ];

      # Let other flakes reuse helpers, packages and hook configuration independently.
      flake = {
        lib = import ./lib { inherit inputs; };
        overlays.default = import ./overlay.nix { inherit inputs; };
        flakeModules.gitHooks = ./flake-modules/git-hooks.nix;
      };

      perSystem =
        {
          config,
          pkgs,
          system,
          ...
        }:
        let
          treefmt = (inputs.treefmt-nix.lib.evalModule pkgs) {
            projectRootFile = "flake.nix";
            programs = {
              nixfmt.enable = true;
              deno.enable = true;
            };
          };
        in
        {
          # Use our overlay consistently in packages, checks and development tools.
          _module.args.pkgs = import inputs.nixpkgs {
            inherit system;
            overlays = [ inputs.self.overlays.default ];
          };

          # Expose tools through `nix build` and `nix run`.
          packages = {
            inherit (pkgs) diplomat-tool;
          };

          # Apply repository formatting with `nix fmt`.
          formatter = treefmt.config.build.wrapper;

          # Verify formatting and package builds with `nix flake check`.
          checks = {
            formatter = treefmt.config.build.check inputs.self;
            diplomat-tool = config.packages.diplomat-tool;
          };

          # Install explicitly with `nix run .#install-git-hooks`.
          gitHooks = {
            pre-commit = pkgs.writeNuShellScript "pre-commit" ''
              print "⚡️ Running pre-commit checks..."
              nix build .#checks.${system}.formatter -L
            '';

            pre-push = pkgs.writeNuShellScript "pre-push" ''
              print "⚡️ Running pre-push checks..."
              nix flake check -L
            '';
          };
        };
    };
}
