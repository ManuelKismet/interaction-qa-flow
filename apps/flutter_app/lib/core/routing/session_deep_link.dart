final _detailRoutePattern = RegExp(
  r'^/(questions|guided/sessions|personal/interact/sessions)/[^/]+/?$',
);
const _workspaceRoutes = {
  '/',
  '/organisation',
  '/questions',
  '/guided',
  '/review-queue',
  '/admin',
  '/guest/groups',
  '/personal',
  '/personal/ask',
  '/personal/questions',
  '/personal/interact',
};

bool _isAppRoute(Uri uri) =>
    !uri.hasScheme &&
    !uri.hasAuthority &&
    (_workspaceRoutes.contains(uri.path) ||
        _detailRoutePattern.hasMatch(uri.path));

String sessionDeepLinkInitialLocation(Uri uri) {
  // A hosted hash route takes precedence over the hosting document's path.
  final fragment = uri.fragment;
  if (fragment.startsWith('/')) {
    final hashRoute = Uri.tryParse(fragment);
    return hashRoute != null && _isAppRoute(hashRoute)
        ? _sessionLocation(hashRoute)
        : '/';
  }
  final pathRoute = Uri(path: uri.path, query: uri.hasQuery ? uri.query : null);
  return _isAppRoute(pathRoute) ? _sessionLocation(pathRoute) : '/';
}

String _sessionLocation(Uri uri) =>
    '${uri.path}${uri.hasQuery ? '?${uri.query}' : ''}';
