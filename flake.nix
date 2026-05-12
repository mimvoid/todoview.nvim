{
  description = "Flake for todoview.nvim";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    { self, nixpkgs }:
    let
      allSystems = nixpkgs.lib.genAttrs nixpkgs.lib.platforms.all;
      toSystems = passPkgs: allSystems (system: passPkgs (import nixpkgs { inherit system; }));
    in
    {
      devShells = toSystems (pkgs: {
        default = pkgs.mkShell {
          name = "todoview.nvim";
          packages = [ pkgs.emmylua-ls ];
        };
      });
    };
}
