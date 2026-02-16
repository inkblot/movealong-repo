This repository contains the source code of a Debian meta package which installs the signing key and apt sources for
the movealong apt repository at https://dist.movealong.org/apt/.

## Build

- Build dependencies: debhelper, devscripts, lintian
- Build: `debuild -uc -us`
- Lint: `lintian --pedantic ../movealong-repo_*.deb`

## Architecture

- Ships `movealong.list` with `stable` as default codename
- postinst rewrites codename only on fresh install (not upgrade), using lsb_release or /etc/os-release
- Supported: Ubuntu (jammy, noble, focal), Debian (bullseye, bookworm, trixie), fallback to "stable"
- debhelper compat 13, Standards-Version 4.6.2

## CI/CD

- GitHub Actions: `build-test.yml` (matrix across 5 distros), `release-please.yml` (semantic versioning + S3 publish)
- Conventional commits drive versioning (feat: minor, fix: patch, feat!: major)
- release-please uses `release-type: debian` to manage debian/changelog
- Publish job uploads .deb to GitHub Releases and S3 (all 7 codenames via deb-s3, common pool)
- Required secrets: `GPG_PRIVATE_KEY`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`