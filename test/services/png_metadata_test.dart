import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:myroad/services/png_metadata.dart';

Future<Uint8List> _tinyPng() async {
  final pixels = Uint8List.fromList([255, 0, 0, 255]); // 1x1 red pixel, RGBA
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    pixels,
    1,
    1,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  final image = await completer.future;
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'embedPngText round-trips UTF-8 text and stays a decodable PNG',
    () async {
      final png = await _tinyPng();
      const payload = '{"trip":"東京旅行"}';

      final embedded = embedPngText(png, payload);

      expect(extractPngText(embedded), payload);
      expect(extractPngText(png), isNull);

      final codec = await ui.instantiateImageCodec(embedded);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 1);
      expect(frame.image.height, 1);
    },
  );
}
