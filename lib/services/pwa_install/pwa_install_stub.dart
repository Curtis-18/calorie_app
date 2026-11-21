import 'pwa_install_base.dart';

PwaInstall createPwaInstall() => _NoInstall();

/// Phone builds and tests: nothing to install.
class _NoInstall implements PwaInstall {
  @override
  InstallMode get mode => InstallMode.none;
  @override
  Stream<void> get changes => const Stream.empty();
  @override
  Future<bool> prompt() async => false;
}
