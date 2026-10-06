import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:int_qa_flow/core/auth/auth_providers.dart';

class SignInPage extends ConsumerStatefulWidget {
  const SignInPage({
    this.createAccount = false,
    super.key,
  });

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

  @override
  void initState() {
    super.initState();
    _createAccountMode = widget.createAccount;
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final isResetOperation = _resetMode;
    final isAccountCreation = _createAccountMode;
    final email = _email.text.trim();
    final password = _password.text;
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    final auth = ref.read(firebaseAuthProvider);
    try {
      if (_resetMode) {
        await auth.sendPasswordResetEmail(email: email);
        if (!mounted) return;
        setState(() {
          _message = 'If that account exists, a reset email has been sent.';
        });
      } else if (_createAccountMode) {
        final credential = await auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        final user = credential.user;
        if (user == null) {
          if (!mounted) return;
          setState(() {
            _createAccountMode = false;
            _message =
                'Personal account created, but email verification could not be '
                'started. Local work is unchanged; try again later.';
          });
          return;
        }
        try {
          await user.sendEmailVerification();
          if (!mounted) return;
          setState(() {
            _createAccountMode = false;
            _message = 'Personal account created. Check your email to verify '
                'it. Your local work remains on this device; nothing is uploaded '
                'unless you choose items to import after verification.';
          });
        } on FirebaseAuthException {
          if (!mounted) return;
          setState(() {
            _createAccountMode = false;
            _message = 'Personal account created, but the verification email '
                'could not be sent. Local work remains on this device. Try again '
                'later or request a new verification email.';
          });
        }
      } else {
        await auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
    } on FirebaseAuthException catch (error) {
      // Log only a sanitized error code; never credentials or exception details.
      final code = error.code
          .toLowerCase()
          .split('/')
          .last
          .replaceAll(RegExp(r'[^a-z0-9_-]'), '');
      const diagnostics = bool.fromEnvironment('AUTH_DIAGNOSTICS');
      if (diagnostics) {
        final app = auth.app;
        final projectId = app.options.projectId;
        debugPrint(
          'Firebase authentication failed: auth/$code '
          '(app=${app.name}, project=$projectId)',
        );
      }
      if (!mounted) return;
      final message = isResetOperation
          ? 'Unable to send a reset email. Please check the address and try again.'
          : isAccountCreation
          ? switch (code) {
              'email-already-in-use' =>
                'An account already uses this email. Sign in or reset the password instead.',
              'weak-password' =>
                'Choose a stronger password and try creating the account again.',
              'invalid-email' => 'Enter a valid email address to create an account.',
              'network-request-failed' =>
                'Unable to reach the account service. Check your connection and try again.',
              'too-many-requests' =>
                'Too many account-creation attempts. Please wait before trying again.',
              'invalid-api-key' ||
              'app-not-authorized' ||
              'operation-not-allowed' =>
                'Account creation is unavailable because the application configuration needs attention.',
              'captcha-check-failed' || 'invalid-app-credential' =>
                'Application verification failed. Please contact the development administrator.',
              _ => 'Unable to create the account. Check the details and try again.',
            }
          : switch (code) {
              'network-request-failed' =>
                'Unable to reach the sign-in service. Check your connection and try again.',
              'too-many-requests' =>
                'Too many sign-in attempts. Please wait before trying again.',
              'invalid-api-key' ||
              'app-not-authorized' ||
              'operation-not-allowed' =>
                'Sign-in is unavailable because the application configuration needs attention.',
              'captcha-check-failed' || 'invalid-app-credential' =>
                'Application verification failed. Please contact the development administrator.',
              'invalid-credential' ||
              'wrong-password' ||
              'user-not-found' ||
              'invalid-email' =>
                'Sign-in failed. Check your email and password and try again.',
              'weak-password' =>
                'This password cannot be used to create an account. Choose a stronger password.',
              _ => 'Sign-in failed. Please try again.',
            };
      setState(() {
        _error = message + (diagnostics ? ' [auth/$code]' : '');
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to complete this account request. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _actionLabel() {
    if (_busy) return 'Please wait…';
    if (_resetMode) return 'Send reset email';
    if (!_createAccountMode) return 'Sign in';
    return 'Create account';
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
                                label: const Text('Back to workspace'),
                              ),
                            ),
                            Text(
                              _resetMode
                                  ? 'Reset password'
                                  : _createAccountMode
                                      ? 'Create a personal account'
                                      : 'Sign in to IntQAFlow',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            if (_createAccountMode) ...[
                              const SizedBox(height: 8),
                              Text(
                                'A personal account is separate from local '
                                'work. Nothing is uploaded unless you choose '
                                'items to import.',
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
                                      } else {
                                        _createAccountMode = true;
                                      }
                                      _error = null;
                                      _message = null;
                                    }),
                              child: Text(
                                _resetMode
                                    ? 'Back to sign in'
                                    : _createAccountMode
                                        ? 'Back to sign in'
                                        : 'Create a personal account',
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
