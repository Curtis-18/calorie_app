import 'dart:typed_data';

import 'package:calorie_app/services/scan_photo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

Uint8List jpeg(int w, int h) {
  final image = img.Image(width: w, height: h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      image.setPixelRgb(x, y, x % 256, y % 256, (x + y) % 256);
    }
  }
  return Uint8List.fromList(img.encodeJpg(image, quality: 95));
}

void main() {
  test('a large landscape photo is scaled so its longest side is 1280', () async {
    final out = await shrinkForScan(jpeg(3000, 2000));
    final decoded = img.decodeJpg(out)!;
    expect(decoded.width, scanPhotoMaxSide);
    expect(decoded.height, closeTo(853, 2));
  });

  test('a large portrait photo is scaled by its height', () async {
    final decoded = img.decodeJpg(await shrinkForScan(jpeg(1500, 3000)))!;
    expect(decoded.height, scanPhotoMaxSide);
    expect(decoded.width, closeTo(640, 2));
  });

  test('a photo that is already small is sent untouched', () async {
    final small = jpeg(800, 600);
    expect(await shrinkForScan(small), small);
  });

  test('bytes that are not a decodable image come back unchanged', () async {
    final junk = Uint8List.fromList(List.generate(200, (i) => i));
    expect(await shrinkForScan(junk), junk);
  });
}
