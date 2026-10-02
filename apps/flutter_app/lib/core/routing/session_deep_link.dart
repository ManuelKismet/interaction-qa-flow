String sessionDeepLinkInitialLocation(Uri uri) {
  if (!RegExp(r'^/guided/sessions/[^/]+/?$').hasMatch(uri.path)) return '/';
  return '${uri.path}${uri.hasQuery ? '?${uri.query}' : ''}';
}
