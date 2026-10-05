import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:int_qa_flow/core/auth/auth_providers.dart';

class SignInPage extends ConsumerStatefulWidget {
  const SignInPage({
    this.linkGuestIdentity = false,
    this.createAccount = false,
    this.hasMeaningfulGuestWork = false,
    this.hasCurrentGuestGroupAccess = false,
    this.hasArchivedGuestGroups = false,
    this.hasSoleAdministeredGroup = false,
    this.guestGroupOwnershipUnavailable = false,
    super.key,
  });

  final bool linkGuestIdentity;
  final bool createAccount;
  final bool hasMeaningfulGuestWork;
  final bool hasCurrentGuestGroupAccess;
  final bool hasArchivedGuestGroups;
  final bool hasSoleAdministeredGroup;
  final bool guestGroupOwnershipUnavailable;

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
    final isResetOperation = _resetMode;
    final isSeparateAccountCreation = _createAccountMode && !_linkGuestMode;
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
          email: email,
          password: password,
        );
        final linkedCredential = await user!.linkWithCredential(credential);
        final linkedUser = linkedCredential.user ?? user;
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
        final currentUser = auth.currentUser;
        if ((currentUser?.isAnonymous == true ||
                _hasMeaningfulCurrentGuestState) &&
            !await _confirmCurrentGuestState(
              auth,
              currentUser,
              createSeparateAccount: true,
            )) {
          return;
        }
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
        final currentUser = auth.currentUser;
        if ((currentUser?.isAnonymous == true ||
                (currentUser == null && _hasMeaningfulCurrentGuestState)) &&
            !await _confirmCurrentGuestState(
              auth,
              currentUser,
              createSeparateAccount: false,
            )) {
          return;
        }
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
          : isSeparateAccountCreation
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
              'email-already-in-use' ||
              'credential-already-in-use' ||
              'provider-already-linked' =>
                'That account could not be linked. This guest identity remains active; an existing account is never linked or granted group access automatically.',
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
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool get _hasMeaningfulCurrentGuestState =>
      widget.hasMeaningfulGuestWork ||
      widget.hasCurrentGuestGroupAccess ||
      widget.hasArchivedGuestGroups;

  Future<bool> _confirmCurrentGuestState(
    FirebaseAuth auth,
    User? currentUser, {
    required bool createSeparateAccount,
  }) async {
    if (widget.guestGroupOwnershipUnavailable ||
        widget.hasSoleAdministeredGroup) {
      final message = widget.guestGroupOwnershipUnavailable
          ? 'Shared-group administration could not be checked, so sign-in and '
                'separate-account creation are paused to protect group access. '
                'Keep this identity and retry after shared groups are available.'
          : 'This identity is the only administrator of at least one shared '
                'group. Keep this identity, or return to Shared groups → Manage '
                'members to request a transfer and wait for an active member to '
                'accept, or archive the group before leaving it. An archived group '
                'can be restored for 30 days only by this same Firebase identity.';
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Keep this shared-group identity'),
            content: Text(message),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Keep this identity'),
              ),
            ],
          ),
        );
      }
      return false;
    }

    if (!_hasMeaningfulCurrentGuestState) return true;

    final currentUid = currentUser?.uid;
    final wasAnonymous = currentUser?.isAnonymous == true;
    final archivedGroupWarning = widget.hasArchivedGuestGroups
        ? ' Archived groups can be restored for 30 days only by the same '
              'Firebase account that archived them; starting fresh does not '
              'transfer restoration rights.'
        : '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          createSeparateAccount
              ? 'Start fresh with a separate account?'
              : 'Sign in to your existing account?',
        ),
        content: Text(
          (createSeparateAccount
              ? 'This starts a separate registered identity. The current guest '
                    'workspace is different from that new account: local work '
                    'stays in this browser unless you explicitly clear only its '
                    'local copy from Workspace options. Shared-group membership '
                    'or administration does not transfer or get deleted. To keep '
                    'group access, create an account from this guest instead.'
              : 'This signs in to your existing account; it does not upgrade '
                    'the current guest identity. Local work stays in this browser. '
                    'Keep it, or explicitly clear only the local copy from '
                    'Workspace options; sign-in never clears it. Shared-group '
                    'membership and ownership stay with the current identity and '
                    'are not transferred.') +
              archivedGroupWarning,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              createSeparateAccount
                  ? 'Cancel account creation'
                  : currentUser?.isAnonymous == true
                  ? 'Keep guest workspace'
                  : 'Keep local workspace',
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              createSeparateAccount ? 'Start fresh' : 'Continue to sign in',
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      if (confirmed == false && createSeparateAccount && mounted) {
        setState(() {
          _message = currentUser?.isAnonymous == true
              ? 'Account creation cancelled. Your guest identity, group access, and local work are unchanged.'
              : 'Account creation cancelled. Your current workspace and local work are unchanged.';
        });
      }
      return false;
    }
    if (auth.currentUser?.uid != currentUid ||
        (auth.currentUser?.isAnonymous == true) != wasAnonymous) {
      setState(() {
        _error =
            'The current identity changed while confirming. No account action was started.';
      });
      return false;
    }
    return true;
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
                                      ? 'Create a sign-in account from this guest to keep the same identity and group access. '
                                          'Local work stays on this device; it is not uploaded.'
                                      : 'Start fresh with a separate registered identity. '
                                          'It does not transfer shared-group access or upload local work; '
                                          'local work remains on this device.',
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
