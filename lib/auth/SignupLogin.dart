import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'verification_email_service.dart';

class SignupLogin extends StatefulWidget {
  const SignupLogin({super.key});

  @override
  State<SignupLogin> createState() => _SignupLoginState();
}

class _SignupLoginState extends State<SignupLogin> {
  bool isLogin = true;
  bool rememberMe = false;
  bool _hidePassword = true;
  bool _hideConfirm = true;
  bool _isSubmitting = false;

  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate() || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      final email = _usernameController.text.trim();
      final password = _passwordController.text;

      if (isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        await VerificationEmailService.send(cred.user!);

        await FirebaseFirestore.instance
            .collection('users')
            .doc(cred.user!.uid)
            .set({
              'email': email,
              'firstName': _firstNameController.text.trim(),
              'lastName': _lastNameController.text.trim(),
              'createdAt': FieldValue.serverTimestamp(),
              'displayName': '',
              'onboardingComplete': false,
            });
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(e.message ?? 'Authentication error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _toggleMode() {
    setState(() {
      isLogin = !isLogin;
      rememberMe = false;
      _hidePassword = true;
      _hideConfirm = true;
      _firstNameController.clear();
      _lastNameController.clear();
      _usernameController.clear();
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
                                        isSignupMode: !isLogin,
                                      ),
                              ),
                              if (!isLogin) const SizedBox(height: 14),
                              _CredentialsCard(
                                isLogin: isLogin,
                                usernameController: _usernameController,
                                passwordController: _passwordController,
                                confirmPasswordController:
                                    _confirmPasswordController,
                                hidePassword: _hidePassword,
                                hideConfirm: _hideConfirm,
                                onTogglePassword: () => setState(
                                  () => _hidePassword = !_hidePassword,
                                ),
                                onToggleConfirm: () => setState(
                                  () => _hideConfirm = !_hideConfirm,
                                ),
                                onSubmitFromKeyboard: _submit,
                              ),
                              const SizedBox(height: 14),
                              if (isLogin)
                                _UtilityRow(
                                  rememberMe: rememberMe,
                                  onRememberChanged: (value) =>
                                      setState(() => rememberMe = value),
                                  onForgotPassword: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        behavior: SnackBarBehavior.floating,
                                        content: Text(
                                          'Forgot password flow is coming soon.',
                                        ),
                                      ),
                                    );
                                  },
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
                              _InfoPanel(isLogin: isLogin),
                              if (!isLogin) ...[
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
                  colorScheme.primary.withOpacity(0.09),
                  colorScheme.surface,
                ),
                Color.alphaBlend(
                  colorScheme.secondary.withOpacity(0.08),
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
            color: colorScheme.primary.withOpacity(0.22),
          ),
        ),
        Positioned(
          top: 220,
          left: -60,
          child: _BackdropOrb(
            diameter: 170,
            color: colorScheme.secondary.withOpacity(0.18),
          ),
        ),
        Positioned(
          bottom: -90,
          right: 20,
          child: _BackdropOrb(
            diameter: 230,
            color: colorScheme.primaryContainer.withOpacity(0.32),
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
            Color.alphaBlend(cs.primary.withOpacity(0.60), cs.primaryContainer),
            Color.alphaBlend(
              cs.secondary.withOpacity(0.42),
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
              color: cs.onPrimaryContainer.withOpacity(0.86),
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
        color: colorScheme.surface.withOpacity(0.22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colorScheme.onPrimaryContainer.withOpacity(0.20),
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
        color: cs.surface.withOpacity(0.24),
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
              return cs.surfaceContainerHighest.withOpacity(0.6);
            }),
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return cs.onPrimaryContainer;
              }
              return cs.onSurfaceVariant;
            }),
            side: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return BorderSide(color: cs.primary.withOpacity(0.45));
              }
              return BorderSide(color: cs.outlineVariant.withOpacity(0.45));
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
    required this.isSignupMode,
  });

  final TextEditingController firstNameController;
  final TextEditingController lastNameController;
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
                    hint: 'Alex',
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
                    hint: 'Brown',
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
          ],
        ),
      ),
    );
  }
}

class _CredentialsCard extends StatelessWidget {
  const _CredentialsCard({
    required this.isLogin,
    required this.usernameController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.hidePassword,
    required this.hideConfirm,
    required this.onTogglePassword,
    required this.onToggleConfirm,
    required this.onSubmitFromKeyboard,
  });

  final bool isLogin;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final bool hidePassword;
  final bool hideConfirm;
  final VoidCallback onTogglePassword;
  final VoidCallback onToggleConfirm;
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
              controller: usernameController,
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
            _AuthField(
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
                onPressed: onTogglePassword,
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
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  children: [
                    _AuthField(
                      controller: confirmPasswordController,
                      label: 'Confirm password',
                      hint: 'Re-enter password',
                      icon: Icons.verified_user_outlined,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.newPassword],
                      obscureText: hideConfirm,
                      suffixIcon: IconButton(
                        onPressed: onToggleConfirm,
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
                    ),
                    if (!isLogin) ...[
                      const SizedBox(height: 10),
                      _PasswordMeter(password: passwordController.text),
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
    required this.rememberMe,
    required this.onRememberChanged,
    required this.onForgotPassword,
  });

  final bool rememberMe;
  final ValueChanged<bool> onRememberChanged;
  final VoidCallback onForgotPassword;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Row(
      children: [
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onRememberChanged(!rememberMe),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Checkbox.adaptive(
                    value: rememberMe,
                    onChanged: (value) => onRememberChanged(value ?? false),
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
        color: cs.surfaceContainerHighest.withOpacity(0.65),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.55)),
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
