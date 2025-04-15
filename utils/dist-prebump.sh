#!/bin/bash
# Called as prebump script by commit-and-tag-version.
# Mainly for working around the fact that commit-and-tag-version will not bump versions in ignored files

set -e

cp .gitignore .gitignore~
sed -i '/\.version/d' .gitignore
