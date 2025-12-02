{
  lib,

  buildEnv,
}:

{
  # Copy full package, remove existing bin/ and replace with the given list of bins.
  #
  # This is useful to patch some binaries / force them to use some
  # configuration, while preserving the pkg layout, allowing `man tool` to
  # auto-find the manpage of the tool when it's installed in home.packages!
  #
  # Example:
  #   replaceBinsInPkg {
  #     name = "custom-fzf";
  #     copyFromPkg = fzf;
  #     bins = {
  #       fzf = writeShellScript "fzf" ''
  #         exec ${fzf}/bin/fzf --custom-args right here --and=here "$@"
  #       '';
  #     };
  #     postBuild = "
  #   }
  #   => creates a derivation like:
  #     /nix/store/xx3yknpx0yvnks0dqvsd11n7p1zm5mb4-custom-fzf
  #     ├── bin
  #     │   └── fzf
  #     └── share
  #         ├── fish -> /nix/store/3fz694nbl7ndyinz7xmhz77inzn0a17h-fzf-0.35.1/share/fish
  #         ├── fzf -> /nix/store/3fz694nbl7ndyinz7xmhz77inzn0a17h-fzf-0.35.1/share/fzf
  #         ├── man -> /nix/store/5fl47ah7k40j6pk0ln74wf3kby2h8jp1-fzf-0.35.1-man/share/man
  #         └── vim-plugins -> /nix/store/3fz694nbl7ndyinz7xmhz77inzn0a17h-fzf-0.35.1/share/vim-plugins
  #
  #   replaceBinsInPkg {
  #     name = "custom-zsh";
  #     copyFromPkg = zsh;
  #     nativeBuildInputs = [ makeWrapper ];
  #     postBuild = /* sh */ ''
  #       makeWrapper ${zsh}/bin/zsh $out/bin/zsh --set ZDOTDIR /some/new/zdotdir
  #     '';
  #   };
  #   => creates a derivation like:
  #     /nix/store/p85wi35yda68xw9xr2s1lamgv4hqh1jl-custom-zsh
  #     ├── bin
  #     │   └── zsh
  #     ├── etc -> /nix/store/dy11j8bd6a6gq0nsgx54zddg32qrcd7l-zsh-5.8.1/etc
  #     ├── lib -> /nix/store/dy11j8bd6a6gq0nsgx54zddg32qrcd7l-zsh-5.8.1/lib
  #     └── share -> /nix/store/dy11j8bd6a6gq0nsgx54zddg32qrcd7l-zsh-5.8.1/share
  #
  replaceBinsInPkg = { name, copyFromPkg, bins ? {}, nativeBuildInputs ? [], postBuild ? "", meta ? {} }:
    buildEnv {
      inherit name nativeBuildInputs meta;
      paths = [ copyFromPkg ];
      postBuild = /* sh */ ''
        if [[ -e $out/bin ]]; then
          echo "Remove existing bin/ (was: `readlink $out/bin`)"
          # No need for '-r', it's a symlink!
          rm -f $out/bin
        fi
        echo "Create empty bin/"
        mkdir $out/bin

        ${lib.optionalString (0 != (lib.length (lib.attrNames bins))) ''
          echo "Add binaries: ${lib.concatStringsSep ", " (lib.attrNames bins)}"
          ${lib.concatStringsSep "\n"
            (lib.mapAttrsToList
              (name: targetBin: "cp ${toString targetBin} $out/bin/${name}")
              bins
            )
          }
        ''}

        ${lib.optionalString (0 != (lib.stringLength postBuild)) ''
          echo "Run postBuild to add more binaries"
          ${postBuild}
        ''}
      '';
    };
}
