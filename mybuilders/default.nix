{pkgs, lib}:

let
  linkers = pkgs.callPackage ./linkers.nix {};
  transformers = pkgs.callPackage ./transformers.nix {};

  # note: not using `callPackage` here to have a cleaner final value:
  #   a plain function instead of a functor attrset with override support.
  directSymlinker = import ./editable-symlinker.nix {
    inherit lib;
    inherit (pkgs) runCommandLocal;
  };
in {
  inherit (linkers) linkBins linkSingleBin;
  inherit (transformers) replaceBinsInPkg;
  # also expose the nested modules, 'cause why not!
  inherit linkers transformers;

  inherit directSymlinker;
}
