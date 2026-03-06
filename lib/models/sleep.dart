class Sleep {
  const Sleep({
    required this.bedTime,
    required this.wakeTime,
    required this.quality,
    required this.date,
    this.notes = '',
  });

  final DateTime bedTime;
  final DateTime wakeTime;
  final SleepQuality quality;
  final DateTime date;
  final String notes;

  Duration get duration {
    if (bedTime.isAfter(wakeTime)) {
      final adjustedWakeTime = wakeTime.add(const Duration(days: 1));
      return adjustedWakeTime.difference(bedTime);
    }
    return wakeTime.difference(bedTime);
  }

  String get durationFormatted {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    return '${hours}h ${minutes}m';
  }
}

enum SleepQuality {
  poor('😴', 'Poor', 1),
  fair('😊', 'Fair', 2), 
  good('😌', 'Good', 3),
  excellent('🌟', 'Excellent', 4);

  const SleepQuality(this.emoji, this.label, this.value);

  final String emoji;
  final String label;
  final int value;
}

const sleepQualities = SleepQuality.values;

final sampleSleepData = [
  Sleep(
    bedTime: DateTime.now().subtract(const Duration(days: 1, hours: 9)),
    wakeTime: DateTime.now().subtract(const Duration(hours: 1)),
    quality: SleepQuality.good,
    date: DateTime.now().subtract(const Duration(days: 1)),
    notes: 'Felt refreshed',
  ),

  Sleep(
    bedTime: DateTime.now().subtract(const Duration(days: 2, hours: 10)),
    wakeTime: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
    quality: SleepQuality.fair,
    date: DateTime.now().subtract(const Duration(days: 2)),
    notes: 'Woke up a few times',
  ),

  Sleep(
    bedTime: DateTime.now().subtract(const Duration(days: 3, hours: 8)),
    wakeTime: DateTime.now().subtract(const Duration(days: 2, hours: 1)),
    quality: SleepQuality.excellent,
    date: DateTime.now().subtract(const Duration(days: 3)),
    notes: 'Perfect night',
  ),
];