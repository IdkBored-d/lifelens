import 'package:flutter/material.dart';

class SoftIconButton extends StatelessWidget {
  const SoftIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell (
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container (
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration (
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
          ),
          child: Icon(icon, color: cs.onSurfaceVariant),
        ),
      );
    }
  }