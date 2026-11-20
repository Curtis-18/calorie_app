import '../l10n/app_strings.dart';
/// Username rules, mirroring the backend (`app/services/username_service.py`)
/// so the picker can say what's wrong while the user types. The server is
/// still the authority.
const int usernameMinLength = 3;
const int usernameMaxLength = 20;

const _reserved = {
  'admin', 'administrator', 'moderator', 'mod', 'support', 'help', 'staff',
  'team', 'official', 'nustreak', 'nu_streak', 'root', 'system', 'security',
  'null', 'undefined', 'anonymous', 'me', 'you', 'everyone', 'all',
};

final _allowed = RegExp(r'^[A-Za-z][A-Za-z0-9_]*$');

/// A friendly reason [raw] can't be a username, or null if it is fine.
String? validateUsername(String raw) {
  final name = raw.trim();
  if (name.length < usernameMinLength) {
    return tr('Usernames need at least {usernameMinLength} characters.', {'usernameMinLength': usernameMinLength});
  }
  if (name.length > usernameMaxLength) {
    return tr('Usernames can be at most {usernameMaxLength} characters.', {'usernameMaxLength': usernameMaxLength});
  }
  if (!RegExp(r'^[A-Za-z]').hasMatch(name)) return tr('Usernames must start with a letter.');
  if (!_allowed.hasMatch(name)) return tr('Use only letters, numbers and underscores.');
  if (name.endsWith('_') || name.contains('__')) {
    return tr("Underscores can't be doubled or go at the end.");
  }
  if (_reserved.contains(name.toLowerCase())) return tr("That name isn't available.");
  return null;
}
