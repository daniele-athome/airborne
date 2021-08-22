#!/bin/bash

set -e

# go to iOS project root
cd "$(dirname "$0")/.."

inkscape ../resources/icon.svg -w 320 -h 320 --export-filename Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png
inkscape ../resources/icon.svg -w 640 -h 640 --export-filename Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@2x.png
inkscape ../resources/icon.svg -w 960 -h 960 --export-filename Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png
