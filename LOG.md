# Completed Work

## v3.0.0 Modernization (2026-01-29)

Implemented from PLAN.md:

1. **Package Modernization** — Updated debian/control to Standards-Version 4.6.2, debhelper-compat 13, Priority optional. Deleted debian/compat.
2. **Multi-Distribution Support** — postinst detects codename via lsb_release/os-release on fresh install only. Upgrades preserve existing `movealong.list` (keeps `stable`). Deleted preinst/prerm (no-ops). Makefile ships `movealong.list` with `stable` as default.
3. **GitHub Actions CI/CD** — build-test.yml (matrix: debian 11/12/13, ubuntu 22.04/24.04), release-please.yml (debian release type, auto changelog, S3 publish to all 7 codenames), dependabot.yml.
4. **Documentation** — Updated README, created CONTRIBUTING.md.
5. **Changelog** — Added v3.0.0 entry to debian/changelog.

## Refinements (2026-02-16)

- Removed template-based approach (movealong.list.template) in favor of shipping movealong.list directly with `stable` default — simpler upgrade path for existing users
- postinst now only rewrites codename on fresh install (`configure` with no previous version), not on upgrade
- Added S3 publishing to release workflow (deb-s3 upload to all 7 codenames via common pool)
- GPG signing in CI via `GPG_PRIVATE_KEY` secret

## CI/CD Fixes (2026-02-16)

- Fixed `upload-artifact@v4` rejecting `../*.deb` — copies .deb into workspace first
- Added `.gitignore` for `*.deb` and debian build products
- Added `debian/copyright` (MIT, DEP-5 format)
- Added lintian overrides: `package-installs-apt-sources` (binary), `custom-compression-in-debian-rules` (source)
- Changed lintian from `|| true` to `--fail-on warning`
- Fixed release-please: `release-type: debian` is invalid, switched to `simple` with manifest-based config
- Added `update-debian-changelog` job to release-please workflow — runs `dch` on PR branch with entries from CHANGELOG.md
- Reset version to 2.0.0 (last actual release); release-please will create the 3.0.0 release PR
- Added `version.txt`, `release-please-config.json`, `.release-please-manifest.json`
- Filled in Vcs-Git and Vcs-Browser in debian/control
