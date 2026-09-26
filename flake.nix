{
  description = "A very basic flake";

  inputs = {
    nixpkgs-lib.url = "github:nix-community/nixpkgs.lib";
  };

  outputs = inputs: {
    mkModule = import ./src/mkModule.nix {
      inherit inputs;
      lib = inputs.nixpkgs-lib.lib;
    };
  };
}
