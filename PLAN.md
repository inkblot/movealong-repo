# Modernization Plan: movealong-repo v3.0.0

## Overview
Modernize the movealong-repo Debian meta-package with three major changes:
1. **Support multiple distributions** - Auto-detect Ubuntu/Debian versions and use distro-specific codenames
2. **Modernize package structure** - Update to current Debian standards (4.6.2, debhelper 13)
3. **Add CI/CD automation** - GitHub Actions with matrix builds and release-please for semantic versioning

## Key Design Decisions

### Multi-Distribution Strategy
- **Single package** with runtime distribution detection using lsb_release or /etc/os-release
- **Distro-specific codenames** in apt sources (jammy, noble, bookworm, trixie, bullseye)
- Template-based sources.list generation in postinst

### CI/CD Approach
- **GitHub Actions** for all automation
- **Matrix builds** across 5 distributions (Debian 11/12/13, Ubuntu 22.04/24.04)
- **release-please-action** for automated semantic versioning from conventional commits
- **Automated testing** of package installation on each distro

### Version Management
- Start at **v3.0.0** (major version for breaking changes)
- Use **conventional commits** (feat:, fix:, feat!:, etc.)
- **release-please** auto-generates versions, changelogs, and GitHub releases

---

## Phase 1: Package Modernization

### Update debian/control
**File:** `/home/inkblot/var/src/movealong-repo/debian/control`

**Changes:**
- Standards-Version: `3.9.4` → `4.6.2`
- Build-Depends: `debhelper (>= 8.0.0)` → `debhelper-compat (= 13)`
- Priority: `extra` → `optional` (extra is deprecated)
- Add: `Depends: ${misc:Depends}, lsb-release | base-files (>= 11)`
- Add: `Vcs-Git` and `Vcs-Browser` fields (update with actual GitHub URL)
- Add: `Homepage: https://dist.movealong.org/apt/`
- Update Description to mention multi-distro support

**New content:**
```
Source: movealong-repo
Section: admin
Priority: optional
Maintainer: Nate Riffe <inkblot@movealong.org>
Build-Depends: debhelper-compat (= 13)
Standards-Version: 4.6.2
Vcs-Git: https://github.com/[username]/movealong-repo.git
Vcs-Browser: https://github.com/[username]/movealong-repo
Homepage: https://dist.movealong.org/apt/

Package: movealong-repo
Architecture: all
Depends: ${misc:Depends}, lsb-release | base-files (>= 11)
Description: Installs the movealong apt repository
 This package installs an apt source for the movealong apt repository
 at https://dist.movealong.org/apt/.
 .
 The package automatically detects the distribution (Ubuntu/Debian) and
 codename to configure the appropriate repository source.
```

### Remove debian/compat
**File:** `/home/inkblot/var/src/movealong-repo/debian/compat`

**Action:** Delete this file entirely (replaced by debhelper-compat in Build-Depends)

### Update debian/rules
**File:** `/home/inkblot/var/src/movealong-repo/debian/rules`

**Changes:** Add comments for clarity, keep override_dh_usrlocal

```
#!/usr/bin/make -f

# Uncomment this to turn on verbose mode.
#export DH_VERBOSE=1

# Use debhelper 13 compatibility level
%:
	dh $@

# override_dh_usrlocal to do nothing (we install to /etc and /usr/share)
override_dh_usrlocal:

# No tests to run
override_dh_auto_test:
```

---

## Phase 2: Multi-Distribution Support

### Create movealong.list.template
**File:** `/home/inkblot/var/src/movealong-repo/movealong.list.template`

**Content:**
```
deb [signed-by=/usr/share/keyrings/inkblot-movealong-keyring.gpg] https://dist.movealong.org/apt ${CODENAME} main
```

**Note:** Template uses ${CODENAME} placeholder for runtime substitution

### Update Makefile
**File:** `/home/inkblot/var/src/movealong-repo/Makefile`

**Changes:** Install template instead of final .list file

```makefile
#
# Makefile
#

all:

clean:

install:
	mkdir -p $(DESTDIR)
	install -m 755 -d $(DESTDIR)/etc/apt/sources.list.d
	install -m 755 -d $(DESTDIR)/usr/share/keyrings
	install -m 644 movealong.list.template $(DESTDIR)/etc/apt/sources.list.d/movealong.list.template
	install -m 644 inkblot-movealong-keyring.gpg $(DESTDIR)/usr/share/keyrings/
```

### Rewrite debian/postinst
**File:** `/home/inkblot/var/src/movealong-repo/debian/postinst`

**Purpose:** Detect distribution codename and generate sources.list

