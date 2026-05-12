import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:lifelens/services/tracking_reminder_service.dart';

import 'app_services.dart';
import 'database/sleep_entry.dart';
import 'models/sleep.dart';

class SleepStore extends ChangeNotifier {
  SleepStore({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance {
    _authSub = _auth.authStateChanges().listen((user) {
      _handleAuthChanged(user);
    });
    _loadFromIsar();
  }

  final FirebaseAuth _auth;
  late final StreamSubscription<User?> _authSub;

  final List<Sleep> _items = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _loadedScopeKey = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
  int _loadRequestId = 0;

  List<Sleep> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void _handleAuthChanged(User? user) {
    final nextScopeKey = user?.uid ?? 'guest';
    if (_loadedScopeKey != nextScopeKey) {
      _loadedScopeKey = nextScopeKey;
      _items.clear();
      _isLoading = user != null;
      _errorMessage = null;
      notifyListeners();
    }
    _loadFromIsar();
  }

  Future<String?> add(Sleep sleep) async {
    _items.insert(0, sleep);
    notifyListeners();
    await TrackingReminderService.instance.handleLogRecorded();

    try {
      final entry = SleepEntry()
        ..date = _isoDate(sleep.date)
        ..bedTime = sleep.bedTime
        ..wakeTime = sleep.wakeTime
        ..quality = sleep.quality.name
        ..qualityValue = sleep.quality.value
        ..notes = sleep.notes
        ..durationMinutes = sleep.duration.inMinutes
        ..timestamp = DateTime.now();
      await AppServices.isar.writeSleepEntry(entry);
      _errorMessage = null;
      notifyListeners();
      return null;
    } catch (e) {
      _errorMessage = 'Could not save sleep log.';
      notifyListeners();
      return _errorMessage;
    }
  }

  Future<void> refresh() => _loadFromIsar();

  Future<void> _loadFromIsar() async {
    final requestId = ++_loadRequestId;
    final uid = _auth.currentUser?.uid;
    final scopeKey = uid ?? 'guest';
    if (_loadedScopeKey != scopeKey) {
      _loadedScopeKey = scopeKey;
      _items.clear();
    }

    _isLoading = true;
    notifyListeners();

    try {
      final entries = await AppServices.isar.getRecentSleepEntries(days: 120);
      if (requestId != _loadRequestId || _loadedScopeKey != scopeKey) return;
      _items
        ..clear()
        ..addAll(entries.map(_fromEntry));
      _errorMessage = null;
    } catch (_) {
      if (requestId != _loadRequestId || _loadedScopeKey != scopeKey) return;
      _errorMessage = 'Could not load sleep logs.';
    } finally {
      if (requestId == _loadRequestId && _loadedScopeKey == scopeKey) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Sleep _fromEntry(SleepEntry e) {
    final quality = SleepQuality.values.firstWhere(
      (q) => q.name == e.quality,
      orElse: () => SleepQuality.fair,
    );
    return Sleep(
      bedTime: e.bedTime,
      wakeTime: e.wakeTime,
      quality: quality,
      date: DateTime.parse(e.date),
      notes: e.notes,
    );
  }

  String _isoDate(DateTime dt) => dt.toIso8601String().substring(0, 10);

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }
}
