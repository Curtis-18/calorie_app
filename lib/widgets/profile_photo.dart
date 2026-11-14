import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../screens/friends_screen.dart' show FriendAvatar;
import '../services/avatar_service.dart';
import '../theme/tracker_colors.dart';
import 'app_dialog.dart';
import 'pressable.dart';

/// Your own picture, with a camera badge: tap to take a photo, choose one
/// from the library, or go back to the coloured initial.
class ProfilePhotoButton extends StatefulWidget {
  const ProfilePhotoButton({
    super.key,
    required this.username,
    this.imageUrl,
    this.onChanged,
    this.service,
    this.pick,
    this.prepare,
    this.size = 60,
  });

  final String username;
  final String? imageUrl;

  /// Called after the picture was saved or removed, so lists can refresh.
  final VoidCallback? onChanged;
  final AvatarService? service;

  /// Replace the camera/library and the resize step; for tests.
  final Future<XFile?> Function(ImageSource source)? pick;
  final Future<Uint8List> Function(Uint8List photo)? prepare;
  final double size;

  @override
  State<ProfilePhotoButton> createState() => _ProfilePhotoButtonState();
}

class _ProfilePhotoButtonState extends State<ProfilePhotoButton> {
  late final AvatarService _service = widget.service ?? AvatarService();
  bool _busy = false;

  /// What was just uploaded, shown until the new link arrives from the server.
  Uint8List? _fresh;
  bool _removed = false;

  bool get _hasPhoto => _fresh != null || (!_removed && widget.imageUrl != null);

  @override
  void didUpdateWidget(ProfilePhotoButton old) {
    super.didUpdateWidget(old);
    // The server has caught up: trust its answer again.
    if (old.imageUrl != widget.imageUrl) _removed = false;
  }

  Future<XFile?> _pick(ImageSource source) =>
      ImagePicker().pickImage(source: source, maxWidth: 1600, maxHeight: 1600, imageQuality: 90);

  Future<void> _fail(String title, String message) async {
    if (!mounted) return;
    await showAppDialog(context: context, title: title, message: message);
  }

  Future<void> _choose() async {
    if (_busy) return;
    final choice = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Profile photo'),
        message: const Text('Your friends, and people you send a friend request to, can see it.'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, 'camera'),
            child: const Text('Take a photo'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, 'library'),
            child: const Text('Choose from library'),
          ),
          if (_hasPhoto)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(context, 'remove'),
              child: const Text('Remove photo'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == 'remove') return _remove();

    final source = choice == 'camera' ? ImageSource.camera : ImageSource.gallery;
    final XFile? file;
    try {
      file = await (widget.pick ?? _pick)(source);
    } catch (_) {
      return _fail(
        source == ImageSource.camera ? "Couldn't open the camera" : "Couldn't open your photos",
        'Allow access in Settings, then try again.',
      );
    }
    if (file == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final Uint8List photo;
      try {
        photo = await (widget.prepare ?? prepareAvatar)(await file.readAsBytes());
      } catch (_) {
        await _fail("That photo can't be used", 'Try a different one.');
        return;
      }
      await _service.upload(photo);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _fresh = photo;
        _removed = false;
      });
      widget.onChanged?.call();
    } on AvatarException catch (e) {
      await _fail("Couldn't save your photo", e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    setState(() => _busy = true);
    try {
      await _service.remove();
      if (!mounted) return;
      setState(() {
        _fresh = null;
        _removed = true;
      });
      widget.onChanged?.call();
    } on AvatarException catch (e) {
      await _fail("Couldn't remove your photo", e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final fresh = _fresh;
    return Semantics(
      button: true,
      label: _hasPhoto ? 'Change profile photo' : 'Add a profile photo',
      child: Pressable(
        onTap: _choose,
        child: SizedBox(
          width: size + 4,
          height: size + 4,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                child: fresh != null
                    ? ClipOval(
                        child: Image.memory(fresh, width: size, height: size, fit: BoxFit.cover, gaplessPlayback: true),
                      )
                    : FriendAvatar(
                        username: widget.username,
                        size: size,
                        imageUrl: _removed ? null : widget.imageUrl,
                      ),
              ),
              if (_busy)
                Positioned(
                  left: 0,
                  top: 0,
                  child: Container(
                    width: size,
                    height: size,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x88000000)),
                    child: const CupertinoActivityIndicator(color: Color(0xFFFFFFFF)),
                  ),
                ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: TrackerColors.calorieGradient,
                    border: Border.all(color: TrackerColors.background, width: 2),
                  ),
                  child: Icon(CupertinoIcons.camera_fill, size: 11, color: TrackerColors.onAccent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
