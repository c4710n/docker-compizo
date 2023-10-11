# docker-compizo

![Nix flakes](https://img.shields.io/badge/Nix%20flakes-5277C3?logo=nixos&logoColor=white&style=flat-square)

Deploy a new version of Docker Compose service without downtime.

> This project is inspired by [docker-rollout](https://github.com/Wowu/docker-rollout).

## Features

- 🐳 Works with Docker Compose.
- ❤️ Supports Docker healthchecks out of the box.

## Usage

```bash
$ docker-compizo -f compose.yml SERVICE
```

See `docker-compizo --help` and examples in [examples](examples) directory for more usage.

### ⚠️ Limits

- A proxy is required to route traffic, such as [Traefik](https://github.com/traefik/traefik) or [nginx-proxy](https://github.com/nginx-proxy/nginx-proxy). (Traefik is recommended. In conjunction with Docker healthchecks, it will make sure that traffic is only routed to the new containers when they're ready, with ease.)
- `SERVICE` cannot have `container_name` and `ports` defined in `compose.yml`, as it's not possible to run multiple containers with the same name or port mapping.
- Each deployment will increment the index in container name (e.g. `project-web-1` -> `project-web-2`).

## How it works?

`docker-compizo` achieves a zero downtime deployment by:

1. scaling the service to twice the current number of containers
2. waiting for the new containers to be ready
3. removing the old containers

## Why?

Using container orchestration tools like [Kubernetes](https://kubernetes.io/) or [Nomad](https://www.nomadproject.io/) is usually an overkill for projects that will do fine with a single-server Docker Compose setup.

But, using `docker compose up` to deploy a new version of a service causes downtime because the app container is stopped before the new container is created. If your application takes a while to boot, this may be noticeable to users.

`docker-compizo` tries to maintain a balance between a simple solution and a good end-user experience.

## License

MIT
