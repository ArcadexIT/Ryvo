/// Dial code plus the national number, without a trunk prefix `0`.
/// `+44` and `07700900123` become `+447700900123`.
String composeE164(String dialCode, String nationalNumber) {
  var digits = nationalNumber.trim().replaceAll(RegExp(r'\D'), '');
  digits = digits.replaceFirst(RegExp(r'^0+'), '');
  return normalizePhone('$dialCode$digits');
}

/// Normalizes user input to E.164 format expected by the RYVO API.
String normalizePhone(String input) {
  final trimmed = input.trim();
  if (trimmed.startsWith('+')) return trimmed;

  final digits = trimmed.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 11 && digits.startsWith('1')) {
    return '+$digits';
  }
  if (digits.length == 10) {
    return '+1$digits';
  }
  return '+$digits';
}
