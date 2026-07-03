# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- GitHub issue templates for bug reports and feature requests
- Pull request template with contributor checklist
- Code of Conduct (Contributor Covenant 2.1)
- Contributing guide with setup, testing, and commit conventions
- Timestamp logging to entrypoint script for better debugging
- Configurable `SLEEP_INTERVAL` environment variable in integration test
- Expanded `.gitignore` with IDE files, env files, and development artifacts
- Improved error messages in integration test with debugging context

### Changed
- Replaced Python with `jq` for JSON parsing in integration test
- Integration test now requires `jq` instead of `python3`

### Documented
- Added explanation for custom GitHub Actions workflow vs. reusable workflow
- Dynamic Salt version badge in README

## [2024-01] - 2024-01

### Added
- Hardened Docker images with security best practices
- Broader test coverage in integration tests
- Dynamic Salt version extraction and tagging in CI

### Changed
- Moved base image from openSUSE Tumbleweed to openSUSE Leap 16.0
- Build images for `linux/amd64` only (removed multi-arch)
- Streamlined README and removed old CONTRIBUTING.md

### Fixed
- Renovate versioning strategy for openSUSE Leap (cap below legacy 42.x line)
- Dependency pinning with SHA digests

## [2023-12] - 2023-12

### Added
- Revived and modernized SaltStack master/minion images
- Docker Compose configuration for easy local development
- Integration test script (`scripts/integration-test.sh`)
- GitHub Actions CI/CD pipeline with linting and Trivy scanning
- Renovate configuration for automated dependency updates
- SECURITY.md documenting test-fixture nature and limitations

### Changed
- Switched from Supervisor to direct process management in entrypoint
- Exposed salt-api on port 9080 (HTTP)
- Proper ENTRYPOINT and CMD usage in Dockerfiles

### Fixed
- Base image selection (settled on openSUSE Leap for stability)

---

## Release Notes

Images are tagged as:
- `latest` - Latest build from the default branch
- `<version>` - Detected Salt version (e.g., `3007.2`, `3007`)
- `sha-<commit>` - Git commit SHA
- Semver tags when git tags are pushed (e.g., `v1.0.0`)

See [README § Quick start](README.md#quick-start) for usage instructions.
