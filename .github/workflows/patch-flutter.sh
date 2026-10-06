#!/bin/bash
# Applies the patches in patches/flutter/ to the Flutter SDK, which the setup
# action points FLUTTER_ROOT at. Safe to run more than once.

set -e

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
patches_dir="$script_dir/patches/flutter"

if [ -z "${FLUTTER_ROOT:-}" ]; then
  echo "::error::FLUTTER_ROOT is not set"
  exit 1
fi

shopt -s nullglob
patches=("$patches_dir"/*.patch)

if [ ${#patches[@]} -eq 0 ]; then
  echo "no SDK patch to apply"
  exit 0
fi

for patch_file in "${patches[@]}"; do
  name="$(basename "$patch_file")"

  if git -C "$FLUTTER_ROOT" apply -R --check -p1 "$patch_file" 2>/dev/null; then
    echo "$name: already applied"
    continue
  fi

  git -C "$FLUTTER_ROOT" apply -p1 "$patch_file"
  echo "$name: applied"
done
