import 'browser_push_base.dart';

BrowserPush createBrowserPush() => _NoBrowserPush();

/// Phone builds and tests: no browser, so nothing to do.
class _NoBrowserPush implements BrowserPush {
  @override
  bool get supported => false;
  @override
  bool get needsHomeScreenInstall => false;
  @override
  String get permission => 'denied';
  @override
  Future<String?> subscribe(String publicKey) async => null;
  @override
  Future<String?> currentSubscription() async => null;
  @override
  Future<void> unsubscribe() async {}
}
