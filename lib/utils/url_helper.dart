/// Parses a user-entered URL, prefixing `https://` if no scheme was given.
Uri externalUri(String url) {
  final trimmed = url.trim();
  return Uri.parse(trimmed.contains('://') ? trimmed : 'https://$trimmed');
}
