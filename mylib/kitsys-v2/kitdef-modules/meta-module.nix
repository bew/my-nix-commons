{ lib, ... }:
let
  ty = lib.types;
in
{
  _class = "kitdef";
  options = {
    meta.name = lib.mkOption {
      description = "Name for this Kit";
      type = ty.str;
      # required!
    };
    meta.description = lib.mkOption {
      description = "Description for this Kit";
      type = ty.str;
      default = "";
    };
    meta.maintainers = lib.mkOption {
      description = "List of maintainers for this Kit";
      type = ty.listOf ty.raw;
      default = [];
    };
  };
}
