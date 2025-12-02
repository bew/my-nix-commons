{
  lib,

  runCommandLocal,
}:

# TODO: write tests!

{
  # Creates a derivation with only links to the given binaries.
  # The binaries to include are described by a spec, see the examples below.
  #
  # Can be used:
  # * to rename binaries
  # * to rename binaries to allow multiple version of the same software
  #   in the same environment
  # * to expose only a few binaries of a derivation
  #
  # NOTE: Using linkBins, the packages used to define the new binaries can't install their normal
  # outputs, thus 'man' output is never available... Similarly shell completions, icons, libs,
  # includes, configs are not included.
  # This builder is ONLY useful to make binaries available.
  # => Use `replaceBinsInPkg` to replace bins in an existing package while keeping its structure.
  #
  # Types:
  #   linkBins :: { name :: String; ... } -> derivation
  #   linkBins :: [ String or { name :: String; path :: String; } ] -> derivation
  #
  # Examples:
  #   (linkBins "my-bins1" [
  #     pkgs.neovim
  #     "/tmp/foo/bar"
  #   ])
  #   => creates a derivation like:
  #     /nix/store/znk3qkb30ccgq6kvgmv69jj4ci9bin18-my-bins1/
  #     └── bin/
  #         ├── nvim -> /nix/store/frlxim9yz5qx34ap3iaf55caawgdqkip-neovim-0.5.1/bin/nvim
  #         └── bar -> /tmp/foo/bar
  #
  #   (linkBins "my-bins2" [
  #     {name = "nvim-stable"; path = pkgs.neovim;}
  #     "/tmp/foo/bar"
  #   ])
  #   => creates a derivation like:
  #     /nix/store/f35182nny6lb95srh0lbxfd5hq99kr8s-my-bins2/
  #     └── bin/
  #         ├── nvim-stable -> /nix/store/frlxim9yz5qx34ap3iaf55caawgdqkip-neovim-0.5.1/bin/nvim
  #         └── bar -> /tmp/foo/bar
  #
  #   (linkBins "my-bins3" {
  #     nvim-stable = pkgs.neovim;
  #     bar-tmp = "/tmp/foo/bar";
  #   })
  #   => creates a derivation like:
  #     /nix/store/3v6mk91b4n4758zli921y2z27xm3a5v2-my-bins3/
  #     └── bin/
  #         ├── nvim-stable -> /nix/store/frlxim9yz5qx34ap3iaf55caawgdqkip-neovim-0.5.1/bin/nvim
  #         └── bar-tmp -> /tmp/foo/bar
  #
  # TODO: allow to pass `mainProgram = true;` in a spec
  # => set a bin as the `meta.mainProgram` of the resulting drv
  linkBins = name: binsSpec:
    let
      binSpecHelp = ''
        a binSpec can be either:
        - a string: "/path/to/foo"
        - a set pointing to a string: { name = "foo"; path = "/path/to/foo"; }
        - a derivation: pkgs.neovim
        - a set pointing to a derivation: { name = "nvim-custom"; path = pkgs.neovim; }
      '';
      binsSpecHelp = ''
        binsSpec argument can be either:
        - a list of binSpec: (see below)
        - a set: { foo = "/path/to/foo"; }

        ${binSpecHelp}
      '';

      typeOf = builtins.typeOf;
      binsSpecList =
        if (typeOf binsSpec) == "list" then binsSpec
        else if (typeOf binsSpec) == "set" then
          lib.mapAttrsToList (name: path: { inherit name path; }) binsSpec
        else
          throw ''
            For linkBins: Unable to normalize given binsSpec argument of type '${typeOf binsSpec}'
            ${binsSpecHelp}
          '';
      normalizedBinsSpec = lib.forEach binsSpecList (item:
        if (typeOf item) == "string" then
          { name = baseNameOf item; path = item; }
        else if (typeOf item) == "set" && (item ? "name") && (item ? "path") then
          let binTarget = item.path; in {
            inherit (item) name;
            path = (
              if (typeOf binTarget) == "string" then
                binTarget
              else if (typeOf binTarget) == "set" && (binTarget ? outPath) then
                lib.getExe binTarget
              else
                throw ''
                  For linkBins: Unable to find target bin path '${name}' of type '${typeOf binTarget}'
                  ${binsSpecHelp}
                ''
            );
          }
        else
          throw ''
            For linkBins: Unable to normalize bin spec of type '${typeOf item}'
            ${binSpecHelp}
          ''
      );
    in runCommandLocal name {} ''
      mkdir -p $out/bin
      cd $out/bin
      ${lib.concatMapStrings ({name, path}: ''
        ln -s ${lib.escapeShellArg path} ${lib.escapeShellArg name}
      '') normalizedBinsSpec}
    '';

  # Creates a derivation with a single link in bin/ to the given binary path.
  #
  # Type: linkSingleBin :: String -> derivation
  #
  # Example:
  #   linkSingleBin "${pkgs.neovim}/bin/nvim"
  #   => creates a derivation like:
  #     /nix/store/yv5aigjy8l9bi9kpqh7y1dzf6nv07cl0-nvim-single-bin/
  #     └── bin/
  #         └── nvim -> /nix/store/frlxim9yz5qx34ap3iaf55caawgdqkip-neovim-0.5.1/bin/nvim
  #
  linkSingleBin = path:
    let
      binName = baseNameOf path;
      meta.mainProgram = binName;
    in runCommandLocal "${binName}-single-bin" { inherit meta; } ''
      mkdir -p $out/bin
      ln -s ${lib.escapeShellArg path} $out/bin/
    '';
}
