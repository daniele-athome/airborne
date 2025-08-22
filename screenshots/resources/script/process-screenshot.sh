#!/usr/bin/env bash
# Usage: ./process-screenshot.sh filename.png <android|ios> <device> <locale> <orientation>
# This script is meant to be executed by the screenshots test driver

set -euo pipefail

get_screen_property() {
  local platform="$1"
  local device="$2"
  local property="$3"
  yq -r '.'"$platform"'.["'"$device"'"].'"$property" < resources/screens.yaml
}

# final path to the screenshots for the given device type and model.
# the path will contain "%s" to be replaced with the input filename
get_screenshot_path() {
  local platform="$1"
  local device="$2"
  local locale="$3"
  local devtype

  case "$platform" in
    android)
      devtype="$(get_screen_property "$platform" "$device" "destName")"
      echo "android/fastlane/metadata/android/$locale/images/${devtype}Screenshots/${device}-${orientation}-%s"
      ;;
    ios)
      echo "ios/fastlane/screenshots/$locale/${device}-${orientation}-%s"
      ;;
  esac
}

die() {
  echo "$@" >&2
  exit 1
}

cleanup() {
  [[ -d "$tempdir" ]] && rm -fr "$tempdir"
}

tempdir="$(mktemp -d --tmpdir screenshot.XXXXX)"

trap cleanup EXIT

[[ "$#" -lt "5" ]] && die "Not enough arguments."

image_file="$1"
platform="$2"
device="$3"
locale="$4"
orientation="$5"

image_size="$(get_screen_property "$platform" "$device" "size")"

if [[ "$image_size" == "" || "$image_size" == "null" ]]; then
  die "Device $device not found."
fi

# resize to screen size
convert -resize "$image_size" "$image_file" "$tempdir/resized.png"

# overlay status bar
statusbar_file="$(get_screen_property "$platform" "$device" "resources.statusbar")"
convert "$tempdir/resized.png" "$statusbar_file" -gravity north -composite "$tempdir/with_statusbar.png"

screenshot_path="$(get_screenshot_path "$platform" "$device" "$locale" "$orientation")"
# shellcheck disable=SC2059
cp "$tempdir/with_statusbar.png" "../$(printf "$screenshot_path" "$(basename "$image_file")")"
