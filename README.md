# docker-salt — SaltStack master & minion images

[![Build and Push](https://github.com/mbologna/docker-salt/actions/workflows/build-and-push.yml/badge.svg)](https://github.com/mbologna/docker-salt/actions/workflows/build-and-push.yml)

Docker images of [SaltStack](https://saltproject.io/) built on a pinned
[openSUSE Leap](https://www.opensuse.org/) base and published to Docker Hub:

* **[`mbologna/saltstack-master`](https://hub.docker.com/r/mbologna/saltstack-master)** —
  a Salt master that auto-accepts minion keys and exposes the
  `salt-api` (cherrypy / netapi) interface on port `9080`.
* **[`mbologna/saltstack-minion`](https://hub.docker.com/r/mbologna/saltstack-minion)** —
  a Salt minion preconfigured to connect to a master reachable as `salt`.

These images are primarily used as test fixtures for
[SUSE/salt-netapi-client](https://github.com/SUSE/salt-netapi-client).

![Demo in action](demo/result.gif)

## Quick start (docker compose)

```bash
docker compose up -d --build
```

This starts a master (with `salt-api` on `localhost:9080`) and one minion whose
key is auto-accepted. Scale the minions:

```bash
docker compose up -d --scale salt-minion=3
```

## Quick start (docker run)

Start the master:

```bash
docker run -d --hostname saltmaster --name saltmaster \
  -v "$(pwd)/srv/salt:/srv/salt" -p 9080:9080 -ti mbologna/saltstack-master
```

Start one or more minions (linked so the master resolves as `salt`):

```bash
docker run -d --hostname saltminion --name saltminion \
  --link saltmaster:salt mbologna/saltstack-minion
```

```bash
for i in $(seq 1 10); do
  docker run -d --hostname saltminion$i --name saltminion$i \
    --link saltmaster:salt mbologna/saltstack-minion
done
```

## Running Salt

Via the command line:

```bash
docker exec saltmaster salt '*' test.ping
docker exec saltmaster salt '*' cmd.run 'uname -a'
```

Via the netapi (HTTP) interface:

```bash
# 1. Get a token (PAM auth, user/password: saltdev/saltdev)
curl -sS http://localhost:9080/login \
  -c ~/cookies.txt -H 'Accept: application/json' \
  -d username=saltdev -d password=saltdev -d eauth=pam

# 2. Use the saved token to run a function
curl -sS http://localhost:9080 \
  -b ~/cookies.txt -H 'Accept: application/json' \
  -d client=local -d tgt='*' -d fun=cmd.run -d arg=uptime
```

## Applying Salt states

A `./srv/salt` directory is mounted into the master at `/srv/salt`. Drop your
SLS files there:

```bash
cat srv/salt/tmux.sls
```

```yaml
tmux:
  pkg.installed
```

```bash
docker exec saltmaster salt saltminion1 state.apply tmux
```

## Compatibility with salt-netapi-client

`SUSE/salt-netapi-client` consumes these images as GitHub Actions `services`.
The following is a stable contract — do not change it:

| Property            | Value                                             |
| ------------------- | ------------------------------------------------- |
| Image names         | `mbologna/saltstack-master`, `mbologna/saltstack-minion` |
| salt-api port       | `9080/tcp` (HTTP, SSL disabled)                   |
| Minion key handling | `auto_accept: True`                               |
| Auth                | PAM, user `saltdev`, password `saltdev`, perms `.*` |
| Master hostname     | minions reach the master as `salt`                |

## Building and testing locally

```bash
# Build both images
docker compose build

# End-to-end smoke test (build, login, test.ping, runner + wheel clients)
./scripts/integration-test.sh
```

A `Makefile` wraps the common tasks: `make build`, `make test`, `make up`,
`make down`, `make logs`, `make lint`. See [CONTRIBUTING.md](CONTRIBUTING.md) for
the full developer workflow and [SECURITY.md](SECURITY.md) for the test-fixture
security caveats.

The same script runs in CI on every push and pull request.

## Continuous integration & publishing

`.github/workflows/build-and-push.yml`:

1. lints the Dockerfiles (`hadolint`) and workflow YAML (`yamllint`);
2. runs the integration test (`scripts/integration-test.sh`);
3. builds both images for `linux/amd64`;
4. pushes them to Docker Hub on pushes to the default branch with tags
   `latest`, `sha-<sha>`, the detected Salt version (e.g. `3006.0` and `3006`),
   and semver tags from `v*` git tags;
5. scans the published images with Trivy.

Pull requests build and test only — they do not push.

### Required repository secrets

To publish to Docker Hub, add these in **Settings → Secrets and variables →
Actions**:

| Secret            | Description                                        |
| ----------------- | -------------------------------------------------- |
| `DOCKER_USERNAME` | Docker Hub username (must be `mbologna`)            |
| `DOCKER_PASSWORD` | Docker Hub access token with read/write permissions |

## Dependency updates

Dependencies (base image, packages, and pinned GitHub Actions) are kept up to
date by [Renovate](https://docs.renovatebot.com/), inheriting the shared
[`mbologna/.github`](https://github.com/mbologna/.github) preset via
`renovate.json`.

## Caveats and security

* The master exposes port `9080/tcp` over **plain HTTP (no SSL)** — credentials
  travel in clear text. These images are intended for testing, not production.
* PAM auth uses a baked-in `saltdev` / `saltdev` account. Do not expose these
  images on untrusted networks.
* Writing to `/srv/salt` on the host may require `root`.

## License

[MIT](LICENSE) © Michele Bologna
