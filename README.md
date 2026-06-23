# docker-salt — SaltStack master & minion images

[![Build and Push](https://github.com/mbologna/docker-salt/actions/workflows/build-and-push.yml/badge.svg)](https://github.com/mbologna/docker-salt/actions/workflows/build-and-push.yml)
[![Salt version](https://img.shields.io/docker/v/mbologna/saltstack-master?sort=semver&label=salt&color=00a651)](https://hub.docker.com/r/mbologna/saltstack-master/tags)

Ready-to-run [SaltStack](https://saltproject.io/) images built on a pinned
[openSUSE Leap](https://www.opensuse.org/) base and published to Docker Hub:

| Image | Description |
| ----- | ----------- |
| **[`mbologna/saltstack-master`](https://hub.docker.com/r/mbologna/saltstack-master)** | Salt master that auto-accepts minion keys and serves the `salt-api` (cherrypy / netapi) HTTP interface on port `9080`. |
| **[`mbologna/saltstack-minion`](https://hub.docker.com/r/mbologna/saltstack-minion)** | Salt minion preconfigured to connect to a master reachable as `salt`. |

Images are tagged `latest`, the detected Salt version (e.g. `3006.0` and `3006`),
`sha-<commit>`, and semver (`vX.Y.Z`) from git tags.

> **For testing, not production.** salt-api is served over plain HTTP and the
> images ship a fixed `saltdev` account and auto-accept any minion key. See
> [SECURITY.md](SECURITY.md).

These images are the test fixtures behind
[SUSE/salt-netapi-client](https://github.com/SUSE/salt-netapi-client).

![Demo in action](demo/result.gif)

## Quick start

```bash
docker compose up -d --build
```

This brings up a master (with `salt-api` on `localhost:9080`) and one minion
whose key is auto-accepted. Scale the minions with:

```bash
docker compose up -d --scale salt-minion=3
```

<details>
<summary>Without compose (<code>docker run</code>)</summary>

```bash
# Master: salt-api on :9080, states mounted from ./srv/salt
docker run -d --name saltmaster \
  -v "$(pwd)/srv/salt:/srv/salt" -p 9080:9080 mbologna/saltstack-master

# Minion(s): --link makes the master resolve as `salt`
docker run -d --name saltminion1 --link saltmaster:salt mbologna/saltstack-minion
```
</details>

## Running Salt

From the master, over the Salt CLI:

```bash
docker exec saltmaster salt '*' test.ping
docker exec saltmaster salt '*' cmd.run 'uname -a'
```

Over the netapi (HTTP) interface — PAM auth, user/password `saltdev`/`saltdev`:

```bash
# 1. Authenticate and save the token
curl -sS http://localhost:9080/login \
  -c ~/cookies.txt -H 'Accept: application/json' \
  -d username=saltdev -d password=saltdev -d eauth=pam

# 2. Run a function with the saved token
curl -sS http://localhost:9080 \
  -b ~/cookies.txt -H 'Accept: application/json' \
  -d client=local -d tgt='*' -d fun=cmd.run -d arg=uptime
```

## Applying Salt states

`./srv/salt` is mounted into the master at `/srv/salt`. Drop SLS files there and
apply them:

```bash
cat srv/salt/tmux.sls
# tmux:
#   pkg.installed

docker exec saltmaster salt saltminion1 state.apply tmux
```

## Development

Common tasks are wrapped in a `Makefile`:

```bash
make build   # build both images
make test    # end-to-end test: login + test.ping + runner & wheel netapi clients
make lint    # hadolint + shellcheck + yamllint
make up      # start the stack          make down  # tear it down
```

`make test` runs `scripts/integration-test.sh`, the same end-to-end test CI runs
on every push and pull request. Commits follow
[Conventional Commits](https://www.conventionalcommits.org/) (enforced by a
commit hook).

## Compatibility with salt-netapi-client

`SUSE/salt-netapi-client` consumes these images as GitHub Actions `services`.
The following is a **stable contract — do not change it**:

| Property            | Value                                             |
| ------------------- | ------------------------------------------------- |
| Image names         | `mbologna/saltstack-master`, `mbologna/saltstack-minion` |
| salt-api port       | `9080/tcp` (HTTP, SSL disabled)                   |
| Minion key handling | `auto_accept: True`                               |
| Auth                | PAM, user `saltdev`, password `saltdev`, perms `.*` |
| Master hostname     | minions reach the master as `salt`                |

Modern Salt (3006+) disables netapi clients by default; this contract is kept
working by enabling them in `etc_master/salt/master.d/netapi.conf`.

## Continuous integration

[`build-and-push.yml`](.github/workflows/build-and-push.yml) lints
(hadolint + yamllint), runs the integration test, then builds both images for
`linux/amd64`. On pushes to the default branch it also pushes the images to
Docker Hub and scans them with Trivy; pull requests build and test only.

Base image, packages, and pinned GitHub Actions are kept current by
[Renovate](https://docs.renovatebot.com/) via `renovate.json`.

## License

[MIT](LICENSE) © Michele Bologna
