class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() {
    final code = statusCode;
    if (code == null) return message;
    return '$message ($code)';
  }
}

/// Pulls the human-readable message out of a server body.
///
/// Nest responses use `message` as a string or a list of validation errors,
/// and sometimes nest the text under `error`.
String? serverErrorMessage(dynamic data) {
  if (data == null) return null;
  if (data is String) {
    final text = data.trim();
    return text.isEmpty ? null : text;
  }
  if (data is List) {
    final parts = data.map(serverErrorMessage).whereType<String>().toList();
    return parts.isEmpty ? null : parts.join('\n');
  }
  if (data is Map) {
    final map = Map<String, dynamic>.from(data);
    final message = serverErrorMessage(map['message']);
    if (message != null) return message;
    final error = map['error'];
    if (error is Map || error is List) return serverErrorMessage(error);
    if (error is String && error.trim().isNotEmpty) return error.trim();
    final errors = serverErrorMessage(map['errors']);
    if (errors != null) return errors;
  }
  return null;
}
