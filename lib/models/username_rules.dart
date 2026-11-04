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
    return 'Usernames need at least $usernameMinLength characters.';
  }
  if (name.length > usernameMaxLength) {
    return 'Usernames can be at most $usernameMaxLength characters.';
  }
  if (!RegExp(r'^[A-Za-z]').hasMatch(name)) return 'Usernames must start with a letter.';
  if (!_allowed.hasMatch(name)) return 'Use only letters, numbers and underscores.';
  if (name.endsWith('_') || name.contains('__')) {
    return "Underscores can't be doubled or go at the end.";
  }
  if (_reserved.contains(name.toLowerCase())) return "That name isn't available.";
  return null;
}
