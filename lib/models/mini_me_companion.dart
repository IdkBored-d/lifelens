import 'package:flutter/material.dart';

class MiniMeCompanionPreset {
  const MiniMeCompanionPreset({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.accentColor,
    required this.shellColor,
    required this.shirtColor,
    required this.bodyModel,
    required this.hairModel,
    required this.shirtModel,
    required this.bodyWidthScale,
  });

  final String id;
  final String name;
  final String subtitle;
  final Color accentColor;
  final Color shellColor;
  final Color shirtColor;
  final String bodyModel;
  final String hairModel;
  final String shirtModel;
  final double bodyWidthScale;
}

class MiniMeBackendAvatarSnapshot {
  const MiniMeBackendAvatarSnapshot({
    this.companionId,
    this.degradationLevel,
    this.isHatched,
    this.miniMeName,
  });

  final String? companionId;
  final double? degradationLevel;
  final bool? isHatched;
  final String? miniMeName;
}

const List<MiniMeCompanionPreset> miniMeCompanionPresets = [
  MiniMeCompanionPreset(
    id: 'cloud',
    name: 'Classic',
    subtitle: 'Original Mini-Me look',
    accentColor: Color(0xFF7A9DDB),
    shellColor: Color(0xFFF9F7F3),
    shirtColor: Color(0xFF7FA8E8),
    bodyModel: 'preset/cloud',
    hairModel: 'preset/cloud_fluff',
    shirtModel: 'preset/cloud_band',
    bodyWidthScale: 1.0,
  ),
  MiniMeCompanionPreset(
    id: 'pebble',
    name: 'Sunset',
    subtitle: 'Warm coral variation',
    accentColor: Color(0xFF8F7AD8),
    shellColor: Color(0xFFFFF8EC),
    shirtColor: Color(0xFFE8A06F),
    bodyModel: 'preset/pebble',
    hairModel: 'preset/pebble_sprout',
    shirtModel: 'preset/pebble_tie',
    bodyWidthScale: 1.06,
  ),
  MiniMeCompanionPreset(
    id: 'sprig',
    name: 'Mint',
    subtitle: 'Fresh green variation',
    accentColor: Color(0xFF58A78B),
    shellColor: Color(0xFFF3FBF2),
    shirtColor: Color(0xFF6CC2A4),
    bodyModel: 'preset/sprig',
    hairModel: 'preset/sprig_fluff',
    shirtModel: 'preset/sprig_band',
    bodyWidthScale: 0.96,
  ),
  MiniMeCompanionPreset(
    id: 'dawn',
    name: 'Twilight',
    subtitle: 'Cool violet variation',
    accentColor: Color(0xFF7E84DA),
    shellColor: Color(0xFFF4F2FE),
    shirtColor: Color(0xFF8F96EA),
    bodyModel: 'preset/dawn',
    hairModel: 'preset/dawn_sprout',
    shirtModel: 'preset/dawn_tie',
    bodyWidthScale: 1.02,
  ),
];

MiniMeCompanionPreset miniMePresetById(String id) {
  return miniMeCompanionPresets.firstWhere(
    (preset) => preset.id == id,
    orElse: () => miniMeCompanionPresets.first,
  );
}
