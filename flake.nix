{
  description = "CHANGEME";

  nixConfig = {
    extra-substituters = [ "https://pr0d1r2.cachix.org" ];
    extra-trusted-public-keys = [ "pr0d1r2.cachix.org-1:NfWjbhgAj41byXhCKiaE+av3Vnphm1fTezHXEGsiQIM=" ];
  };

  inputs = {
    nixpkgs-lock.url = "github:pr0d1r2/nixpkgs-lock";
    nixpkgs.follows = "nixpkgs-lock/nixpkgs";

    set-and-setting.url = "github:pr0d1r2/set-and-setting";
    set-and-setting.inputs.nixpkgs-lock.follows = "nixpkgs-lock";
  };

  outputs =
    {
      self,
      nixpkgs,
      set-and-setting,
      ...
    }:
    (set-and-setting.lib.mkConsumerFlake {
      inherit self nixpkgs set-and-setting;
      fragments = [
        "base"
        "nix"
        "shell"
        "ascii"
        "markdown"
        "yaml"
      ];
      src = ./.;
    })
    // {
      packages =
        let
          scaffold = set-and-setting.lib.mkConsumerFlake {
            inherit self nixpkgs set-and-setting;
            fragments = [
              "base"
              "nix"
              "shell"
              "ascii"
              "markdown"
              "yaml"
            ];
            src = ./.;
          };
          systems = [
            "aarch64-darwin"
            "x86_64-darwin"
            "x86_64-linux"
            "aarch64-linux"
          ];
        in
        scaffold.packages
        // (nixpkgs.lib.genAttrs systems (
          system:
          scaffold.packages.${system}
          // {
            default = nixpkgs.legacyPackages.${system}.writeShellApplication {
              name = "lefthook-tcl-syntax";
              runtimeInputs = [ nixpkgs.legacyPackages.${system}.tcl ];
              text = builtins.readFile ./lefthook-tcl-syntax.sh;
            };
          }
        ));
    };
}
