import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// The longest side a meal photo is sent at. The model gains nothing from
/// more, and a full camera photo is several MB, which makes the scan slower
/// and the request heavier.
const scanPhotoMaxSide = 1280;

/// Photos at or under this size and dimension are sent as they are.
const _alreadySmallBytes = 1500000;

/// [bytes] scaled so the longest side is at most [maxSide], as a JPEG.
///
/// The phone camera path already asks `image_picker` for this size, but the
/// browser ignores that hint, so a web upload can be a full-size photo. A
/// photo that can't be decoded here (for example HEIC) is returned unchanged:
/// the server accepts it as it is.
Future<Uint8List> shrinkForScan(Uint8List bytes, {int maxSide = scanPhotoMaxSide}) =>
    compute(_shrink, _Job(bytes, maxSide));

class _Job {
  const _Job(this.bytes, this.maxSide);
  final Uint8List bytes;
  final int maxSide;
}

Uint8List _shrink(_Job job) {
  final decoded = img.decodeImage(job.bytes);
  if (decoded == null) return job.bytes;
  final longest = decoded.width > decoded.height ? decoded.width : decoded.height;
  if (longest <= job.maxSide && job.bytes.length <= _alreadySmallBytes) return job.bytes;
  var photo = img.bakeOrientation(decoded);
  if (longest > job.maxSide) {
    photo = photo.width >= photo.height
        ? img.copyResize(photo, width: job.maxSide, interpolation: img.Interpolation.average)
        : img.copyResize(photo, height: job.maxSide, interpolation: img.Interpolation.average);
  }
  return Uint8List.fromList(img.encodeJpg(photo, quality: 80));
}
