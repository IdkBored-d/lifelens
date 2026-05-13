import 'package:isar_community/isar.dart';

part 'sleep_entry.g.dart';

@Collection()
class SleepEntry {
  Id id = Isar.autoIncrement;

  @Index()
  late String date;

  late DateTime bedTime;
  late DateTime wakeTime;
  late String quality;
  late int qualityValue;
  late String notes;
  late int durationMinutes;

  @Index()
  late DateTime timestamp;
}
