{
  description = "Symfony demo";

  inputs.nixpkgs.url = "nixpkgs/nixpkgs-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = inputs: inputs.flake-utils.lib.eachDefaultSystem (system: let
    name = "symfony-demo";
    port = "8000"; # Must be a string

    pkgs = import inputs.nixpkgs {
      inherit system;
    };

    revision = "${inputs.self.lastModifiedDate}-${inputs.self.shortRev or "dirty"}";

    phpProject =
      pkgs.callPackage ./composer-project.nix {
        php = pkgs.php81;
      }
      inputs.self;

    symfony-demo = pkgs.writeShellApplication {
      name = "symfony-demo";
      text = ''
        MKTEMP=$(mktemp -u)
        TMPDIR=$(dirname "$MKTEMP")
        APP_CACHE_DIR=$TMPDIR/${name}
        APP_LOG_DIR=$APP_CACHE_DIR/log
        export TMPDIR
        export APP_CACHE_DIR
        export APP_LOG_DIR

        ${pkgs.symfony-cli}/bin/symfony serve --port ${port} --document-root ${phpProject}/libexec/source/public --allow-http
      '';
      runtimeInputs = [pkgs.mktemp];
    };
  in {
    formatter = pkgs.alejandra;

    # Nix run
    apps.default = inputs.flake-utils.lib.mkApp {drv = symfony-demo;};

    # Nix build
    packages = {
      oci = pkgs.dockerTools.buildLayeredImage {
        name = "symfony/demo";
        tag = revision;
        contents = [
          symfony-demo
        ];
        config = {
          Cmd = ["${symfony-demo}/bin/symfony-demo"];
          ExposedPorts = {
            "${port}/tcp" = {};
          };
        };
      };
    };
  });
}