```bash
#!/bin/bash
set -e

# Function to detect distribution codename
detect_codename() {
    # Try lsb_release first (most reliable)
    if command -v lsb_release >/dev/null 2>&1; then
        lsb_release -cs
        return 0
    fi

    # Fall back to /etc/os-release
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "${VERSION_CODENAME:-stable}"
        return 0
    fi

    # Last resort: use stable
    echo "stable"
}

# Validate codename against supported list
validate_codename() {
    local codename="$1"
    case "$codename" in
        # Ubuntu releases
        jammy|noble|focal)
            return 0
            ;;
        # Debian releases
        bullseye|bookworm|trixie)
            return 0
            ;;
        # Fallback
        stable)
            return 0
            ;;
        *)
            echo "Warning: Unsupported distribution codename: $codename" >&2
            echo "Falling back to 'stable'" >&2
            echo "stable"
            return 1
            ;;
    esac
}

# Main installation logic
if [ "$1" = "configure" ]; then
    CODENAME=$(detect_codename)

    # Validate and potentially override with stable
    if ! validate_codename "$CODENAME" >/dev/null 2>&1; then
        CODENAME="stable"
    fi

    TEMPLATE="/etc/apt/sources.list.d/movealong.list.template"
    TARGET="/etc/apt/sources.list.d/movealong.list"

    # Generate sources list from template
    if [ -f "$TEMPLATE" ]; then
        sed "s/\${CODENAME}/$CODENAME/g" "$TEMPLATE" > "$TARGET"
        chmod 644 "$TARGET"

        # Clean up template
        rm -f "$TEMPLATE"

        echo "Configured movealong repository for: $CODENAME"
    else
        echo "Warning: Template file not found, using fallback" >&2
        echo "deb [signed-by=/usr/share/keyrings/inkblot-movealong-keyring.gpg] https://dist.movealong.org/apt stable main" > "$TARGET"
        chmod 644 "$TARGET"
    fi
fi

#DEBHELPER#
```

### Rewrite debian/postrm
**File:** `/home/inkblot/var/src/movealong-repo/debian/postrm`

**Purpose:** Clean up sources list on removal

```bash
#!/bin/bash
set -e

if [ "$1" = "remove" ] || [ "$1" = "purge" ]; then
    rm -f /etc/apt/sources.list.d/movealong.list
    rm -f /etc/apt/sources.list.d/movealong.list.template
fi

#DEBHELPER#
```

### Delete unnecessary maintainer scripts
**Files to delete:**
- `/home/inkblot/var/src/movealong-repo/debian/preinst`
- `/home/inkblot/var/src/movealong-repo/debian/prerm`

**Rationale:** These contain only no-ops and are not needed

---

## Phase 3: GitHub Actions CI/CD

### Create workflow directory
**Directory:** `.github/workflows/`

### Create release-please workflow
**File:** `.github/workflows/release-please.yml`

**Purpose:** Automated semantic versioning and releases

```yaml
name: Release Please

on:
  push:
    branches:
      - master

permissions:
  contents: write
  pull-requests: write

jobs:
  release-please:
    runs-on: ubuntu-latest
    steps:
      - uses: googleapis/release-please-action@v4
        id: release
        with:
          release-type: simple
          package-name: movealong-repo

      # Build and upload .deb if a release was created
      - uses: actions/checkout@v4
        if: ${{ steps.release.outputs.release_created }}

      - name: Install build dependencies
        if: ${{ steps.release.outputs.release_created }}
        run: |
          sudo apt-get update
          sudo apt-get install -y debhelper devscripts

      - name: Update debian/changelog for release
        if: ${{ steps.release.outputs.release_created }}
        run: |
          # release-please version is in steps.release.outputs.version
          dch -v "${{ steps.release.outputs.version }}" "Release ${{ steps.release.outputs.version }}"
          dch -r ""

      - name: Build package
        if: ${{ steps.release.outputs.release_created }}
        run: debuild -us -uc

      - name: Upload release assets
        if: ${{ steps.release.outputs.release_created }}
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          gh release upload ${{ steps.release.outputs.tag_name }} \
            ../movealong-repo_${{ steps.release.outputs.version }}_all.deb
```

### Create build and test workflow
**File:** `.github/workflows/build-test.yml`

**Purpose:** Matrix build and test on every PR/push

