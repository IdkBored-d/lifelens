import 'package:flutter/material.dart';

class FilterChips extends StatelessWidget {
  final List<String> muscles = const [
    'chest',
    'back',
    'legs',
    'shoulders',
    'core',
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemBuilder: (_, i) => Chip(label: Text(muscles[i])),
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemCount: muscles.length,
      ),
    );
  }
}

