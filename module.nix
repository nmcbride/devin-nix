# NixOS module exposing `programs.devin`. Imported via
# devin-nix.nixosModules.default. Takes the flake `self` so it can install
# the prebuilt packages (already evaluated with allowUnfree), meaning the
# importing system needs no unfree config of its own.
self:
{ config, lib, pkgs, ... }:

let
  cfg = config.programs.devin;
in
{
  options.programs.devin = {
    enable = lib.mkEnableOption "Devin Desktop (AI coding IDE)";
    enableNext = lib.mkEnableOption "Devin Desktop, next (prerelease) channel";
  };

  # Each package provides the GUI launcher (devin-desktop[-next]) plus the
  # `devin` terminal agent (with node/uv/python3 bundled). So the local agent
  # works the same in a terminal as in the IDE, with no ~/.local/bin install
  # and no global toolchain pollution. Skip the app's own "install CLI" prompt.
  config = lib.mkIf (cfg.enable || cfg.enableNext) {
    environment.systemPackages =
      lib.optional cfg.enable self.packages.${pkgs.stdenv.hostPlatform.system}.devin
      ++ lib.optional cfg.enableNext self.packages.${pkgs.stdenv.hostPlatform.system}.devin-next;
  };
}
