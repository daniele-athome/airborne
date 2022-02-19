#!/bin/bash
# Called as prebump script by standard-version.
# Mainly for working around the fact that standard-version will not bump versions in ignored files

set -e

cp .gitignore .gitignore~
sed -i '/\.version/d' .gitignore
