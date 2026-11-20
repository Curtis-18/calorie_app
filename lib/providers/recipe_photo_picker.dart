import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../services/scan_photo.dart';

/// Choose or take a photo and hand back JPEG bytes no larger than 1600 px.
/// Null when the person backs out. Throws if the camera or library can't be opened.
typedef PhotoPicker = Future<Uint8List?> Function(ImageSource source);

Future<Uint8List?> _pickAndShrink(ImageSource source) async {
  final file = await ImagePicker().pickImage(source: source, maxWidth: 1600, maxHeight: 1600, imageQuality: 85);
  if (file == null) return null;
  return shrinkForScan(await file.readAsBytes(), maxSide: 1600);
}

/// Overridden in tests so no camera or library is needed.
final recipePhotoPickerProvider = Provider<PhotoPicker>((ref) => _pickAndShrink);
