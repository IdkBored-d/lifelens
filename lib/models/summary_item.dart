import 'package:flutter/material.dart';

class Summaryitem {
  const Summaryitem ({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;
}