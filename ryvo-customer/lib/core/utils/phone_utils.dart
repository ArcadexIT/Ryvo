/// Digits from a dial code such as `+44`.
String dialDigits(String dialCode) => dialCode.replaceAll(RegExp(r'\D'), '');

/// National digits for [dialCode].
///
/// Autofill and paste often include the country code (`+44 7700 900123` or
/// `447700900123`). Those digits are removed once, then a trunk `0` is
/// dropped. A short value the user is still typing is left unchanged.
String nationalDigits(String dialCode, String raw) {
  final code = dialDigits(dialCode);
  var digits = raw.replaceAll(RegExp(r'\D'), '');
  if (code.isNotEmpty && digits.startsWith(code)) {
    final rest = digits.substring(code.length);
    final includedCode = raw.trimLeft().startsWith('+') || rest.length >= 7;
    if (includedCode && rest.isNotEmpty) digits = rest;
  }
  return digits.replaceFirst(RegExp(r'^0+'), '');
}

/// Dial code plus the national number, without a trunk prefix `0`.
/// `+44` and `07700900123` become `+447700900123`.
String composeE164(String dialCode, String nationalNumber) {
  return normalizePhone('$dialCode${nationalDigits(dialCode, nationalNumber)}');
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
