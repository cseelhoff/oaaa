{
  description = "oaaa Odin development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
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
