#!/bin/bash
# Applies the patches in patches/ to their packages in the pub cache.
# Must run after "flutter pub get", which is what writes the package config we
# read the package locations from. Safe to run more than once.

set -e

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
patches_dir="$script_dir/patches"
package_config="$(cd "$script_dir/../.." && pwd)/.dart_tool/package_config.json"

patch_pkg() {
  local pkg="$1"
  local patch="$2"
  local dir

  # dark magic to extract the actual path to the dart package in any platform
  dir="$(jq -r --arg p "$pkg" '.packages[] | select(.name==$p) | .rootUri' "$package_config" \
    | sed -e 's|^file:///\([A-Za-z]\):|/\1|' -e 's|^file://||')"
  if [ -z "$dir" ]; then
    echo "::error::package $pkg not found in $package_config"
    return 1
  fi

  if git -C "$dir" apply -R --check -p1 "$patch" 2>/dev/null; then
    echo "$pkg: already patched ($dir)"
    return 0
  fi

  git -C "$dir" apply -p1 "$patch"
  echo "$pkg: patched ($dir)"
}


for pkg_dir in "$patches_dir"/*/; do
  pkg="$(basename "$pkg_dir")"
  [ "$pkg" = flutter ] && continue
  for patch in "$pkg_dir"*.patch; do patch_pkg "$pkg" "$patch"; done
done