```yaml
name: Build and Test

on:
  push:
    branches: [ master ]
  pull_request:
    branches: [ master ]

jobs:
  lint-and-build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install build dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y debhelper devscripts lintian

      - name: Build package
        run: debuild -us -uc

      - name: Run lintian
        run: lintian --info --display-info --pedantic ../*.deb || true

      - name: Upload build artifacts
        uses: actions/upload-artifact@v4
        with:
          name: debian-package
          path: ../*.deb
          retention-days: 7

  test-install:
    needs: lint-and-build
    strategy:
      fail-fast: false
      matrix:
        distro:
          - debian:11
          - debian:12
          - debian:13
          - ubuntu:22.04
          - ubuntu:24.04
        include:
          - distro: debian:11
            codename: bullseye
          - distro: debian:12
            codename: bookworm
          - distro: debian:13
            codename: trixie
          - distro: ubuntu:22.04
            codename: jammy
          - distro: ubuntu:24.04
            codename: noble

    runs-on: ubuntu-latest
    container:
      image: ${{ matrix.distro }}

    steps:
      - name: Download built package
        uses: actions/download-artifact@v4
        with:
          name: debian-package

      - name: Install dependencies
        run: |
          apt-get update
          apt-get install -y lsb-release

      - name: Install package
        run: dpkg -i *.deb || apt-get install -f -y

      - name: Verify installation
        run: |
          test -f /etc/apt/sources.list.d/movealong.list || exit 1
          test -f /usr/share/keyrings/inkblot-movealong-keyring.gpg || exit 1
          grep -q "deb \[signed-by=/usr/share/keyrings/inkblot-movealong-keyring.gpg\]" \
            /etc/apt/sources.list.d/movealong.list || exit 1

      - name: Verify codename detection
        run: |
          grep -q "${{ matrix.codename }}" /etc/apt/sources.list.d/movealong.list || exit 1
          echo "✓ Codename ${{ matrix.codename }} detected correctly"

      - name: Test removal
        run: |
          apt-get remove -y movealong-repo
          test ! -f /etc/apt/sources.list.d/movealong.list || exit 1
          echo "✓ Package removed cleanly"
```

### Create dependabot config (optional)
**File:** `.github/dependabot.yml`

**Purpose:** Keep GitHub Actions up to date

```yaml
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
```

---

## Phase 4: Documentation

### Update README
**File:** `/home/inkblot/var/src/movealong-repo/README`

**Changes:** Add comprehensive documentation

```
The Debian Package movealong-repo
----------------------------

This package installs the apt source and apt key for the package repository at
https://dist.movealong.org/apt/

The package automatically detects your distribution (Ubuntu/Debian) and configures
the appropriate repository source.

Supported Distributions
----------------------------

Ubuntu: 20.04 (focal), 22.04 (jammy), 24.04 (noble)
Debian: 11 (bullseye), 12 (bookworm), 13 (trixie)

Installation
----------------------------

# Download and install
wget https://dist.movealong.org/apt/pool/movealong-repo_3.0.0_all.deb
sudo dpkg -i movealong-repo_3.0.0_all.deb
sudo apt-get update

Development
----------------------------

This project uses conventional commits and automated semantic versioning.

Commit message format:
  feat: new feature (minor version bump)
  fix: bug fix (patch version bump)
  feat!: breaking change (major version bump)
  chore: maintenance (no version bump)

Build and Test Locally
----------------------------

# Install build dependencies
sudo apt-get install debhelper devscripts lintian

# Build package
debuild -uc -us

# Test with lintian
lintian --info ../movealong-repo_*.deb

# Test installation in Docker
docker run -it --rm -v $(pwd)/../:/build ubuntu:jammy bash
  cd /build && apt-get update && apt-get install -y lsb-release
  dpkg -i movealong-repo_*.deb
  cat /etc/apt/sources.list.d/movealong.list

Release Process
----------------------------

Releases are automated via release-please:

1. Make changes using conventional commits
2. Push to master branch
3. release-please creates a PR with updated version/changelog
4. Merge the release PR
5. release-please creates a GitHub release with .deb artifact
6. Manually upload to S3 using deb-s3:

   deb-s3 upload --bucket dist.movealong.org --prefix apt/ \
     --codename <distro-codename> --preserve-versions \
     --sign inkblot@movealong.org movealong-repo_*.deb

Note: You'll need to upload for each supported codename:
  jammy, noble, focal (Ubuntu)
  bullseye, bookworm, trixie (Debian)

CI/CD
----------------------------

GitHub Actions workflows:
- build-test.yml: Runs on every push/PR, tests across 5 distros
- release-please.yml: Creates releases from conventional commits

Repository Structure Requirements
----------------------------

The S3 repository must have distribution-specific directories:

https://dist.movealong.org/apt/dists/jammy/
https://dist.movealong.org/apt/dists/noble/
https://dist.movealong.org/apt/dists/bookworm/
... etc

Use deb-s3 with --codename flag to create these structures.
```

