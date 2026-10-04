import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:int_qa_flow/core/auth/auth_providers.dart';

class SignInPage extends ConsumerStatefulWidget {
  const SignInPage({
    this.linkGuestIdentity = false,
    this.createAccount = false,
    super.key,
  });

  final bool linkGuestIdentity;
  final bool createAccount;

  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<SignInPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _resetMode = false;
  bool _busy = false;
  String? _message;
  String? _error;
  bool _createAccountMode = false;
  bool _linkGuestMode = false;

  @override
  void initState() {
    super.initState();
    _linkGuestMode = widget.linkGuestIdentity;
    _createAccountMode = _linkGuestMode || widget.createAccount;
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      final auth = ref.read(firebaseAuthProvider);
      if (_resetMode) {
        await auth.sendPasswordResetEmail(email: _email.text.trim());
        if (!mounted) return;
        setState(() {
          _message = 'If that account exists, a reset email has been sent.';
        });
      } else if (_createAccountMode && _linkGuestMode) {
        final user = auth.currentUser;
        if (user?.isAnonymous != true) {
          setState(() {
            _error =
                'The guest identity is no longer available. Sign in or create a separate account instead.';
          });
          return;
        }
        final credential = EmailAuthProvider.credential(
          email: _email.text.trim(),
          password: _password.text,
        );
        final linkedCredential = await user!.linkWithCredential(credential);
        final linkedUser = linkedCredential.user ?? user!;
        var verificationEmailFailed = false;
        try {
          if (!linkedUser.emailVerified) {
            await linkedUser.sendEmailVerification();
          }
        } on FirebaseAuthException {
          verificationEmailFailed = true;
        }
        try {
          await linkedUser.reload();
        } on FirebaseAuthException {
          if (!mounted) return;
          await _finishGuestLink(
            'Account created from this guest, but the account status could not be refreshed. The guest identity and group access remain linked. Sign in again to verify the account state.',
          );
          return;
        }
        if (!mounted) return;
        await _finishGuestLink(
          verificationEmailFailed
              ? 'Account created from this guest, but the verification email could not be sent. The guest identity and group access remain linked. Sign in normally and contact your administrator if verification is still pending.'
              : linkedUser.emailVerified
              ? 'Account created from this guest and verified. Group access is retained; local work stays on this device.'
              : 'Account created from this guest. Check your email to verify it. The guest identity and group access are retained; local work stays on this device.',
        );
      } else if (_createAccountMode) {
        if (auth.currentUser?.isAnonymous == true) {
          final switchIdentity = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Create a separate account?'),
              content: const Text(
                'This creates a new signed-in identity and does not transfer '
                'the current guest group membership. Create an account from this '
                'guest instead to keep the same identity and group access. Local '
                'work stays on this device.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel account creation'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Create separate account'),
                ),
              ],
            ),
          );
          if (switchIdentity != true || !mounted) {
            if (switchIdentity == false && mounted) {
              setState(() {
                _message =
                    'Account creation cancelled. Your guest identity, group access, and local work are unchanged.';
              });
            }
            return;
          }
        }
        final credential = await auth.createUserWithEmailAndPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
        final user = credential.user;
        if (user == null) {
          if (!mounted) return;
          setState(() {
            _createAccountMode = false;
            _message =
                'Account created, but email verification could not be started. '
                'Contact your administrator before requesting organisation access.';
          });
          return;
        }
        try {
          await user.sendEmailVerification();
          if (!mounted) return;
          setState(() {
            _createAccountMode = false;
            _message =
                'Account created. Check your email to verify it, then sign out '
                'and sign in again before requesting organisation access. '
                'Account creation does not add organisation membership.';
          });
        } on FirebaseAuthException {
          if (!mounted) return;
          setState(() {
            _createAccountMode = false;
            _message =
                'Account created, but the verification email could not be sent. '
                'Try again later or contact your administrator before requesting '
                'organisation access.';
          });
        }
      } else {
        if (auth.currentUser?.isAnonymous == true) {
          final switchIdentity = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Switch from this guest identity?'),
              content: const Text(
                'Signing in to a different account will not move this guest '
                'group membership. Link a new account for recovery, or transfer '
                'group administration explicitly before switching.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Keep guest identity'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Switch account'),
                ),
              ],
            ),
          );
          if (switchIdentity != true || !mounted) return;
        }
        await auth.signInWithEmailAndPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
      }
    } on FirebaseAuthException catch (error) {
      // Log only a sanitized error code; never credentials or exception details.
      final code = error.code.replaceAll(RegExp(r'[^a-z0-9_-]'), '');
      const diagnostics = bool.fromEnvironment('AUTH_DIAGNOSTICS');
      if (diagnostics) debugPrint('Firebase authentication failed: auth/$code');
      if (!mounted) return;
      final message = switch (code) {
        'email-already-in-use' || 'credential-already-in-use' ||
        'provider-already-linked' =>
          'That account could not be linked. This guest identity remains active; an existing account is never linked or granted group access automatically.',
        'network-request-failed' =>
          'Unable to reach the sign-in service. Check your connection and try again.',
        'too-many-requests' =>
          'Too many sign-in attempts. Please wait before trying again.',
        'invalid-api-key' || 'app-not-authorized' || 'operation-not-allowed' =>
          'Sign-in is unavailable because the application configuration needs attention.',
        'captcha-check-failed' || 'invalid-app-credential' =>
          'Application verification failed. Please contact the development administrator.',
        'invalid-credential' || 'wrong-password' || 'user-not-found' || 'invalid-email' =>
          'Sign-in failed. Check your email and password and try again.',
        _ => 'Sign-in failed. Please try again.',
      };
      setState(() {
        _error = (_resetMode
            ? 'Unable to send a reset email. Please try again.'
            : message) + (diagnostics ? ' [auth/$code]' : '');
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finishGuestLink(String message) async {
    if (!mounted) return;
    setState(() {
      _createAccountMode = false;
      _message = message;
    });
    final navigator = Navigator.of(context);
    if (!navigator.canPop()) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    await navigator.maybePop();
  }

  String _actionLabel() {
    if (_busy) return 'Please wait…';
    if (_resetMode) return 'Send reset email';
    if (!_createAccountMode) return 'Sign in';
    if (!_linkGuestMode) return 'Create a separate account';
    return ref.read(firebaseAuthProvider).currentUser?.isAnonymous == true
        ? 'Create account from this guest'
        : 'Guest identity unavailable';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Card(
                      margin: const EdgeInsets.all(24),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: () =>
                                    Navigator.of(context).maybePop(),
                                icon: const Icon(Icons.arrow_back),
                                label: const Text('Back to guest workspace'),
                              ),
                            ),
                            Text(
                              _resetMode
                                  ? 'Reset password'
                                  : _createAccountMode
                                      ? _linkGuestMode
                                          ? 'Create account from this guest'
                                          : 'Create a separate account'
                                      : 'Sign in to IntQAFlow',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            if (_createAccountMode) ...[
                              const SizedBox(height: 8),
                              Text(
                                _linkGuestMode
                                    ? 'Create a sign-in account from this guest to keep the same identity and group access. Local work stays on this device; it is not uploaded.'
                                    : 'This creates a separate account. It does not transfer guest-group access or upload local work.',
                              ),
                            ],
                            const SizedBox(height: 20),
                            TextField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              decoration: const InputDecoration(
                                labelText: 'Email',
                              ),
                            ),
                            if (!_resetMode) ...[
                              const SizedBox(height: 12),
                              TextField(
                                controller: _password,
                                obscureText: true,
                                autofillHints: const [AutofillHints.password],
                                decoration: const InputDecoration(
                                  labelText: 'Password',
                                ),
                                onSubmitted: (_) => _submit(),
                              ),
                            ],
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                _error!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ],
                            if (_message != null) ...[
                              const SizedBox(height: 12),
                              Text(_message!),
                            ],
                            const SizedBox(height: 20),
                            FilledButton(
                              onPressed: _busy ? null : _submit,
                              child: Text(_actionLabel()),
                            ),
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => setState(() {
                                      if (_resetMode) {
                                        _resetMode = false;
                                      } else if (_createAccountMode) {
                                        _createAccountMode = false;
                                        _linkGuestMode = false;
                                      } else {
                                        _createAccountMode = true;
                                        _linkGuestMode = false;
                                      }
                                      _error = null;
                                      _message = null;
                                    }),
                              child: Text(
                                _resetMode
                                    ? 'Back to sign in'
                                    : _createAccountMode
                                        ? 'Back to sign in'
                                        : 'Create a separate account',
                              ),
                            ),
                            if (!_resetMode && !_createAccountMode)
                              TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => setState(() {
                                        _resetMode = true;
                                        _error = null;
                                        _message = null;
                                      }),
                                child: const Text('Forgot password?'),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
