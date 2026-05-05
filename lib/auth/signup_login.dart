import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_prefs.dart';
import 'verification_email_service.dart';

class SignupLogin extends StatefulWidget {
  const SignupLogin({super.key, this.initialIsLogin = true});

  final bool initialIsLogin;

  @override
  State<SignupLogin> createState() => _SignupLoginState();
}

class _SignupLoginState extends State<SignupLogin> {
  static const String _passwordResetContinueUrl =
      'https://lifelens.app/reset-password';
  static const String _androidPackageName = 'com.example.lifelens';

  late bool isLogin;
  bool _isSubmitting = false;

  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _signupUsernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final ValueNotifier<bool> _rememberMe = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _hidePassword = ValueNotifier<bool>(true);
  final ValueNotifier<bool> _hideConfirm = ValueNotifier<bool>(true);

  @override
  void initState() {
    super.initState();
    isLogin = widget.initialIsLogin;
    _loadRememberedLogin();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _signupUsernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _rememberMe.dispose();
    _hidePassword.dispose();
    _hideConfirm.dispose();
    super.dispose();
  }

  Future<void> _loadRememberedLogin() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final savedRememberMe = prefs.getBool(kRememberMeKey) ?? false;
    final savedEmail = prefs.getString(kRememberedEmailKey) ?? '';
    final nextEmail = savedRememberMe && savedEmail.isNotEmpty
        ? savedEmail
        : '';

    if (_rememberMe.value == savedRememberMe &&
        _emailController.text == nextEmail) {
      return;
    }