### Create CONTRIBUTING.md
**File:** `/home/inkblot/var/src/movealong-repo/CONTRIBUTING.md`

```markdown
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
```

---

## Phase 5: Update debian/changelog

### Initial 3.0.0 Entry
**File:** `/home/inkblot/var/src/movealong-repo/debian/changelog`

**Action:** Add new entry at the top

```
movealong-repo (3.0.0) stable; urgency=medium

  * Major modernization release
  * Update Standards-Version to 4.6.2 (from 3.9.4)
  * Update debhelper compatibility to 13 (from 8)
  * Remove deprecated debian/compat file
  * Add multi-distribution support with automatic detection
  * Support Ubuntu 22.04, 24.04 and Debian 11, 12, 13
  * Use distribution-specific codenames (jammy, noble, bookworm, etc)
  * Rewrite postinst to detect and configure for specific distribution
  * Remove unnecessary maintainer scripts (preinst, prerm)
  * Add GitHub Actions CI/CD pipeline with matrix builds
  * Add automated semantic versioning via release-please
  * Add conventional commits workflow
  * Change Priority from "extra" to "optional" (extra is deprecated)
  * Add Vcs-Git and Vcs-Browser fields to debian/control

 -- Nate Riffe <inkblot@movealong.org>  Wed, 29 Jan 2026 XX:XX:XX -0600
```

**Note:** After this, release-please will manage changelog automatically

---

## Implementation Steps

### Step 1: Modernize Package Structure
1. Update `/home/inkblot/var/src/movealong-repo/debian/control`
2. Delete `/home/inkblot/var/src/movealong-repo/debian/compat`
3. Update `/home/inkblot/var/src/movealong-repo/debian/rules`
4. Test build: `debuild -us -uc`
5. Verify with lintian: `lintian --pedantic ../movealong-repo_*.deb`

### Step 2: Add Multi-Distribution Support
1. Create `/home/inkblot/var/src/movealong-repo/movealong.list.template`
2. Update `/home/inkblot/var/src/movealong-repo/Makefile`
3. Rewrite `/home/inkblot/var/src/movealong-repo/debian/postinst`
4. Rewrite `/home/inkblot/var/src/movealong-repo/debian/postrm`
5. Delete `/home/inkblot/var/src/movealong-repo/debian/preinst`
6. Delete `/home/inkblot/var/src/movealong-repo/debian/prerm`
7. Test in Docker containers for each distro

### Step 3: Setup GitHub Actions
1. Create `.github/workflows/` directory
2. Create `.github/workflows/build-test.yml`
3. Create `.github/workflows/release-please.yml`
4. Create `.github/dependabot.yml` (optional)
5. Push to GitHub and verify workflows run

### Step 4: Update Documentation
1. Update `/home/inkblot/var/src/movealong-repo/README`
2. Create `/home/inkblot/var/src/movealong-repo/CONTRIBUTING.md`

### Step 5: Finalize Release
1. Update `/home/inkblot/var/src/movealong-repo/debian/changelog` with 3.0.0 entry
2. Build final package: `debuild -us -uc`
3. Test thoroughly across all distros
4. Commit with: `feat!: modernize package to v3.0.0 with multi-distro support`
5. Push to GitHub
6. Merge release-please PR when created
7. Upload .deb to S3 for each codename

---

## Verification & Testing

### Pre-Merge Testing

**Build verification:**
```bash
debuild -us -uc
lintian --info --pedantic ../movealong-repo_*.deb
```

**Expected:** Clean build, no lintian errors, minimal warnings

**Installation test matrix:**
```bash
for distro in ubuntu:22.04 ubuntu:24.04 debian:11 debian:12 debian:13; do
  docker run --rm -v $(pwd)/../:/build $distro bash -c "
    apt-get update && apt-get install -y lsb-release &&
    dpkg -i /build/movealong-repo_*.deb &&
    test -f /etc/apt/sources.list.d/movealong.list &&
    grep -q signed-by /etc/apt/sources.list.d/movealong.list &&
    echo '✓ $distro PASS' || echo '✗ $distro FAIL'
  "
done
```

**Expected:** All 5 distributions pass

**Codename detection test:**
```bash
docker run --rm -v $(pwd)/../:/build ubuntu:22.04 bash -c "
  apt-get update && apt-get install -y lsb-release &&
  dpkg -i /build/movealong-repo_*.deb &&
  cat /etc/apt/sources.list.d/movealong.list
"
```

**Expected:** Sources list contains `jammy` not `stable`

