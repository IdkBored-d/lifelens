import 'package:flutter/material.dart';

String miniMeAssetForMood(String? moodLabel) {
  switch (moodLabel) {
    case "Happy":
      return "lib/assets/minime/happy.png";
    case "Sad":
      return "lib/assets/minime/sad.png";
    case "Anxious":
    case "Stressed":
      return "lib/assets/minime/stressed.png";
    case "Energetic":
      return "lib/assets/minime/energetic.png";
    default:
      return "lib/assets/minime/calm.png";
  }
}

Color glowForIntensity(ColorScheme cs, int intensity) {
  if (intensity <= 1) return cs.primary.withOpacity(0.18);
  if (intensity == 2) return cs.primary.withOpacity(0.26);
  if (intensity == 3) return cs.primary.withOpacity(0.34);
  if (intensity == 4) return cs.primary.withOpacity(0.42);
  return cs.primary.withOpacity(0.5);
}