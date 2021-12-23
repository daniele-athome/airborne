#!/bin/sh

which screenshots >/dev/null || exit 1

set -e

if [ "$1" = "android" ]; then
  screenshots -c screenshots_android.yaml
elif [ "$1" = "ios" ]; then
  screenshots -c screenshots_ios.yaml
  for lang in "ios/fastlane/screenshots"/*; do
    for screenshot in "$lang/iPad Pro (12.9-inch) (4th generation)-"*.png; do
      cp -v "$screenshot" "$(echo "$screenshot" | sed 's/4th generation/3rd generation/')"
    done
  done
fi
