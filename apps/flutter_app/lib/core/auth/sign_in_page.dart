import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:int_qa_flow/core/auth/auth_providers.dart';

class SignInPage extends ConsumerStatefulWidget {
  const SignInPage({super.key});

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
        setState(() {
          _message = 'If that account exists, a reset email has been sent.';
        });
      } else {
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

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
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
                    Text(
                      _resetMode ? 'Reset password' : 'Sign in to IntQAFlow',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(labelText: 'Email'),
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
                      Text(_error!, style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      )),
                    ],
                    if (_message != null) ...[
                      const SizedBox(height: 12),
                      Text(_message!),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: Text(
                        _busy
                            ? 'Please wait…'
                            : _resetMode
                                ? 'Send reset email'
                                : 'Sign in',
                      ),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                                _resetMode = !_resetMode;
                                _error = null;
                                _message = null;
                              }),
                      child: Text(
                        _resetMode ? 'Back to sign in' : 'Forgot password?',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
