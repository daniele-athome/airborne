#!/bin/sh

cat <<EOF
// Automatically generated. DO NOT EDIT.
import 'dart:typed_data';

final kTestAircraftData = Uint8List.fromList(<int>[
EOF

hexdump -e '16/1 "0x%02x_" "\n"' | sed 's/0x  _//g'| sed 's/_/, /g; s/.*/    &/'

cat <<EOF
]);
EOF
