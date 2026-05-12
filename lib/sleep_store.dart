import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:lifelens/services/tracking_reminder_service.dart';

import 'models/sleep.dart';

class SleepStore extends ChangeNotifier {
  SleepStore({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance {
    _authSub = _auth.authStateChanges().listen((user) {
      _handleAuthChanged(user);
    });
    _loadFromCloud();
  }

  final FirebaseFirestore _firestore;
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
    _loadFromCloud();
  }

  Future<String?> add(Sleep sleep) async {
    _items.insert(0, sleep);
    notifyListeners();
    await TrackingReminderService.instance.handleLogRecorded();

    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      _errorMessage = 'Saved locally. Sign in to sync sleep logs to cloud.';
      notifyListeners();
      return _errorMessage;
    }

    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('sleep_logs')
          .add(_toFirestore(sleep));
      _errorMessage = null;
      notifyListeners();
      return null;
    } on FirebaseException {
      _errorMessage = 'Saved locally. Cloud sync failed for this sleep log.';
      notifyListeners();
      return _errorMessage;
    }
  }

  Future<void> refresh() => _loadFromCloud();

  Future<void> _loadFromCloud() async {
    final requestId = ++_loadRequestId;
    final uid = _auth.currentUser?.uid;
    final scopeKey = uid ?? 'guest';
    if (_loadedScopeKey != scopeKey) {
      _loadedScopeKey = scopeKey;
      _items.clear();
    }
    if (uid == null) {
      _items.clear();
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('sleep_logs')
          .orderBy('date', descending: true)
          .limit(120)
          .get();

      if (requestId != _loadRequestId || _loadedScopeKey != scopeKey) return;

      _items
        ..clear()
        ..addAll(snapshot.docs.map(_fromFirestore));
      _errorMessage = null;
    } on FirebaseException {
      if (requestId != _loadRequestId || _loadedScopeKey != scopeKey) return;
      _errorMessage = 'Could not sync sleep logs from cloud.';
    } finally {
      if (requestId == _loadRequestId && _loadedScopeKey == scopeKey) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Map<String, dynamic> _toFirestore(Sleep sleep) {
    return {
      'bedTime': Timestamp.fromDate(sleep.bedTime),
      'wakeTime': Timestamp.fromDate(sleep.wakeTime),
      'quality': sleep.quality.name,
      'qualityValue': sleep.quality.value,
      'date': Timestamp.fromDate(sleep.date),
      'notes': sleep.notes,
      'durationMinutes': sleep.duration.inMinutes,
    };
  }

  Sleep _fromFirestore(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();

    final bedTime = _parseDate(data['bedTime']) ?? DateTime.now();
    final wakeTime = _parseDate(data['wakeTime']) ?? DateTime.now();
    final date = _parseDate(data['date']) ?? DateTime.now();
    final qualityName = (data['quality'] ?? 'fair').toString();

    final quality = SleepQuality.values.firstWhere(
      (item) => item.name == qualityName,
      orElse: () => SleepQuality.fair,
    );

    return Sleep(
      bedTime: bedTime,
      wakeTime: wakeTime,
      quality: quality,
      date: date,
      notes: (data['notes'] ?? '').toString(),
    );
  }

  DateTime? _parseDate(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }
}
