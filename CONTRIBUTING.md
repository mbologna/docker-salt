# Contributing to docker-salt

Thanks for your interest in contributing! These images are test fixtures for
[salt-netapi-client](https://github.com/SUSE/salt-netapi-client), so please
keep changes aligned with that purpose.

## Quick Start

### Prerequisites

You'll need Docker (with compose plugin) and these development tools:

```bash
# openSUSE / SUSE Linux Enterprise
sudo zypper install hadolint ShellCheck jq python3-yamllint

# Ubuntu/Debian
sudo apt-get install hadolint shellcheck jq yamllint

# macOS
brew install hadolint shellcheck jq yamllint
```

### Getting Started

```bash
# Clone the repository
git clone https://github.com/mbologna/docker-salt.git
cd docker-salt

# Build both images
make build

# Start the stack
make up

# Run integration tests
make test

# Lint all files (Dockerfiles, scripts, YAML)
make lint

# Stop the stack
make down
```

## Development Workflow

1. **Fork and clone** the repository
2. **Create a branch** for your changes
3. **Make your changes** following the guidelines below
4. **Test locally** with `make lint` and `make test`
5. **Commit** using [Conventional Commits](https://www.conventionalcommits.org/)
6. **Push** to your fork and **open a pull request**

## Commit Messages

Commits must follow the [Conventional Commits](https://www.conventionalcommits.org/)
format (enforced by a commit hook):

```
<type>(<scope>): <description>

[optional body]
[optional footer]
```

Examples:
- `feat: add environment variable for custom salt config`
- `fix: resolve healthcheck timeout issue`
- `docs: update README with new examples`
- `chore(deps): update base image digest`

## Testing

Before submitting a PR:

```bash
# Lint everything
make lint

# Run integration tests
make test

# Test manually if needed
make up
docker exec saltmaster salt '*' test.ping
make down
```

The integration test (`scripts/integration-test.sh`) validates:
- salt-api HTTP endpoint responds
- PAM authentication works with saltdev/saltdev
- Minion registers and responds to test.ping
- All three netapi clients (local, runner, wheel) function

## Stable Contract

**Do not change these** without explicit discussion — they are the stable
contract with salt-netapi-client consumers:

| Property | Value |
|----------|-------|
| Image names | `mbologna/saltstack-master`, `mbologna/saltstack-minion` |
| salt-api port | `9080/tcp` (HTTP) |
| Authentication | PAM, user `saltdev`, password `saltdev` |
| Minion keys | `auto_accept: True` |
| Master hostname | Minions reach master as `salt` |

See [README § Compatibility](README.md#compatibility-with-salt-netapi-client)
for details.

## Pull Request Guidelines

When opening a PR, please:

- Fill out the PR template checklist
- Link related issues if applicable
- Describe what you tested and how
- Keep changes focused (one feature/fix per PR)
- Update documentation (README, SECURITY.md) if needed

## Code Style

- **Shell scripts**: Follow existing style, use shellcheck
- **Dockerfiles**: Follow hadolint recommendations
- **YAML**: yamllint-clean (see `.github/workflows/build-and-push.yml` config)

## Questions?

Open a [Discussion](https://github.com/mbologna/docker-salt/discussions) or
[Issue](https://github.com/mbologna/docker-salt/issues) if you need help!

## License

By contributing, you agree that your contributions will be licensed under the
[MIT License](LICENSE).
