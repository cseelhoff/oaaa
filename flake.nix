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
            clang
            llvmPackages.llvm  # Match the LLVM version with clang_18
            llvmPackages.bintools  # Match bintools version
            odin  # Already included in buildInputs, no need to repeat unless required
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
