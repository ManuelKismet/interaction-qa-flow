final _sessionRoutePattern = RegExp(r'^/guided/sessions/[^/]+/?$');

String sessionDeepLinkInitialLocation(Uri uri) {
  if (_sessionRoutePattern.hasMatch(uri.path)) {
    return _sessionLocation(uri);
  }

  final fragment = uri.fragment;
  if (!fragment.startsWith('/')) return '/';
  final hashRoute = Uri.parse(fragment);
  if (!_sessionRoutePattern.hasMatch(hashRoute.path)) return '/';
  return _sessionLocation(hashRoute);
}

String _sessionLocation(Uri uri) =>
    '${uri.path}${uri.hasQuery ? '?${uri.query}' : ''}';
