# TODO

## v3.0.0 Release

### Local
- [X] Review all uncommitted changes
- [X] Build and test locally: `debuild -uc -us && lintian --pedantic --fail-on warning ../movealong-repo_*.deb`
- [X] Test fresh install in Docker (should get distro-specific codename)
- [/] Test upgrade in Docker (should keep `stable`)
- [X] Fill in Vcs-Git and Vcs-Browser URLs in debian/control

### GitHub Setup
- [X] Create GitHub repo
- [X] Add remote and push master branch
- [X] Configure GitHub secrets:
  - `GPG_PRIVATE_KEY` — ASCII-armored private key for inkblot@movealong.org
  - `AWS_ACCESS_KEY_ID`
  - `AWS_SECRET_ACCESS_KEY`
- [X] Verify build-test.yml CI passes on first push

### First Release
- [X] Commit with conventional commit message (e.g. `feat!: modernize package to v3.0.0 with multi-distro support`)
- [ ] Push to master
- [ ] Wait for release-please to open a release PR (updates debian/changelog automatically)
- [ ] Review and merge the release PR
- [ ] Verify publish job: .deb uploaded to GitHub Release, S3 updated for all 7 codenames
- [ ] Verify S3: `curl -I https://dist.movealong.org/apt/dists/{stable,jammy,noble,focal,bullseye,bookworm,trixie}/Release`

## GPG Signing Key Migration

### Phase 1: Ship dual-key package (manual release)
- [X] Generate new passphrase-less signing key (fingerprint: `28FA0CDCB9289CCFA2497190791CE7779788EB53`)
- [X] Update `inkblot-movealong-keyring.gpg` to contain both old and new public keys
- [X] Update `release-please.yml` to sign with new key fingerprint
- [X] Add loopback pinentry + `GPG_PASSPHRASE` support to workflow
- [ ] Add `GPG_PASSPHRASE` GitHub secret (old key's passphrase)
- [ ] Merge `ci-signing-key` branch to master
- [ ] Build locally: `debuild -uc -us`
- [ ] Manually bump version (version.txt, .release-please-manifest.json, CHANGELOG.md, debian/changelog)
- [ ] Upload .deb to GitHub release
- [ ] Upload to S3 with old key for all 7 codenames:
  ```
  CODENAMES="stable jammy noble focal bullseye bookworm trixie"
  DEB="../movealong-repo_<version>_all.deb"
  for codename in $CODENAMES; do
    deb-s3 upload --bucket dist.movealong.org --prefix apt/ \
      --codename "$codename" --preserve-versions \
      --sign 559D7CDB4E302F55C4E88DDB3120F8F824423EDA "$DEB"
  done
  ```
- [ ] Verify: `apt update` succeeds on a test system using the repo

### Phase 2: Switch CI to new key
- [ ] Replace `GPG_PRIVATE_KEY` GitHub secret with contents of `/tmp/new-signing-key.asc`
- [ ] Push a change to trigger release-please CI pipeline
- [ ] Verify CI publish job succeeds (signs with new key)
- [ ] Verify: `apt update` still succeeds on a test system

### Phase 3: Remove old key (future)
- [ ] Remove old public key (`559D7CDB4E302F55C4E88DDB3120F8F824423EDA`) from `inkblot-movealong-keyring.gpg`
- [ ] Release updated package

## Future

- [ ] Cross-publish other packages from `stable` to distro-specific repos
- [ ] Once distro-specific repos are populated, release a version that rewrites `movealong.list` on upgrade too
- [ ] Phase out `stable` codename
