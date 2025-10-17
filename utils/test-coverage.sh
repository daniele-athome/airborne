#!/usr/bin/env sh

set -e

cd "$(dirname "$0")/.."

flutter test --no-pub -r expanded --coverage
lcov -r coverage/lcov.info 'lib/generated/**' -o coverage/lcov.info
genhtml coverage/lcov.info -o coverage/html
