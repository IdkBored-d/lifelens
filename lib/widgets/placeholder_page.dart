import 'package:flutter/material.dart';

class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Text(
        "$title (UI only)",
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }
}
