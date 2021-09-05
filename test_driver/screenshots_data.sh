#!/bin/sh
# Regenerates the screenshots data source file.

INPUT="$(dirname "$0")/screenshots_data.zip"
OUTPUT="$(dirname "$0")/screenshots_data.dart"

cat >"$OUTPUT" <<EOF
// Automatically generated from $(basename "$INPUT"). DO NOT EDIT.
import 'dart:typed_data';

final kScreenshotsData = Uint8List.fromList(<int>[
EOF

hexdump -e '16/1 "0x%02x_" "\n"' "$INPUT" | sed 's/_/, /g; s/.*/    &/' >>"$OUTPUT"

cat >>"$OUTPUT" <<EOF
]);
EOF
