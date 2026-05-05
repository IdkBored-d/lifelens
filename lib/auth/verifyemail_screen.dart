import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'verification_email_service.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({
    super.key,
    required this.email,
    required this.onVerifiedConfirmed,
    this.onUseAnotherAccount,
  });
  final String email;
  final VoidCallback onVerifiedConfirmed;
  final VoidCallback? onUseAnotherAccount;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool sending = false;
  bool checking = false;

  bool _isRateLimitError(FirebaseAuthException e) {
    final code = e.code.toLowerCase();
    final msg = (e.message ?? '').toLowerCase();
    return code == 'too-many-requests' ||
        msg.contains('unusual activity') ||
        msg.contains('too many') ||
        msg.contains('blocked all requests');
  }

  String _friendlySendError(FirebaseAuthException e) {
    if (_isRateLimitError(e)) {
      return 'Too many resend attempts. Please wait a few minutes before trying again.';
    }
    if (e.code == 'network-request-failed') {
      return 'Network issue while sending email. Check your connection and try again.';
    }
    if (e.code == 'invalid-email') {
      return 'Your account email appears invalid. Update it and try again.';
    }
    return e.message ?? 'Unable to send verification email.';
  }

  Future<void> _sendVerificationEmail() async {
    setState(() => sending = true);
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.reload();
        user = FirebaseAuth.instance.currentUser;
      }
      if (user == null) {
        for (var i = 0; i < 6; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 300));
          user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            await user.reload();
            user = FirebaseAuth.instance.currentUser;
            break;
          }
        }
      }
      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Session unavailable right now. Please stay on this screen and try resend again in a moment.',
            ),
          ),
        );
        return;
      }
      if (user.emailVerified) return;
      final mode = await VerificationEmailService.send(user);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            mode == VerificationEmailSendMode.customActionLink
                ? 'Verification email resent. Open the newest email link.'
                : 'Verification email resent. Open the newest email link.',
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlySendError(e))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to send verification email right now. Please try again. ($e)',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => sending = false);
      }
    }
  }

  Future<void> _resend() => _sendVerificationEmail();

  Future<void> _checkVerified() async {
    setState(() => checking = true);

    final user = FirebaseAuth.instance.currentUser;
    await user?.reload();

    if (FirebaseAuth.instance.currentUser?.emailVerified == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email verified. Continuing...')),
        );
      }
      widget.onVerifiedConfirmed();
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not verified yet. Check your email.')),
      );
    }

    if (mounted) {
      setState(() => checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  cs.surface,
                  Color.alphaBlend(
                    cs.primary.withValues(alpha: 0.10),
                    cs.surface,
                  ),
                  Color.alphaBlend(
                    cs.secondary.withValues(alpha: 0.08),
                    cs.surface,
                  ),
                ],
              ),
            ),
            child: const SizedBox.expand(),
          ),
          Positioned(
            top: -70,
            right: -20,
            child: _GlowBubble(
              diameter: 190,
              color: cs.primary.withValues(alpha: 0.24),
            ),
          ),
          Positioned(
            bottom: -90,
            left: -20,
            child: _GlowBubble(
              diameter: 210,
              color: cs.primaryContainer.withValues(alpha: 0.30),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 34,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _HeaderCard(email: widget.email),
                        const SizedBox(height: 14),
                        _StepsCard(colorScheme: cs),
                        const SizedBox(height: 14),
                        Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                FilledButton.icon(
                                  onPressed: sending ? null : _resend,
                                  icon: sending
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.4,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.mark_email_unread_rounded,
                                        ),
                                  label: Text(
                                    sending
                                        ? 'Sending verification email...'
                                        : 'Resend verification email',
                                  ),
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size(
                                      double.infinity,
                                      52,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                OutlinedButton.icon(
                                  onPressed: checking ? null : _checkVerified,
                                  icon: checking
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.verified_user_rounded),
                                  label: Text(
                                    checking
                                        ? 'Checking verification...'
                                        : 'I verified, continue',
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(
                                      double.infinity,
                                      52,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: cs.surfaceContainerHighest
                                        .withValues(alpha: 0.55),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: cs.outlineVariant.withValues(
                                        alpha: 0.55,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline_rounded,
                                        size: 18,
                                        color: cs.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Use the latest verification email only. Older links expire after a new resend.',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: cs.onSurfaceVariant,
                                                height: 1.25,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextButton.icon(
                          onPressed: () async {
                            await FirebaseAuth.instance.signOut();
                            widget.onUseAnotherAccount?.call();
                          },
                          icon: const Icon(Icons.logout_rounded),
                          label: const Text('Sign out and use another account'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowBubble extends StatelessWidget {
  const _GlowBubble({required this.diameter, required this.color});

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

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              cs.primary.withValues(alpha: 0.58),
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
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: cs.surface.withValues(alpha: 0.20),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.mark_email_read_rounded,
                  color: cs.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Verify your email',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: cs.onPrimaryContainer,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'We sent a secure verification link to:',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onPrimaryContainer.withValues(alpha: 0.86),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: cs.surface.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: cs.onPrimaryContainer.withValues(alpha: 0.22),
              ),
            ),
            child: Text(
              email,
              style: theme.textTheme.titleSmall?.copyWith(
                color: cs.onPrimaryContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepsCard extends StatelessWidget {
  const _StepsCard({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Next steps',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(color: colorScheme.onSurface),
            ),
            const SizedBox(height: 10),
            _StepTile(
              index: 1,
              text: 'Open your inbox and tap the verification link.',
            ),
            const SizedBox(height: 8),
            _StepTile(
              index: 2,
              text: 'Return to this screen and tap Continue.',
            ),
            const SizedBox(height: 8),
            _StepTile(index: 3, text: 'If needed, resend the email below.'),
          ],
        ),
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({required this.index, required this.text});

  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$index',
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onPrimaryContainer,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
