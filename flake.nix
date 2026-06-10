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
    in
    {
      packages.${system} = rec {
        devin = mkDevin {
          pname = "devin";
          version = "3.0.28";
          desktopName = "Devin";
          url = "https://windsurf-stable.codeiumdata.com/linux-x64/stable/e9f7e622f49ec544e97d0e624691d71a963ac40b/Devin-linux-x64-3.0.28.tar.gz";
          sha256 = "sha256-5U4eb9ztXWz6VRNuVT7pr0BcigSLKoUz5Bo5oL4Owdo=";
          exe = "devin-desktop";
        };

        devin-next = mkDevin {
          pname = "devin-next";
          version = "3.1.1005+next.296eca6010";
          desktopName = "Devin Next";
          url = "https://windsurf-stable.codeiumdata.com/linux-x64/next/296eca60105473c0cd97c73679ac395c1d23a155/Devin-linux-x64-3.1.1005+next.296eca6010.tar.gz";
          sha256 = "sha256-aOzum13UNvLLrPPIIX9k+ObKjS+Z/PAThfBBQ0EEc28=";
          exe = "devin-desktop-next";
          iconFile = "code-next.png";
          urlScheme = "devin-next";
        };

        default = devin;
      };

      apps.${system} = rec {
        devin = {
          type = "app";
          program = "${self.packages.${system}.devin}/bin/devin";
        };
        devin-next = {
          type = "app";
          program = "${self.packages.${system}.devin-next}/bin/devin-next";
        };
        default = devin;
      };
    };
}
