import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key, required this.email});
  final String email;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool sending = false;
  bool checking = false;

  Future<void> _resend() async {
    setState(() => sending = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      await user?.sendEmailVerification();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification email resent.')),
      );
    } finally {
      setState(() => sending = false);
    }
  }

  Future<void> _checkVerified() async {
    setState(() => checking = true);

    final user = FirebaseAuth.instance.currentUser;
    await user?.reload();

    if (FirebaseAuth.instance.currentUser?.emailVerified == true) {
      // ✅ DO NOTHING ELSE
      // AppRoot will automatically rebuild and route to MenuScreen
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not verified yet. Check your email.')),
      );
    }

    setState(() => checking = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify your email')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'We sent a verification link to:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              widget.email,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            const Text('Open your email and click the link.'),

            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: sending ? null : _resend,
              child: Text(sending ? 'Sending…' : 'Resend email'),
            ),

            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: checking ? null : _checkVerified,
              child: Text(checking ? 'Checking…' : 'I verified, continue'),
            ),

            const Spacer(),

            // Optional: explicit logout instead of pop
            TextButton(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
              },
              child: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}
