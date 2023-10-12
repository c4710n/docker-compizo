{ lib
, beamPackages
, elixir
, makeWrapper
, erlang
, docker-client
, ...
}:
beamPackages.mixRelease rec {
  pname = "docker-compizo";
  version = "0.1.0";

  inherit elixir;

  nativeBuildInputs = [ makeWrapper ];

  src = ../..;

  mixFodDeps = beamPackages.fetchMixDeps {
    pname = "mix-deps-${pname}";
    inherit src version;
    hash = "sha256-nPIs7ChGpUFW46Lqcpgb7RHzRWqVJb12XYAGcmFPl70=";
  };

  installPhase = ''
    mix escript.build
    install -Dm755 -t $out/bin escripts/docker-compizo

    wrapProgram $out/bin/docker-compizo \
      --prefix PATH : ${lib.makeBinPath [ erlang docker-client ]}
  '';

  meta = with lib; {
    license = licenses.mit;
    homepage = "https://github.com/c4710n/docker-compizo";
    description = "Deploys a new version of Docker Compose service without downtime.";
    platforms = platforms.unix;
  };
}
