#!/bin/bash
# Called as postbump script by standard-version.
# At this point, standard-version has bumped the version in the .version file
# So we update pubspec.yaml with the new version and bump the version code (+1)

set -e

new_version="$(cat .version)"
old_version_code=$(grep -o "version: .*" pubspec.yaml  | awk '{print $2}' | awk -F'+' '{print $2}')
new_version_code=$((old_version_code + 1))
sed -i "s/version: \(.*\)/version: $new_version+$new_version_code/" pubspec.yaml
