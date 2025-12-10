{ lib }:

{
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
}
