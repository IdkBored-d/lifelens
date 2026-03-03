import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
    if (!_formKey.currentState!.validate()) return;

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

        await cred.user!.sendEmailVerification();

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message ?? 'Auth error')));
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

    final title = isLogin ? "Welcome back" : "Create your account";
    final subtitle = isLogin
        ? "Continue your wellness journey with LifeLens."
        : "Join LifeLens to start improving your lifestyle.";

    return Scaffold(
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            // Background gradient "hero"
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFE9FBF7), // mint
                    Color(0xFFF2F2FF), // very light lavender
                    Color(0xFFF7FAF9), // soft near-white
                  ],
                ),
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  // Header / hero
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                    child: Row(
                      children: [
                        _BrandPill(),
                        const Spacer(),
                        _ModeChip(isLogin: isLogin, onTap: _toggleMode),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      child: Column(
                        key: ValueKey(isLogin),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            subtitle,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.grey.shade700,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Card sheet
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: theme.scaffoldBackgroundColor.withOpacity(0.0),
                      ),
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(maxWidth: 520),
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(28),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 22,
                                offset: const Offset(0, -6),
                              ),
                            ],
                          ),
                          child: Form(
                            key: _formKey,
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const SizedBox(height: 6),
                                  AnimatedSize(
                                    duration: const Duration(milliseconds: 220),
                                    curve: Curves.easeOut,
                                    child: AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 220),
                                      child: isLogin
                                        ? const SizedBox.shrink()
                                        : Column(
                                          key: const ValueKey('names'),
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: TextFormField(
                                                    controller: _firstNameController,
                                                    textInputAction: TextInputAction.next,
                                                    autofillHints: const [AutofillHints.givenName],
                                                    decoration: const InputDecoration(
                                                      labelText: 'First Name',
                                                      hintText: 'Enter your first name',
                                                      prefixIcon: Icon(Icons.person_outline),
                                                    ),
                                                    validator: (value) {
                                                      if (!isLogin && (value == null || value.trim().isEmpty)) {
                                                        return 'Please enter your first name';
                                                      }
                                                      return null;
                                                    },
                                                  ),
                                                ),

                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: TextFormField(
                                                    controller: _lastNameController,
                                                    textInputAction: TextInputAction.next,
                                                    autofillHints: const [AutofillHints.familyName],
                                                    decoration: const InputDecoration(
                                                      labelText: 'Last Name',
                                                      hintText: 'Enter your last name',
                                                      prefixIcon: Icon(Icons.person_outline),
                                                    ),
                                                    validator: (value) {
                                                      if (!isLogin && (value == null || value.trim().isEmpty)) {
                                                        return 'Please enter your last name';
                                                      }
                                                      return null;
                                                    },
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 14),
                                          ],
                                        )),
                                    ),
                                  
                                  // Username
                                  TextFormField(
                                    controller: _usernameController,
                                    textInputAction: TextInputAction.next,
                                    autofillHints: const [
                                      AutofillHints.username,
                                    ],
                                    decoration: const InputDecoration(
                                      labelText: "Email",
                                      hintText: "Enter your email",
                                      prefixIcon: Icon(Icons.person_outline),
                                    ),
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Please enter your username';
                                      }
                                      if (!value.contains('@') || !value.contains('.')) {
                                        return 'Please enter a valid email address!';
                                      }
                                      return null;
                                    },
                                  ),

                                  const SizedBox(height: 14),

                                  // Password
                                  TextFormField(
                                    controller: _passwordController,
                                    textInputAction: isLogin
                                        ? TextInputAction.done
                                        : TextInputAction.next,
                                    autofillHints: isLogin
                                        ? const [AutofillHints.password]
                                        : const [AutofillHints.newPassword],
                                    obscureText: _hidePassword,
                                    decoration: InputDecoration(
                                      labelText: "Password",
                                      hintText: "Enter your password",
                                      prefixIcon: const Icon(
                                        Icons.lock_outline,
                                      ),
                                      suffixIcon: IconButton(
                                        onPressed: () => setState(
                                          () => _hidePassword = !_hidePassword,
                                        ),
                                        icon: Icon(
                                          _hidePassword
                                              ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined,
                                        ),
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Please enter your password';
                                      }
                                      if (value.length < 6) {
                                        return 'Password must be at least 6 characters';
                                      }
                                      return null;
                                    },
                                  ),

                                  // Confirm password (animated)
                                  AnimatedSize(
                                    duration: const Duration(milliseconds: 220),
                                    curve: Curves.easeOut,
                                    child: AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 220,
                                      ),
                                      child: isLogin
                                          ? const SizedBox.shrink()
                                          : Padding(
                                              padding: const EdgeInsets.only(
                                                top: 14,
                                              ),
                                              child: TextFormField(
                                                key: const ValueKey("confirm"),
                                                controller:
                                                    _confirmPasswordController,
                                                textInputAction:
                                                    TextInputAction.done,
                                                autofillHints: const [
                                                  AutofillHints.newPassword,
                                                ],
                                                obscureText: _hideConfirm,
                                                decoration: InputDecoration(
                                                  labelText: "Confirm Password",
                                                  hintText:
                                                      "Re-enter your password",
                                                  prefixIcon: const Icon(
                                                    Icons.lock_reset_outlined,
                                                  ),
                                                  suffixIcon: IconButton(
                                                    onPressed: () => setState(
                                                      () => _hideConfirm =
                                                          !_hideConfirm,
                                                    ),
                                                    icon: Icon(
                                                      _hideConfirm
                                                          ? Icons
                                                                .visibility_off_outlined
                                                          : Icons
                                                                .visibility_outlined,
                                                    ),
                                                  ),
                                                ),
                                                validator: (value) {
                                                  if (!isLogin &&
                                                      (value == null ||
                                                          value.isEmpty)) {
                                                    return "Please confirm your password";
                                                  }
                                                  if (!isLogin &&
                                                      value !=
                                                          _passwordController
                                                              .text) {
                                                    return 'Passwords do not match';
                                                  }
                                                  return null;
                                                },
                                              ),
                                            ),
                                    ),
                                  ),

                                  const SizedBox(height: 18),

                                  // Remember + forgot (login only)
                                  if (isLogin)
                                    Row(
                                      children: [
                                        Checkbox(
                                          value: rememberMe,
                                          onChanged: (v) => setState(
                                            () => rememberMe = v ?? false,
                                          ),
                                          visualDensity: VisualDensity.compact,
                                          materialTapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        Text(
                                          "Remember me",
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: Colors.grey.shade700,
                                              ),
                                        ),
                                        const Spacer(),
                                        TextButton(
                                          onPressed: () {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Forgot password')),
                                            );
                                          },
                                          child: Text(
                                            "Forgot password?",
                                            style: TextStyle(
                                              color: cs.primary,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                  const SizedBox(height: 6),

                                  // Primary button (with subtle gradient)
                                  SizedBox(
                                    height: 54,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(18),
                                        gradient: const LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Color(0xFF36B7A7),
                                            Color(0xFF5A86FF),
                                          ],
                                        ),
                                      ),
                                      child: ElevatedButton(
                                        onPressed: _submit,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          shadowColor: Colors.transparent,
                                          foregroundColor: Colors.white,
                                        ),
                                        child: Text(
                                          isLogin
                                              ? "Sign In"
                                              : "Create Account",
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 12),

                                  // Terms microcopy (signup only)
                                  if (!isLogin)
                                    Text(
                                      "By creating an account, you agree to our Terms & Privacy Policy.",
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: Colors.grey.shade600,
                                            height: 1.3,
                                          ),
                                    ),

                                  const SizedBox(height: 18),

                                  // Divider + bottom toggle
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Divider(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                        child: Text(
                                          "OR",
                                          style: theme.textTheme.labelMedium
                                              ?.copyWith(
                                                color: Colors.grey.shade600,
                                                letterSpacing: 0.6,
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Divider(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 16),

                                  Center(
                                    child: Wrap(
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          isLogin
                                              ? "New here? "
                                              : "Already have an account? ",
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                color: Colors.grey.shade700,
                                              ),
                                        ),
                                        InkWell(
                                          onTap: _toggleMode,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 4,
                                            ),
                                            child: Text(
                                              isLogin
                                                  ? "Create account"
                                                  : "Sign in",
                                              style: TextStyle(
                                                color: cs.primary,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 10),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.75),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.9)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.spa_outlined, size: 18, color: Color(0xFF2C6E66)),
          SizedBox(width: 8),
          Text(
            "LifeLens",
            style: TextStyle(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
              color: Color(0xFF102A2A),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.isLogin, required this.onTap});

  final bool isLogin;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.75),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withOpacity(0.9)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isLogin ? Icons.person_add_alt_1_outlined : Icons.login_outlined,
              size: 18,
              color: cs.primary,
            ),
            const SizedBox(width: 8),
            Text(
              isLogin ? "Sign up" : "Sign in",
              style: TextStyle(fontWeight: FontWeight.w800, color: cs.primary),
            ),
          ],
        ),
      ),
    );
  }
}
