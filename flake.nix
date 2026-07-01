{
  description = "NixOS packaging for the Devin (Cognition) desktop app — stable + next";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      # allowUnfree: Devin's binary is proprietary/license-gated.
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      mkDevin = import ./package.nix { inherit pkgs; };
      # version + url + sha256 per channel, kept in sources.json so the
      # update workflow can rewrite them with jq (see .github/workflows).
      sources = builtins.fromJSON (builtins.readFile ./sources.json);
    in
    {
      packages.${system} = rec {
        devin = mkDevin {
          pname = "devin-desktop";
          inherit (sources.stable) version url sha256;
          desktopName = "Devin";
          exe = "devin-desktop";
        };

        devin-next = mkDevin {
          pname = "devin-desktop-next";
          inherit (sources.next) version url sha256;
          desktopName = "Devin - Next";
          exe = "devin-desktop-next";
          iconFile = "code-next.png";
          urlScheme = "devin-next";
        };

        default = devin;
      };

      # `nix run .#devin[-next]` opens the GUI; the agent is `bin/devin`.
      apps.${system} = rec {
        devin = {
          type = "app";
          program = "${self.packages.${system}.devin}/bin/devin-desktop";
        };
        devin-next = {
          type = "app";
          program = "${self.packages.${system}.devin-next}/bin/devin-desktop-next";
        };
        default = devin;
      };

      # Import as: imports = [ devin-nix.nixosModules.default ];
      # then: programs.devin.enable = true;  (and/or programs.devin.enableNext)
      nixosModules.default = import ./module.nix self;
    };
}
