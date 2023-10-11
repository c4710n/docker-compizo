{
  description = "docker-compizo";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    let
      overlayBeam = _final: prev: {
        beam = prev.beam // {
          interpreters = prev.beam.interpreters // {
            erlang_26 = prev.beam.interpreters.erlang_26.overrideAttrs (_finalAttrs: prevAttrs: {
              configureFlags = prevAttrs.configureFlags ++ [ "--disable-jit" ];
            });

            erlang_25 = prev.beam.interpreters.erlang_25.overrideAttrs (_finalAttrs: prevAttrs: {
              configureFlags = prevAttrs.configureFlags ++ [ "--disable-jit" ];
            });
          };
        };
      };
    in
    (flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          system = system;
          overlays = if system == "aarch64-darwin" then [ overlayBeam ] else [ ];
        };
      in
      {
        devShells.default = with pkgs; mkShell {
          buildInputs = [ elixir docker-client ];
        };
      }
    ));
}
