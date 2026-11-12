# Security Policy

## Intended use

These images are **test fixtures**, not production artifacts. They are designed
to bring up a throwaway SaltStack master/minion for exercising
[salt-netapi-client](https://github.com/SUSE/salt-netapi-client) and similar
tooling.

By design they are **not hardened**:

- `salt-api` is served over **plain HTTP (no SSL)** on port `9080` — credentials
  travel in clear text.
- A fixed PAM account `saltdev` / `saltdev` is baked in.
- The master **auto-accepts** any minion key (`auto_accept: True`).
- Both images **run as root**, on purpose. The minion applies states and runs
  modules that manage the system (packages, services, files), which needs
  root. The master runs salt-master as `user: root` because salt-api's PAM
  login for `saltdev` reads `/etc/shadow`; a non-root master would fail that
  login, which is what salt-netapi-client tests.
- The packages beyond the openSUSE Leap base are what the `salt`, `salt-master`,
  `salt-api` and `salt-minion` RPMs require (Python, systemd, sudo, ...); the
  Dockerfiles add nothing else. `curl` (the master's health check) and `shadow`
  (`useradd`) already ship in the base image.

Do **not** run these images on untrusted networks or expose port `9080` publicly.

## Supported versions

Only the latest published image (`:latest`) is supported. Images are rebuilt
from a pinned, Renovate-tracked openSUSE Leap base so security updates flow in
through routine dependency bumps. Each pushed image is scanned with Trivy in CI.

## Reporting a vulnerability

If you find a security issue in the image build (as opposed to the intentional
test-fixture behaviour above), please open a
[private security advisory](https://github.com/mbologna/saltstack-container/security/advisories/new)
or a regular issue if it is not sensitive.
