#!/bin/sh

set -e

# go to Windows project root
cd "$(dirname "$0")/.."

for size in 16 32 48 256; do
  inkscape --export-type="png" --export-filename="$size.png" -w $size -h $size ../resources/icon.svg
done

convert -background transparent 256.png 48.png 32.png 16.png runner/resources/app_icon.ico
rm -f 16.png 32.png 48.png 256.png
