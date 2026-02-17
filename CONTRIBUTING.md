# Contributing to movealong-repo

## Conventional Commits

This project uses [Conventional Commits](https://www.conventionalcommits.org/) for automated versioning.

### Commit Message Format

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

### Types

- `feat:` - New feature (minor version bump)
- `fix:` - Bug fix (patch version bump)
- `feat!:` - Breaking change (major version bump)
- `fix!:` - Breaking bug fix (major version bump)
- `docs:` - Documentation only
- `chore:` - Maintenance tasks
- `ci:` - CI/CD changes
- `refactor:` - Code refactoring
- `test:` - Adding tests

### Examples

```bash
feat: add support for Ubuntu 24.04

fix: correct codename detection for Debian trixie

feat!: change to distro-specific codenames

This is a breaking change because it requires updating
the S3 repository structure to include codename-specific
directories.

chore: update debhelper to version 13
```

## Testing Locally

### Build and Test

```bash
# Build
debuild -uc -us

# Lint
lintian --pedantic ../movealong-repo_*.deb

# Test in Docker
docker run -it --rm -v $(pwd)/../:/build ubuntu:jammy bash
cd /build
apt-get update && apt-get install -y lsb-release
dpkg -i movealong-repo_*.deb
cat /etc/apt/sources.list.d/movealong.list
```

### Test Matrix Locally

Test across all supported distributions:

```bash
for distro in ubuntu:22.04 ubuntu:24.04 debian:11 debian:12 debian:13; do
  echo "Testing $distro..."
  docker run --rm -v $(pwd)/../:/build $distro bash -c \
    "apt-get update && apt-get install -y lsb-release && \
     dpkg -i /build/movealong-repo_*.deb && \
     cat /etc/apt/sources.list.d/movealong.list"
done
```

## Release Process

Releases are fully automated:

1. Make changes with conventional commits
2. Push to `master`
3. release-please bot creates a release PR
4. Review and merge the release PR
5. release-please creates a GitHub release
6. Manually upload .deb to S3 for each codename

## Pull Request Guidelines

- Use conventional commit format in PR title
- Ensure CI passes (all 5 distro tests)
- Update documentation if needed
- One feature/fix per PR
