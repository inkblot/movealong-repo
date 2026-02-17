# TODO

## v3.0.0 Release

### Local
- [X] Review all uncommitted changes
- [ ] Build and test locally: `debuild -uc -us && lintian --pedantic --fail-on warning ../movealong-repo_*.deb`
- [ ] Test fresh install in Docker (should get distro-specific codename)
- [ ] Test upgrade in Docker (should keep `stable`)
- [ ] Fill in Vcs-Git and Vcs-Browser URLs in debian/control

### GitHub Setup
- [ ] Create GitHub repo
- [ ] Add remote and push master branch
- [ ] Configure GitHub secrets:
  - `GPG_PRIVATE_KEY` — ASCII-armored private key for inkblot@movealong.org
  - `AWS_ACCESS_KEY_ID`
  - `AWS_SECRET_ACCESS_KEY`
- [ ] Verify build-test.yml CI passes on first push

### First Release
- [ ] Commit with conventional commit message (e.g. `feat!: modernize package to v3.0.0 with multi-distro support`)
- [ ] Push to master
- [ ] Wait for release-please to open a release PR (updates debian/changelog automatically)
- [ ] Review and merge the release PR
- [ ] Verify publish job: .deb uploaded to GitHub Release, S3 updated for all 7 codenames
- [ ] Verify S3: `curl -I https://dist.movealong.org/apt/dists/{stable,jammy,noble,focal,bullseye,bookworm,trixie}/Release`

## Future

- [ ] Cross-publish other packages from `stable` to distro-specific repos
- [ ] Once distro-specific repos are populated, release a version that rewrites `movealong.list` on upgrade too
- [ ] Phase out `stable` codename
