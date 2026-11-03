{
  description = "gudev — Ruby bindings";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
    mine.url = "github:n-at-han-k/flake.nix";
    mine.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs = { self, mine, nixpkgs, utils }:
    utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        lib = mine.lib.${system};

        gemspecFiles = pkgs.runCommand "gudev-gemspec" { } ''
          mkdir -p $out/lib/gudev
          cp ${./gudev.gemspec}         $out/gudev.gemspec
          cp ${./lib/gudev/version.rb}  $out/lib/gudev/version.rb
        '';

        gems = pkgs.bundlerEnv {
          name = "gudev-gems";
          ruby = pkgs.ruby_3_4;
          gemfile = ./Gemfile;
          lockfile = ./Gemfile.lock;
          gemset = import ./gemset.nix;
          extraConfigPaths = [ "${gemspecFiles}/." ];
        };

        # The namespaces the loader needs at require time: GUdev itself, and
        # GObject/GLib, which GUdev-1.0.typelib names as its one dependency and
        # the loader resolves transitively.
        #
        # `makeSearchPath` would take each package's *first* output, and glib's
        # first output is `bin`, which carries no typelibs -- hence the explicit
        # `.out`. This is the trap the port scaffold documents, and it cost real
        # time before it was written down.
        typelibPath = pkgs.lib.makeSearchPath "lib/girepository-1.0"
          (map (drv: drv.out or drv) [ pkgs.libgudev pkgs.glib ]);
      in
      {
        devShells.default = lib.mkRubyShell {
          buildInputs = with pkgs; [
            gems
            gems.wrappedRuby

            # libgudev itself, for its typelib. Nothing compiles against it
            # any more -- there is no extension here and no pkg-config lookup,
            # so rustc, cargo, clang, pkg-config, glib and udev all came out of
            # this list with the crate. What is left is in scope for
            # GUdev-1.0.typelib and the shared library the typelib names.
            #
            # Taking it from the same nixpkgs as the gobject-introspection gem
            # is not a tidiness point: a typelib built against a different glib
            # registers GObject a second time in the process and dies with
            #   cannot register existing type
            libgudev

            skywalking-eyes
          ];

          shellHook = /* bash */ ''
            # GUdev-1.0.typelib, plus the typelib it depends on. GUdev-1.0
            # declares GObject-2.0, and the loader resolves that transitively at
            # require time, so glib's girepository directory (GLib-2.0,
            # GObject-2.0, Gio-2.0) has to be here too or the load fails with
            # "Typelib file for namespace 'GObject' not found".
            export GI_TYPELIB_PATH="${typelibPath}''${GI_TYPELIB_PATH:+:$GI_TYPELIB_PATH}"

            export BUNDLE_GEMFILE="$PWD/Gemfile"
            export BUNDLE_FROZEN=false

            export LANG="''${LANG:-C.UTF-8}"
            export LC_ALL="''${LC_ALL:-$LANG}"

            export RUBYLIB="$PWD/lib''${RUBYLIB:+:$RUBYLIB}"
          '';
        };
      }
    );
}
