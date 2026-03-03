import 'package:flutter/foundation.dart';

class MoodCheckIn{
  MoodCheckIn({
    required this.moodLabel,
    required this.emoji,
    required this.intensity,
    required this.tags,
    required this.notes,
    required this.createdAt,
  });
  final String moodLabel;
  final String emoji;
  final int intensity;
  final List<String> tags;
  final String notes;
  final DateTime createdAt;
}

class MoodLogStore extends ChangeNotifier{
  final List<MoodCheckIn> _items = [];

  List<MoodCheckIn> get items => List.unmodifiable(_items);

  void add(MoodCheckIn item) {
    _items.insert(0, item);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}