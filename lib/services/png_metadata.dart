import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Embeds/extracts arbitrary UTF-8 text (e.g. trip JSON) in a PNG file using a
/// standard iTXt chunk, so exported images can optionally carry the full trip
/// data they were rendered from.
const _keyword = 'myroad-trip';

/// Returns [png] with [text] embedded as a zlib-compressed iTXt chunk placed
/// right after the mandatory IHDR chunk.
Uint8List embedPngText(Uint8List png, String text) {
  final compressed = const ZLibEncoder().encodeBytes(utf8.encode(text));
  final data = BytesBuilder()
    ..add(latin1.encode(_keyword))
    ..addByte(0) // keyword terminator
    ..addByte(1) // compression flag: compressed
    ..addByte(0) // compression method: zlib (only valid option)
    ..addByte(0) // language tag terminator (tag left empty)
    ..addByte(0) // translated keyword terminator (left empty)
    ..add(compressed);
  final chunk = _buildChunk('iTXt', data.toBytes());

  // IHDR is always the first chunk and always has a fixed 13-byte payload,
  // so its end offset is constant: signature(8) + length(4) + type(4) + data(13) + crc(4).
  const ihdrEnd = 8 + 8 + 13 + 4;
  return Uint8List.fromList([...png.sublist(0, ihdrEnd), ...chunk, ...png.sublist(ihdrEnd)]);
}

/// Returns the text embedded by [embedPngText], or null if [png] has none.
String? extractPngText(Uint8List png) {
  var offset = 8;
  while (offset + 12 <= png.length) {
    final length = ByteData.sublistView(png, offset, offset + 4).getUint32(0);
    final type = ascii.decode(png.sublist(offset + 4, offset + 8));
    final dataStart = offset + 8;
    if (type == 'IEND') break;
    if (type == 'iTXt') {
      final data = png.sublist(dataStart, dataStart + length);
      final keywordEnd = data.indexOf(0);
      if (keywordEnd >= 0 && latin1.decode(data.sublist(0, keywordEnd)) == _keyword) {
        final compressed = data[keywordEnd + 1] == 1;
        final langEnd = data.indexOf(0, keywordEnd + 3);
        final transEnd = data.indexOf(0, langEnd + 1);
        final textBytes = data.sublist(transEnd + 1);
        final raw = compressed ? const ZLibDecoder().decodeBytes(textBytes) : textBytes;
        return utf8.decode(raw);
      }
    }
    offset = dataStart + length + 4; // skip data + crc
  }
  return null;
}

Uint8List _buildChunk(String type, Uint8List data) {
  final typeBytes = ascii.encode(type);
  final crc = getCrc32(Uint8List.fromList([...typeBytes, ...data]));
  return Uint8List.fromList([
    ..._uint32(data.length),
    ...typeBytes,
    ...data,
    ..._uint32(crc),
  ]);
}

Uint8List _uint32(int value) => (ByteData(4)..setUint32(0, value)).buffer.asUint8List();