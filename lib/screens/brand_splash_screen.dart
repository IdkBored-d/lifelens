import 'package:flutter/material.dart';

class BrandSplashScreen extends StatelessWidget {
  const BrandSplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF0F1014);
    const primaryDeep = Color(0xFF6D4CFF);
    const lavender = Color(0xFFBFA5FF);

    return Scaffold(
      backgroundColor: bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: const Color(0xFF1C1830),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: primaryDeep.withValues(alpha: 0.35),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: primaryDeep.withValues(alpha: 0.30),
                    blurRadius: 32,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.spa_rounded,
                size: 48,
                color: lavender,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'LifeLens',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
