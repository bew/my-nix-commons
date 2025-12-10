let
  pkgs = builtins.getFlake "pkgs";
  lib = pkgs.lib;
  ty = lib.types;

  kitsys-v2 = import ./. { inherit lib; };

  minikit = kitsys-v2.newKit ./test-kit/kit.nix;
  minikitExtended = kitsys-v2.newKit {
    imports = [ ./test-kit/kit.nix ];
    # the following will be merged with the base spec!
    _evalConfig.baseModules = [
      ({lib, ...}: {
        options.otherVal = lib.mkOption {
          description = "Option in extra base module, separate from original kit definition";
          type = ty.str;
        };
      })
    ];
  };

  configInit = minikit.eval {
    inherit pkgs;
    config = {
      val = "first-value";
    };
  };

  configNested = configInit.extendWith ({lib, ...}: {
    val = lib.mkForce "second-value, prev not used";
  });

  configNestedAgain = configNested.extendWith ({lib, prevConfig, ...}: {
    val = lib.mkOverride 45 "third-value (was ${prevConfig.val})";
    # note: mkForce has priority 50, 45 has more priority
  });

  configWithWarn = configNestedAgain.extendWith ({lib, ...}: {
    warnings = [ "test warning is working" ];
  });

  configFromExtendedKit = minikitExtended.eval {
    inherit pkgs;
    config = {
      val = "some-value";
      otherVal = "some-other-value";
    };
  };

  # NOTE: useful in repl!
  debugs = {
    inherit pkgs minikit;
    # note: as separate entries, to comment them easily when debugging some eval stuff
    inherit configInit;
    inherit configNested;
    inherit configNestedAgain;
    inherit configWithWarn;
    inherit configFromExtendedKit;
  };

  # NOTE: Test names _must_ start with `test` to be considered by `runTests`.
  # (note: numbers in test name are used to ensure test ordering)
  tests = {
    # Test value propagation across config extensions
    "test.0.initial" = {
      expr = configInit.val;
      expected = "first-value";
    };
    "test.1.nested" = {
      expr = configNested.val;
      expected = "second-value, prev not used";
    };
    "test.2.doubly-nested" = {
      expr = configNestedAgain.val;
      expected = "third-value (was second-value, prev not used)";
    };
    # Test nesting level info in kit state
    "test.0.initial.level" = {
      expr = configInit._kitState.nestingLevel;
      expected = 0;
    };
    "test.1.nested.level" = {
      expr = configNested._kitState.nestingLevel;
      expected = 1;
    };
    "test.2.doubly-nested.level" = {
      expr = configNestedAgain._kitState.nestingLevel;
      expected = 2;
    };
    # Other tests
    "test.90.with-warning" = {
      expr = configWithWarn.warnings;
      # note: extensions are put before for list merges
      expected = [ "test warning is working" ];
    };
    "test.99.extended-kit" = {
      expr = configFromExtendedKit.otherVal;
      expected = "some-other-value";
    };
  };
  nicer_testResults = let
    testResults = pkgs.lib.runTests tests;
    fmtTestNames = lib.concatStringsSep ", " (builtins.attrNames tests);
  in (
    if testResults == []
    then "Tests successful ✨ (${fmtTestNames})"
    else testResults
  );

in nicer_testResults
# in debugs # for DEBUG in repl

# Run with `nix eval -f $CURRENTFILE`
# Add `--json | jq .` for better readability of test result failures
