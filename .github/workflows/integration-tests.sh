#!/bin/bash

set -e

# due to a bug in Flutter, we cannot just pass the whole directory to "flutter test"
for test_file in integration_test/*_test.dart; do
  flutter test --no-pub -d "$1" -r github "$test_file"
done
