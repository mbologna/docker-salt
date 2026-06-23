# Contributing to docker-salt

Thanks for your interest in improving these images! This repository provides two
SaltStack images used primarily as test fixtures for
[SUSE/salt-netapi-client](https://github.com/SUSE/salt-netapi-client).

## Development workflow

Prerequisites: Docker (with the Compose plugin). For linting locally you also
need `hadolint`, `shellcheck` and `yamllint`.

```bash
make build     # build both images
make test      # run the end-to-end integration test (login + test.ping + runner/wheel)
make lint      # hadolint + shellcheck + yamllint
make up        # start the stack
make down      # tear it down
```

The same integration test (`scripts/integration-test.sh`) runs in CI on every
push and pull request.

## Compatibility contract (do not break)

`salt-netapi-client` consumes these images, so the following must stay stable:

- Image names: `mbologna/saltstack-master`, `mbologna/saltstack-minion`
- salt-api on port `9080` (HTTP, SSL disabled)
- `auto_accept: True` for minion keys
- PAM auth, user `saltdev`, password `saltdev`, perms `.*`
- Minions reach the master as the host `salt`

If a change would affect any of the above, call it out explicitly in the PR.

## Commit messages

This repo uses [Conventional Commits](https://www.conventionalcommits.org/)
(enforced by a commit hook), e.g. `feat: ...`, `fix: ...`, `ci: ...`,
`docs: ...`, `chore(deps): ...`.

## Continuous integration

PRs build and test only. Pushes to the default branch additionally build and
push multi-tagged images to Docker Hub and run a Trivy scan. Dependencies (base
image, packages, GitHub Actions) are kept current by Renovate.
