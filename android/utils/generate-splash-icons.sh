#!/bin/bash

set -e

# go to Android project root
cd "$(dirname "$0")/.."

# ldpi (base): 120*1.5
inkscape ../resources/icon.svg -w 180 -h 180 --export-filename app/src/main/res/drawable-ldpi/ic_splash.png
inkscape ../resources/icon.svg -w 240 -h 240 --export-filename app/src/main/res/drawable-mdpi/ic_splash.png
inkscape ../resources/icon.svg -w 360 -h 360 --export-filename app/src/main/res/drawable-hdpi/ic_splash.png
inkscape ../resources/icon.svg -w 480 -h 480 --export-filename app/src/main/res/drawable-xhdpi/ic_splash.png
inkscape ../resources/icon.svg -w 720 -h 720 --export-filename app/src/main/res/drawable-xxhdpi/ic_splash.png
inkscape ../resources/icon.svg -w 960 -h 960 --export-filename app/src/main/res/drawable-xxxhdpi/ic_splash.png
