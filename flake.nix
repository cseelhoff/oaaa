{
  description = "Odin development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    odin-src = {
      url = "github:odin-lang/Odin";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, odin-src }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        odin-dev = pkgs.odin.overrideAttrs (old: {
          version = "dev-2026-04";
          src = odin-src;
          patches = [];
        });
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = [
            odin-dev
          ];

          nativeBuildInputs = with pkgs; [
            git
            which
            clang
            llvmPackages.llvm
            llvmPackages.bintools
            odin-dev
            lldb
          ];

          shellHook = ''
            export CXX=clang++
            export CC=clang
          '';
        };
      }
    );
}
