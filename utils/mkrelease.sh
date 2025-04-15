#!/bin/bash

which commit-and-tag-version >/dev/null || exit 1

usage() {
    echo "Usage: $0 [major|minor|patch|first]"
}

check_branch() {
    BRANCH=$1

    CURRENT=$(git rev-parse --abbrev-ref HEAD)
    if [ "${CURRENT}" != "${BRANCH}" ]; then
        echo "Not on ${BRANCH} branch. Aborting."
        return 1
    fi
}

dump_version() {
  version=$(grep -o "version: .*" pubspec.yaml  | awk '{print $2}' | awk -F'+' '{print $1}')
  echo -n "$version" >.version
}

dump_first_version() {
  echo -n '1.0.0' >.version
}

set -e

command="$1"

case "$command" in
  major)
    stdver_args="$stdver_args --release-as major"
    ;;
  minor)
    stdver_args="$stdver_args --release-as minor"
    ;;
  patch)
    stdver_args="$stdver_args --release-as patch"
    ;;
  first)
    stdver_args="$stdver_args --first-release"
    ;;
  "")
    # commit-and-tag-version will decide
    ;;
  *)
    usage
    exit 1
    ;;
esac

check_branch release || exit 1

# prepare version file for commit-and-tag-version (only if not first)
if [ "$command" == "first" ]; then
  dump_first_version
else
  dump_version
fi

# shellcheck disable=SC2086
commit-and-tag-version -a $stdver_args
