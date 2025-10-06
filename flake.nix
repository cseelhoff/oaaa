{
  description = "Odin development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = [
            pkgs.odin
          ];
          
          nativeBuildInputs = with pkgs; [
            git
            which
            clang_17
            llvmPackages_17.llvm
            llvmPackages_17.bintools
            odin
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
