# Utility scripts

To make a new release:

* switch to branch `release`
* merge from `master` as appropriate
* run `./utils/mkrelease.sh [major|minor|revision]`

commit-and-tag-version will:

* bump the app version in `pubspec.yaml`
* update CHANGELOG.md with changes
* run `git commit` to edit the commit message
* create a version tag

Verify everything and then just `git push`.
