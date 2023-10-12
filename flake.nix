{
  description = "docker-compizo";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    let
      rev = self.shortRev or "dirty";

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
        docker-compizo = pkgs.callPackage ./nix/pkgs/docker-compizo.nix { inherit rev; };
      in
      {
        devShells.default = with pkgs; mkShell {
          buildInputs = [ elixir docker-client ];
        };

        packages.default = docker-compizo;
        packages.docker-compizo = docker-compizo;
      }
    )) // {
      overlays.default = final: prev: {
        docker-compizo = prev.callPackage ./nix/pkgs/docker-compizo.nix { inherit rev; };
      };
    };
}
