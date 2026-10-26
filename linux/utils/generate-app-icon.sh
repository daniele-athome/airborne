#!/bin/sh

set -e

# go to Linux project root
cd "$(dirname "$0")/.."

for size in 16 22 24 32 48 64 128 256 512; do
  dir="share/icons/hicolor/${size}x${size}/apps"
  mkdir -p "$dir"
  inkscape --export-type="png" --export-filename="$dir/it.casaricci.airborne.png" -w $size -h $size ../resources/icon.svg
done
