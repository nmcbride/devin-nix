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

  config = lib.mkIf (cfg.enable || cfg.enableNext) {
    environment.systemPackages =
      lib.optional cfg.enable self.packages.${pkgs.stdenv.hostPlatform.system}.devin
      ++ lib.optional cfg.enableNext self.packages.${pkgs.stdenv.hostPlatform.system}.devin-next;

    # The in-app "install Devin CLI" prompt symlinks the (static) devin
    # binary into ~/.local/bin; ensure that is on PATH so it is callable.
    # NixOS-native, no home-manager assumption.
    environment.localBinInPath = true;
  };
}
