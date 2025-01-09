{ pkgs ? import <nixpkgs> {} }:
pkgs.mkShell {
  buildInputs = [
    pkgs.odin
  ];
  name = "odin";
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
}