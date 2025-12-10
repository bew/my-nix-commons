{config, lib, ...}:
let
  ty = lib.types;
  commonModules = config.commonModules;
  # This is necessary to avoid mixing kit' lib vs kit eval' lib when accessing `config.lib`
  kitlib = config.lib;
in {
  _class = "kitdef";

  options = {
    eval = lib.mkOption {
      description = "Function used to returning the output of the Kit module system";
      type = ty.raw;
      # default is defined below
    };
    _evalConfig = lib.mkOption {
      description = "Configuration that the `eval` function can use";
      type = ty.submodule {
        options = {
          class = lib.mkOption {
            description = "Class name for this Kit' modules";
            type = ty.nullOr ty.str;
            default = null;
          };
          baseModules = lib.mkOption {
            description = "List of base modules to be used for this Kit module system";
            type = ty.listOf ty.raw;
            default = [];
          };
          specialArgs = lib.mkOption {
            description = "Special args for this Kit module system";
            type = ty.attrsOf ty.raw;
            default = {};
          };
        };
      };
      default = {};
    };
  };

  config = {
    # Define the default `eval` function for the Kit!
    eval = lib.mkDefault (
      config.lib.defineEval {
        class = config._evalConfig.class;
        kitBaseModules = config._evalConfig.baseModules;
        specialArgs = config._evalConfig.specialArgs;
      }
    );

    lib.defineEval = {
      # The current kit definition, can be used to access extra fields
      kitBaseModules,
      # Module class
      class ? null,
      # Special args passed to evalModules
      specialArgs ? {},
    }: (
      {
        pkgs,
        lib ? pkgs.lib,
        config,
        configOverride ? {},
        moreModules ? [],
        ...
      }:
      let
        evaluated = lib.evalModules {
          inherit class;
          specialArgs = { inherit pkgs; } // specialArgs;
          modules = (
            [
              commonModules.declareConfigExtender
              # NOTE: we just try to _always_ declare these options
              commonModules.declareLibOption
              commonModules.declareAssertWarnOptions
            ]
            ++ kitBaseModules
            ++ [ config configOverride ]
            ++ moreModules
            ++ [
              # Initialize the state with the current eval, using option-default priority to ensure
              # all _kitState options have the same priority.
              { _kitState.currentEval = lib.mkOptionDefault evaluated; }
            ]
          );
        };
      in kitlib.checkAssertsAndWarningsInConfig evaluated.config
    );
  };
}
