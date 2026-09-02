import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

/// A 1x1 transparent PNG: the cheapest thing that decodes to a real image.
final Uint8List kTransparentPixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR42mNkYAAAAAYAAjhRTaMAAAAASUVORK5CYII=',
);

/// An [ImageProvider] that resolves without touching filesystem or network.
///
/// The [key] only serves to make two fake images distinguishable: the pixels
/// are always the same.
@immutable
class FakeImage extends MemoryImage {
  FakeImage(this.key) : super(kTransparentPixelPng);

  final String key;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is FakeImage && other.key == key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => 'FakeImage($key)';
}
