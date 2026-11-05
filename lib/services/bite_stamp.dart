import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:image/image.dart' as img;

import '../models/bite_meal.dart';

/// Width every bite is sent at. Matches the 4:5 frame the camera shows.
const biteWidth = 1080;
const biteHeight = 1350;

/// Turn a raw camera photo into what gets sent: baked-in rotation, cropped to
/// the 4:5 frame the person saw, 1080 wide, JPEG, with the meal stamped in the
/// bottom-left corner when [meal] is set.
///
/// The stamp is drawn into the photo itself, so it survives however the bite
/// is stored or viewed and the server needs no changes.
Future<Uint8List> prepareBite(Uint8List photo, BiteMeal? meal) async {
  final pill = meal == null ? null : await _renderPill(meal.label);
  return compute(_compose, _Job(photo, pill));
}

class _Job {
  const _Job(this.photo, this.pill);
  final Uint8List photo;
  final Uint8List? pill;
}

Uint8List _compose(_Job job) {
  final decoded = img.decodeImage(job.photo);
  if (decoded == null) throw const FormatException('Not an image');
  var photo = img.bakeOrientation(decoded);

  // Centre-crop to 4:5.
  final targetRatio = biteWidth / biteHeight;
  final ratio = photo.width / photo.height;
  if ((ratio - targetRatio).abs() > 0.001) {
    if (ratio > targetRatio) {
      final w = (photo.height * targetRatio).round();
      photo = img.copyCrop(photo, x: (photo.width - w) ~/ 2, y: 0, width: w, height: photo.height);
    } else {
      final h = (photo.width / targetRatio).round();
      photo = img.copyCrop(photo, x: 0, y: (photo.height - h) ~/ 2, width: photo.width, height: h);
    }
  }
  if (photo.width != biteWidth) {
    photo = img.copyResize(photo, width: biteWidth, height: biteHeight, interpolation: img.Interpolation.average);
  }

  final pillBytes = job.pill;
  if (pillBytes != null) {
    final pill = img.decodePng(pillBytes);
    if (pill != null) {
      final margin = (biteWidth * 0.05).round();
      img.compositeImage(photo, pill, dstX: margin, dstY: biteHeight - pill.height - margin);
    }
  }
  return Uint8List.fromList(img.encodeJpg(photo, quality: 85));
}

/// The stamp itself: a dark rounded pill with a lime dot and the meal name,
/// sized for a [biteWidth]-wide photo.
Future<Uint8List> _renderPill(String label) async {
  const fontSize = 46.0;
  const padX = 30.0, padY = 18.0, dot = 16.0, gap = 14.0;
  final text = TextPainter(
    text: TextSpan(
      text: label,
      style: const TextStyle(
        color: Color(0xFFFFFFFF),
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        fontFamily: 'CupertinoSystemText',
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  final w = padX + dot + gap + text.width + padX;
  final h = text.height + padY * 2;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRRect(
    RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), Radius.circular(h / 2)),
    Paint()..color = const Color(0xA6000000),
  );
  canvas.drawCircle(Offset(padX + dot / 2, h / 2), dot / 2, Paint()..color = const Color(0xFF7CF542));
  text.paint(canvas, Offset(padX + dot + gap, padY));
  final image = await recorder.endRecording().toImage(w.ceil(), h.ceil());
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}
