{ lib, ... }:

{
  meta.name = "Nvim tool kit";
  meta.maintainers = [ lib.maintainers.bew ];

  _evalConfig = {
    class = "test-kit";
    baseModules = [ ./base.nix ];
  };
}
