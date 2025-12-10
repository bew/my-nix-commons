{ lib }:

rec {
  # TODO: doc!
  newKit = (
    kitdefModule: let
      kitdefEvaluated = lib.evalModules {
        class = "kitdef";
        modules = [
          ./kitdef-modules
          kitdefModule
        ];
      };
    in kitdefEvaluated.config
  );

  # TODO: doc!
  newToolkit = (
    toolkitDefModule:
    newKit {
      imports = [ toolkitDefModule ];
      _evalConfig.baseModules = [ ../../modules/kit/toolkit-base.nix ];
    }
  );
}
