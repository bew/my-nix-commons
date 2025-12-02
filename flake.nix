{
  description = "bew's (public) commons";

  inputs = {
    # NOTE: ideally this would _only_ have lib + kinda-framework packages, skipping every other
    #   ~leaf packages... But this doesn't exist AFAIK... (project idea?? 👀)
    nixpkgsBase.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    systems.url = "github:nix-systems/default";
  };

  outputs = {self, nixpkgsBase, systems}: let
    lib = nixpkgsBase.lib;
    eachSystem = lib.genAttrs (import systems);
    forSys = system: {
      pkgs = nixpkgsBase.legacyPackages.${system};
    };
  in {
    mylib = import ./mylib { inherit lib; };
    mybuilders = eachSystem (
      system:
      (forSys system).pkgs.callPackage ./mybuilders {}
    );

    # --- Modules, by kind of module systems

    modules.generic = {
      dyndots = import ./modules/generic/dyndots.nix;
    };

    modules.kit = {
      editable = import ./modules/kit/editable.nix;
      toolkit-base = import ./modules/kit/toolkit-base.nix;
    };
  };
}
