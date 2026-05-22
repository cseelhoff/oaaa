{
  description = "oaaa Odin development environment";

  inputs = {
    # Pinned to a nixos-unstable rev with odin dev-2026-05 (supports [dynamic; N]T).
    nixpkgs.url = "github:NixOS/nixpkgs/d233902339c02a9c334e7e593de68855ad26c4cb";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        devShells.default = pkgs.mkShell {
          name = "odin";
          buildInputs = [
            pkgs.odin
          ];
          nativeBuildInputs = with pkgs; [
            git
            which
            llvmPackages.clang
            llvmPackages.llvm
            llvmPackages.bintools
            odin
            lldb
          ];
          shellHook = ''
            export CXX=clang++
            export CC=clang
          '';
        };
      });
}
