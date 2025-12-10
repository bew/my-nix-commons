{ lib }:

{
  kitsys-v1 = import ./kitsys-v1 { inherit lib; };
  kitsys-v2 = import ./kitsys-v2 { inherit lib; };
}
