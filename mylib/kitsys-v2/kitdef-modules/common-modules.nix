{ config, lib, ... }:

let
  ty = lib.types;
  # This is necessary to avoid mixing kit' lib vs kit eval' lib when accessing `config.lib`
  kitlib = config.lib;

  declareLibOption = {lib, ...}: {
    options.lib = lib.mkOption {
      description = "Set of lib functions for this module system";
      type = ty.attrsOf (ty.uniq ty.raw);
      default = {};
    };
  };
in {
  imports = [declareLibOption];
  options.commonModules = lib.mkOption {
    type = ty.attrsOf ty.raw;
  };

  config = {
    lib.checkAssertsAndWarningsInConfig = config: (
      # Check assertions & warnings: (returns the evaluated config if all good)
      # - show all warnings
      # - fail with messages for all false asserts
      lib.asserts.checkAssertWarn
        config.assertions
        config.warnings
        config
    );

    # A module that declares the `lib` option
    commonModules.declareLibOption = declareLibOption;

    # Interesting related work, to follow:
    # - Reusable assertions (aka, integrate them in the module system)
    #   <https://github.com/NixOS/nixpkgs/pull/207187>
    # - Structured attrs for warnings/assertions
    #   <https://github.com/NixOS/nixpkgs/pull/342372>
    commonModules.declareAssertWarnOptions = {lib, ...}: {
      options.assertions = lib.mkOption {
        description = "List of assertions to check";
        type = ty.listOf (ty.submodule {
          options = {
            assertion = lib.mkOption {
              type = ty.bool;
              description = "Assertion condition that must be true";
            };
            message = lib.mkOption {
              type = ty.str;
              description = "Error message to display when assertion fails";
            };
          };
        });
        default = [];
      };

      options.warnings = lib.mkOption {
        description = "List of warning messages to display";
        type = ty.listOf ty.str;
        default = [];
      };
    };

    # A module defining the `config.extendWith` function for multi-level config extension ✨
    # 👉 Allows to take a full kit-based config and refine it later as needed.
    commonModules.declareConfigExtender = {lib, config, ...}: {
      options._kitState = {
        # Not strictly necessary, but can be useful information.
        nestingLevel = lib.mkOption {
          description = "Nesting level of the current kitsys eval, overridden with each config extension";
          type = ty.ints.unsigned;
          default = 0;
        };
        # NOTE: This is needed to be able to access current eval in the impl of `extendWith`
        currentEval = lib.mkOption {
          type = ty.raw; # zero smart, zero merging
          # note: initial value is set in `kit.eval` with the option-default's priority
        };
      };

      options.extendWith = lib.mkOption {
        description = "MAGIC config extender function, give it a module to get a new extended config!";
        type = ty.functionTo ty.raw;
      };

      # Extend current config with the given module.
      # Supports accessing `prevConfig` in module args if needed.
      config.extendWith = module: (
        let
          prev_kitState = config._kitState;
          prevEval = prev_kitState.currentEval;
          # NOTE: We need to set a higher priority (less is more) for options here, to make sure
          # that 2+ nesting evals won't have conflicting option definitions when overriding value.
          higherPrio = prevEval.options._kitState.nestingLevel.highestPrio - 1;

          evaluated = prevEval.extendModules {
            modules = [
              module
              {
                _kitState.nestingLevel = lib.mkOverride higherPrio (prev_kitState.nestingLevel + 1);
                # NOTE: Storing the eval in the config is necessary to be able to retrieve highestPrio of an
                # option in prevEval.
                #
                # note: Due to Nix's lazyness its value should never actually be evaluated until I actually
                # need a config value from a prev config
                _kitState.currentEval = lib.mkOverride higherPrio evaluated;

                # Expose the previous config if an extension module needs the before-extension value
                # of something.
                _module.args.prevConfig = lib.mkOverride higherPrio prevEval.config;
              }
            ];
          };
        in kitlib.checkAssertsAndWarningsInConfig evaluated.config
      );
    };
  };
}