    _rememberMe.value = savedRememberMe;
    _emailController.text = nextEmail;
  }

  String _normalizeUsername(String input) {
    var value = input.trim();
    if (value.startsWith('@')) {
      value = value.substring(1);
    }
    return value;
  }

  String _usernameLookupKey(String input) {
    return _normalizeUsername(input).toLowerCase();
  }

  ActionCodeSettings _buildPasswordResetSettings() {
    return ActionCodeSettings(
      url: _passwordResetContinueUrl,
      handleCodeInApp: false,
      androidPackageName: _androidPackageName,
      androidInstallApp: true,
    );
  }

  bool _isActionCodeConfigurationError(String code, String? message) {
    const configCodes = <String>{
      'missing-continue-uri',
      'invalid-continue-uri',
      'unauthorized-continue-uri',
      'invalid-dynamic-link-domain',
      'dynamic-link-not-activated',
      'missing-android-pkg-name',
      'missing-ios-bundle-id',
    };

    if (configCodes.contains(code)) return true;

    final msg = (message ?? '').toLowerCase();
    return msg.contains('allowlisted') ||
        msg.contains('allowlist') ||
        msg.contains('continue uri') ||
        msg.contains('dynamic link domain');
  }

  bool _isValidUsername(String input) {
    return RegExp(r'^[A-Za-z0-9_.]{3,24}$').hasMatch(_normalizeUsername(input));
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate() || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      final email = _emailController.text.trim();
      final desiredUsername = _signupUsernameController.text.trim();
      final normalizedUsername = _normalizeUsername(desiredUsername);
      final usernameLower = _usernameLookupKey(desiredUsername);
      final password = _passwordController.text;

      final prefs = await SharedPreferences.getInstance();

      if (isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        if (!_isValidUsername(desiredUsername)) {
          throw FirebaseAuthException(
            code: 'invalid-username',
            message:
                'Username must be 3-24 characters using letters, numbers, ., _.',
          );
        }

        final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        // Any failure after auth creation must delete the auth user so the
        // account doesn't become orphaned (exists in Auth but not Firestore).
        try {
          final usernameRef = FirebaseFirestore.instance
              .collection('usernames')
              .doc(usernameLower);

          try {
            await FirebaseFirestore.instance.runTransaction((tx) async {
              final existing = await tx.get(usernameRef);
              if (existing.exists) {
                final owner = (existing.data()?['uid'] ?? '').toString();
                if (owner != cred.user!.uid) {
                  throw FirebaseAuthException(
                    code: 'username-taken',
                    message: 'That username is already taken.',
                  );
                }
              }

              tx.set(usernameRef, {
                'uid': cred.user!.uid,
                'username': normalizedUsername,
                'updatedAt': FieldValue.serverTimestamp(),
              });
            });
          } on FirebaseException catch (e) {
            // If username registry rules are not deployed yet, skip silently.
            if (e.code != 'permission-denied') {
              rethrow;
            }
          }

          await FirebaseFirestore.instance
              .collection('users')
              .doc(cred.user!.uid)
              .set({
                'email': email,
                'username': normalizedUsername,
                'usernameLower': usernameLower,
                'firstName': _firstNameController.text.trim(),
                'lastName': _lastNameController.text.trim(),
                'createdAt': FieldValue.serverTimestamp(),
                'displayName': '',
                'onboardingComplete': false,
              });

          await VerificationEmailService.send(cred.user!);
        } catch (e) {
          // Rollback: delete the newly created auth account so the email is
          // free to register again on next attempt.
          debugPrint('[Signup] Post-auth setup failed, deleting auth user: $e');
          await cred.user?.delete();
          rethrow;
        }
      }

      if (isLogin && _rememberMe.value) {
        await prefs.setString(kRememberedEmailKey, email);
        await prefs.setBool(kRememberMeKey, true);
      } else {
        await prefs.remove(kRememberedEmailKey);
        await prefs.setBool(kRememberMeKey, false);
      }

      // If SignupLogin was pushed as a route (e.g. from the startup splash),
      // pop back to root so AppRoot can rebuild with the new auth state.
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('[Signup] FirebaseAuthException: code=${e.code} msg=${e.message}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 8),
          content: Text('[${e.code}] ${e.message ?? 'Authentication error'}'),
        ),
      );
    } on FirebaseException catch (e) {
      debugPrint('[Signup] FirebaseException: code=${e.code} msg=${e.message}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 8),
          content: Text('[${e.code}] ${e.message ?? 'Could not save your profile.'}'),
        ),
      );
    } catch (e) {
      debugPrint('[Signup] Unknown error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 8),
          content: Text('Signup error: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Enter your email address first.'),
        ),
      );
      return;
    }

    try {
      try {
        await FirebaseAuth.instance.sendPasswordResetEmail(
          email: email,
          actionCodeSettings: _buildPasswordResetSettings(),
        );
      } on FirebaseAuthException catch (e) {
        if (!_isActionCodeConfigurationError(e.code, e.message)) {
          rethrow;
        }
        await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Reset email sent to $email. Open the link in your email to reset your password on the web page.',
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(e.message ?? 'Unable to send password reset email.'),
        ),
      );
    }
  }

  void _toggleMode() {
    setState(() {
      isLogin = !isLogin;
      _hidePassword.value = true;
      _hideConfirm.value = true;
      _firstNameController.clear();
      _lastNameController.clear();
      _emailController.clear();
      _signupUsernameController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final title = isLogin ? 'Sign in to continue' : 'Create your profile';
    final subtitle = isLogin
        ? 'Your habits, trends, and wellness insights are waiting.'
        : 'Set up your account in a minute and start tracking right away.';

    return Scaffold(
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            _AuthBackdrop(colorScheme: cs),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 34,
                      ),
                      child: Form(
                        key: _formKey,
                        child: AutofillGroup(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _HeaderRibbon(
                                isLogin: isLogin,
                                title: title,
                                subtitle: subtitle,
                              ),
                              const SizedBox(height: 16),
                              _ModeSwitchPanel(
                                isLogin: isLogin,
                                onModeChanged: (newMode) {
                                  if (newMode != isLogin) {
                                    _toggleMode();
                                  }
                                },
                              ),
                              const SizedBox(height: 14),
                              AnimatedSize(
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOut,
                                child: isLogin
                                    ? const SizedBox.shrink()
                                    : _IdentityCard(
                                        firstNameController:
                                            _firstNameController,
                                        lastNameController: _lastNameController,
                                        usernameController:
                                            _signupUsernameController,
                                        isSignupMode: !isLogin,
                                      ),
                              ),
                              if (!isLogin) const SizedBox(height: 14),
                              _CredentialsCard(
                                isLogin: isLogin,
                                emailController: _emailController,
                                passwordController: _passwordController,
                                confirmPasswordController:
                                    _confirmPasswordController,
                                hidePasswordListenable: _hidePassword,
                                hideConfirmListenable: _hideConfirm,
                                onSubmitFromKeyboard: _submit,
                              ),
                              const SizedBox(height: 14),
                              if (isLogin)
                                _UtilityRow(
                                  rememberMeListenable: _rememberMe,
                                  onForgotPassword: _forgotPassword,
                                ),
                              if (isLogin) const SizedBox(height: 10),
                              FilledButton.icon(
                                onPressed: _isSubmitting ? null : _submit,
                                icon: _isSubmitting
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.4,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Icon(
                                        isLogin
                                            ? Icons.lock_open_rounded
                                            : Icons.person_add_alt_1_rounded,
                                      ),
                                label: Text(
                                  _isSubmitting
                                      ? 'Please wait...'
                                      : isLogin
                                      ? 'Sign in'
                                      : 'Create account',
                                ),
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 56),
                                  backgroundColor: cs.primary,
                                  foregroundColor: cs.onPrimary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (!isLogin) ...[
                                _InfoPanel(isLogin: isLogin),
                                const SizedBox(height: 12),
                                Text(
                                  'By creating an account, you agree to Terms and Privacy Policy.',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthBackdrop extends StatelessWidget {
  const _AuthBackdrop({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                colorScheme.surface,
                Color.alphaBlend(
                  colorScheme.primary.withValues(alpha: 0.09),
                  colorScheme.surface,
                ),
                Color.alphaBlend(
                  colorScheme.secondary.withValues(alpha: 0.08),
                  colorScheme.surface,
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: -80,
          right: -40,
          child: _BackdropOrb(
            diameter: 210,
            color: colorScheme.primary.withValues(alpha: 0.22),
          ),
        ),
        Positioned(
          top: 220,
          left: -60,
          child: _BackdropOrb(
            diameter: 170,
            color: colorScheme.secondary.withValues(alpha: 0.18),
          ),
        ),
        Positioned(
          bottom: -90,
          right: 20,
          child: _BackdropOrb(
            diameter: 230,
            color: colorScheme.primaryContainer.withValues(alpha: 0.32),
          ),
        ),
      ],
    );
  }
}

class _BackdropOrb extends StatelessWidget {
  const _BackdropOrb({required this.diameter, required this.color});

  final double diameter;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}

class _HeaderRibbon extends StatelessWidget {
  const _HeaderRibbon({
    required this.isLogin,
    required this.title,
    required this.subtitle,
  });

  final bool isLogin;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              cs.primary.withValues(alpha: 0.60),
              cs.primaryContainer,
            ),
            Color.alphaBlend(
              cs.secondary.withValues(alpha: 0.42),
              cs.primaryContainer,
            ),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _BrandBadge(colorScheme: cs),
              const Spacer(),
              _StatusBadge(
                icon: isLogin
                    ? Icons.nights_stay_rounded
                    : Icons.auto_awesome_rounded,
                label: isLogin ? 'Welcome back' : 'New account',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: cs.onPrimaryContainer,
              fontWeight: FontWeight.w900,
              height: 1.05,
              letterSpacing: -0.35,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onPrimaryContainer.withValues(alpha: 0.86),
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandBadge extends StatelessWidget {
  const _BrandBadge({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colorScheme.onPrimaryContainer.withValues(alpha: 0.20),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.spa_rounded,
            size: 16,
            color: colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 6),
          Text(
            'LIFELENS',
            style: TextStyle(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.9,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: cs.onPrimaryContainer),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: cs.onPrimaryContainer,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeSwitchPanel extends StatelessWidget {
  const _ModeSwitchPanel({required this.isLogin, required this.onModeChanged});

  final bool isLogin;
  final ValueChanged<bool> onModeChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: SegmentedButton<bool>(
          showSelectedIcon: false,
          selected: {isLogin},
          onSelectionChanged: (selection) => onModeChanged(selection.first),
          style: ButtonStyle(
            textStyle: WidgetStateProperty.all(
              const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.2),
            ),
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return cs.primaryContainer;
              }
              return cs.surfaceContainerHighest.withValues(alpha: 0.6);
            }),
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return cs.onPrimaryContainer;
              }
              return cs.onSurfaceVariant;
            }),
            side: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return BorderSide(color: cs.primary.withValues(alpha: 0.45));
              }
              return BorderSide(
                color: cs.outlineVariant.withValues(alpha: 0.45),
              );
            }),
            shape: WidgetStateProperty.all(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            padding: WidgetStateProperty.all(
              const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          segments: const [
            ButtonSegment<bool>(
              value: true,
              label: Text('Login'),
              icon: Icon(Icons.login_rounded, size: 16),
            ),
            ButtonSegment<bool>(
              value: false,
              label: Text('Sign Up'),
              icon: Icon(Icons.person_add_alt_1_rounded, size: 16),
            ),
          ],
        ),
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.firstNameController,
    required this.lastNameController,
    required this.usernameController,
    required this.isSignupMode,
  });

  final TextEditingController firstNameController;
  final TextEditingController lastNameController;
  final TextEditingController usernameController;
  final bool isSignupMode;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'About you',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(color: cs.onSurface),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _AuthField(
                    controller: firstNameController,
                    label: 'First name',
                    hint: 'First name',
                    icon: Icons.badge_outlined,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.givenName],
                    validator: (value) {
                      if (isSignupMode &&
                          (value == null || value.trim().isEmpty)) {
                        return 'Required';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _AuthField(
                    controller: lastNameController,
                    label: 'Last name',
                    hint: 'Last name',
                    icon: Icons.badge_outlined,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.familyName],
                    validator: (value) {
                      if (isSignupMode &&
                          (value == null || value.trim().isEmpty)) {
                        return 'Required';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            if (isSignupMode) ...[
              const SizedBox(height: 10),
              _AuthField(
                controller: usernameController,
                label: 'Username',
                hint: '@yourname',
                icon: Icons.alternate_email_rounded,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  var v = (value ?? '').trim();
                  if (v.startsWith('@')) {
                    v = v.substring(1);
                  }
                  if (v.isEmpty) {
                    return 'Required';
                  }
                  if (!RegExp(r'^[A-Za-z0-9_.]{3,24}$').hasMatch(v)) {
                    return 'Use 3-24 chars: letters, numbers, ., _';
                  }
                  return null;
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CredentialsCard extends StatelessWidget {
  const _CredentialsCard({
    required this.isLogin,
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.hidePasswordListenable,
    required this.hideConfirmListenable,
    required this.onSubmitFromKeyboard,
  });

  final bool isLogin;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final ValueNotifier<bool> hidePasswordListenable;
  final ValueNotifier<bool> hideConfirmListenable;
  final VoidCallback onSubmitFromKeyboard;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Credentials',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(color: cs.onSurface),
            ),
            const SizedBox(height: 10),
            _AuthField(
              controller: emailController,
              label: 'Email',
              hint: 'you@example.com',
              icon: Icons.alternate_email_rounded,
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [
                AutofillHints.email,
                AutofillHints.username,
              ],
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter your email address';
                }
                if (!value.contains('@') || !value.contains('.')) {
                  return 'Enter a valid email address';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<bool>(
              valueListenable: hidePasswordListenable,
              builder: (context, hidePassword, _) {
                return _AuthField(
                  controller: passwordController,
                  label: 'Password',
                  hint: isLogin ? 'Your password' : 'At least 6 characters',
                  icon: Icons.lock_outline_rounded,
                  textInputAction: isLogin
                      ? TextInputAction.done
                      : TextInputAction.next,
                  autofillHints: isLogin
                      ? const [AutofillHints.password]
                      : const [AutofillHints.newPassword],
                  obscureText: hidePassword,
                  suffixIcon: IconButton(
                    onPressed: () {
                      hidePasswordListenable.value = !hidePassword;
                    },
                    icon: Icon(
                      hidePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                  onFieldSubmitted: (_) {
                    if (isLogin) {
                      onSubmitFromKeyboard();
                    }
                  },
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter your password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                );
              },
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  children: [
                    ValueListenableBuilder<bool>(
                      valueListenable: hideConfirmListenable,
                      builder: (context, hideConfirm, _) {
                        return _AuthField(
                          controller: confirmPasswordController,
                          label: 'Confirm password',
                          hint: 'Re-enter password',
                          icon: Icons.verified_user_outlined,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.newPassword],
                          obscureText: hideConfirm,
                          suffixIcon: IconButton(
                            onPressed: () {
                              hideConfirmListenable.value = !hideConfirm;
                            },
                            icon: Icon(
                              hideConfirm
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                          validator: (value) {
                            if (!isLogin &&
                                (value == null || value.trim().isEmpty)) {
                              return 'Confirm your password';
                            }
                            if (!isLogin && value != passwordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        );
                      },
                    ),
                    if (!isLogin) ...[
                      const SizedBox(height: 10),
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: passwordController,
                        builder: (context, value, _) {
                          return _PasswordMeter(password: value.text);
                        },
                      ),
                    ],
                  ],
                ),
              ),
              crossFadeState: isLogin
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              duration: const Duration(milliseconds: 220),
            ),
          ],
        ),
      ),
    );
  }
}

class _PasswordMeter extends StatelessWidget {
  const _PasswordMeter({required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final score = _score(password);
    final strengthLabel = score >= 0.8
        ? 'Strong'
        : score >= 0.5
        ? 'Medium'
        : 'Weak';

    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: score,
              backgroundColor: cs.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                score >= 0.8
                    ? Colors.greenAccent.shade400
                    : score >= 0.5
                    ? Colors.amberAccent.shade400
                    : Colors.redAccent.shade200,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          strengthLabel,
          style: theme.textTheme.labelSmall?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  double _score(String text) {
    if (text.isEmpty) return 0;
    final hasUpper = text.contains(RegExp('[A-Z]'));
    final hasLower = text.contains(RegExp('[a-z]'));
    final hasNum = text.contains(RegExp('[0-9]'));
    final hasSpecial = text.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'));
    final base = (text.length / 12).clamp(0.0, 1.0);
    final bonus =
        [hasUpper, hasLower, hasNum, hasSpecial].where((x) => x).length * 0.1;
    return math.min(1.0, base * 0.6 + bonus);
  }
}

class _UtilityRow extends StatelessWidget {
  const _UtilityRow({
    required this.rememberMeListenable,
    required this.onForgotPassword,
  });

  final ValueNotifier<bool> rememberMeListenable;
  final VoidCallback onForgotPassword;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Row(
      children: [
        Expanded(
          child: ValueListenableBuilder<bool>(
            valueListenable: rememberMeListenable,
            builder: (context, rememberMe, _) {
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => rememberMeListenable.value = !rememberMe,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Checkbox.adaptive(
                        value: rememberMe,
                        onChanged: (value) {
                          rememberMeListenable.value = value ?? false;
                        },
                        visualDensity: VisualDensity.compact,
                      ),
                      Text(
                        'Remember me',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        TextButton(
          onPressed: onForgotPassword,
          child: const Text('Forgot password?'),
        ),
      ],
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.isLogin});

  final bool isLogin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: Row(
        children: [
          Icon(Icons.shield_outlined, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isLogin
                  ? 'Encrypted authentication keeps your account secure.'
                  : 'We use your profile details only for personalized insights.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthField extends StatelessWidget {
  const _AuthField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.textInputAction,
    required this.validator,
    this.keyboardType,
    this.obscureText = false,
    this.autofillHints,
    this.suffixIcon,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputAction textInputAction;
  final FormFieldValidator<String> validator;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Iterable<String>? autofillHints;
  final Widget? suffixIcon;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      autofillHints: autofillHints,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: cs.onSurfaceVariant, size: 19),
        suffixIcon: suffixIcon,
      ),
      validator: validator,
      onFieldSubmitted: onFieldSubmitted,
    );
  }
}
