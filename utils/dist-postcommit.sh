#!/bin/bash
# Called as prebump script by commit-and-tag-version.
# Mainly for working around the fact that commit-and-tag-version will not bump versions in ignored files

set -e

git log -1 --format=%s > .git/COMMIT_LASTMSG
git reset --soft HEAD^
# restore what prebump did
mv .gitignore~ .gitignore
git restore --staged .version
git commit -a -F .git/COMMIT_LASTMSG
