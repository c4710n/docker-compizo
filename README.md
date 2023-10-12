# docker-compizo

![Nix flakes](https://img.shields.io/badge/Nix%20flakes-5277C3?logo=nixos&logoColor=white&style=flat-square)

Deploys a new version of Docker Compose service without downtime.

> This project is an Elixir port of [docker-rollout](https://github.com/Wowu/docker-rollout) with minor improvements.

## Requirements

- Elixir 1.14 or later
- Docker with `docker compose` support.

## Usage

```bash
$ docker-compizo -f compose.yaml <service>
```

See `docker-compizo --help` and examples in [examples](examples) directory for more usage.

### Limits

- A proxy is required to route traffic. [Traefik](https://github.com/traefik/traefik) is recommended.
- Services scaled by `docker-compizo` cannot have `container_name` and `ports` defined in `compose.yaml`, as it's not possible to run multiple containers with the same name or port mapping.
- Each deployment will increase the index of container names. For example, `project-service-1` will be `project-service-2`.

### Guidelines

- It's better to provide healthcheck to containers. In conjunction with healthchecks, it is easier to only route traffic to the new containers when they're ready.

## How it works?

`docker-compizo` achieves zero downtime deployment by a simple blue/green strategy:

1. scaling the service for more containers
2. waiting for the new containers to be ready
3. removing the old containers

## Why?

Using container orchestration tools like [Kubernetes](https://kubernetes.io/), [Nomad](https://www.nomadproject.io/) or vice versa is usually an overkill for most projects.

I prefer the simple solution - Docker Compose. But, using `docker compose up` to deploy a new version of a service causes downtime because the containers are stopped before the new containers are created. Nowadays, this kind of downtime is unacceptable for end users.

`docker-compizo` tries to maintain a balance between a simple solution and a good end-user experience.

## About the name

Compizo (/kəmˈpaɪzoʊ/) is a compound word formed by combining _compose_ and and _zero deployment_:

> docker-compizo = <ins>docker-comp</ins>ose + <ins>z</ins>er<ins>o</ins> deployment

## License

MIT
