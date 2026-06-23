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

Do **not** run these images on untrusted networks or expose port `9080` publicly.

## Supported versions

Only the latest published image (`:latest`) is supported. Images are rebuilt
from a pinned, Renovate-tracked openSUSE Leap base so security updates flow in
through routine dependency bumps. Each pushed image is scanned with Trivy in CI.

## Reporting a vulnerability

If you find a security issue in the image build (as opposed to the intentional
test-fixture behaviour above), please open a
[private security advisory](https://github.com/mbologna/docker-salt/security/advisories/new)
or a regular issue if it is not sensitive.
