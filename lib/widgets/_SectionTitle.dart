import 'package:flutter/material.dart';

class SectionTitle extends StatelessWidget {
  const SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w800,
        color: cs.onSurface,
      ),
    );
  }
}