### Post-Merge CI Verification

**GitHub Actions checks:**
- Build and test workflow passes for all 5 distros
- No lintian errors in CI logs
- Artifacts are created and downloadable
- release-please PR is created automatically

**Release-please verification:**
- PR title includes version number
- CHANGELOG.md is generated/updated
- version.txt or equivalent is updated
- PR is mergeable without conflicts

### Repository Structure Verification

**After S3 upload, verify:**
```bash
curl -I https://dist.movealong.org/apt/dists/jammy/Release
curl -I https://dist.movealong.org/apt/dists/noble/Release
curl -I https://dist.movealong.org/apt/dists/bookworm/Release
# ... etc for each codename
```

**Expected:** All return 200 OK

**End-to-end test:**
```bash
docker run -it --rm ubuntu:22.04 bash
# Inside container:
wget https://dist.movealong.org/apt/pool/movealong-repo_3.0.0_all.deb
apt-get update && apt-get install -y lsb-release
dpkg -i movealong-repo_3.0.0_all.deb
apt-get update  # Should succeed without errors
```

---

## Critical Files Summary

**Files to modify:**
- `/home/inkblot/var/src/movealong-repo/debian/control` - Modernize metadata
- `/home/inkblot/var/src/movealong-repo/debian/rules` - Update comments
- `/home/inkblot/var/src/movealong-repo/debian/postinst` - Add detection logic
- `/home/inkblot/var/src/movealong-repo/debian/postrm` - Add cleanup
- `/home/inkblot/var/src/movealong-repo/debian/changelog` - Add 3.0.0 entry
- `/home/inkblot/var/src/movealong-repo/Makefile` - Install template
- `/home/inkblot/var/src/movealong-repo/README` - Comprehensive update

**Files to create:**
- `/home/inkblot/var/src/movealong-repo/movealong.list.template` - Template with ${CODENAME}
- `/home/inkblot/var/src/movealong-repo/.github/workflows/build-test.yml` - Matrix testing
- `/home/inkblot/var/src/movealong-repo/.github/workflows/release-please.yml` - Automated releases
- `/home/inkblot/var/src/movealong-repo/.github/dependabot.yml` - Optional
- `/home/inkblot/var/src/movealong-repo/CONTRIBUTING.md` - Contributor guide

**Files to delete:**
- `/home/inkblot/var/src/movealong-repo/debian/compat` - Deprecated
- `/home/inkblot/var/src/movealong-repo/debian/preinst` - Unnecessary
- `/home/inkblot/var/src/movealong-repo/debian/prerm` - Unnecessary

---

## Conventional Commits Primer

For the team to adopt after implementation:

**Commit format:**
```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types:**
- `feat:` - New feature → Minor version bump (3.0.0 → 3.1.0)
- `fix:` - Bug fix → Patch version bump (3.0.0 → 3.0.1)
- `feat!:` or `fix!:` - Breaking change → Major version bump (3.0.0 → 4.0.0)
- `docs:`, `chore:`, `ci:`, `refactor:`, `test:` → No version bump

**Examples:**
```bash
feat: add support for Ubuntu 24.10
fix: correct postinst codename detection
feat!: require lsb-release package
docs: update README with new distros
chore: update GitHub Actions to v4
```

**Breaking changes:**
- Add `!` after type: `feat!:`
- Or add `BREAKING CHANGE:` in footer

---

## Success Criteria

✅ Package builds cleanly with no lintian errors
✅ All 5 distros pass installation tests in CI
✅ Codename detection works correctly for each distro
✅ release-please creates automated PRs and releases
✅ GitHub Actions matrix builds complete successfully
✅ Package removal cleanly removes all files
✅ Documentation is comprehensive and accurate
✅ S3 repository structure supports distro-specific codenames
✅ Conventional commits workflow is documented
✅ First commit triggers release-please PR creation

---

## Risk Mitigation

**Risk:** S3 repository doesn't have distro-specific directories
**Mitigation:** Create all required dists/ directories before release, or keep stable as fallback

**Risk:** Codename detection fails on minimal systems
**Mitigation:** Multiple fallback mechanisms in postinst (lsb_release → os-release → stable)

**Risk:** Breaking change for users on old systems
**Mitigation:** Version 2.0.0 users will auto-upgrade to 3.0.0 and get correct codename, fallback to stable if detection fails

**Risk:** CI fails due to Docker rate limiting
**Mitigation:** Use GitHub Actions caching, consider GitHub Packages for container registry

**Risk:** release-please doesn't recognize initial commit
**Mitigation:** Use proper conventional commit format for first commit, manually create 3.0.0 tag if needed
