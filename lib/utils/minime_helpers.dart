import 'package:flutter/material.dart';

String miniMeAssetForMood(String? moodLabel) {
  switch ((moodLabel ?? '').trim().toLowerCase()) {
    case "happy":
    case "joy":
    case "surprised":
      return "lib/assets/minime/happy.png";
    case "affectionate":
    case "love":
      return "lib/assets/minime/happy.png";
    case "sad":
    case "sadness":
    case "scared":
    case "fear":
      return "lib/assets/minime/sad.png";
    case "angry":
    case "anxious":
    case "stressed":
      return "lib/assets/minime/stressed.png";
    case "energetic":
      return "lib/assets/minime/energetic.png";
    default:
      return "lib/assets/minime/calm.png";
  }
}

Color glowForIntensity(ColorScheme cs, int intensity) {
  if (intensity <= 1) return cs.primary.withValues(alpha:0.18);
  if (intensity == 2) return cs.primary.withValues(alpha:0.26);
  if (intensity == 3) return cs.primary.withValues(alpha:0.34);
  if (intensity == 4) return cs.primary.withValues(alpha:0.42);
  return cs.primary.withValues(alpha:0.5);
}
