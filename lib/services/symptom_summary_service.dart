import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum SymptomSummaryRange { last7, last14, last30, last90, custom }

extension SymptomSummaryRangeX on SymptomSummaryRange {
  int get days {
    switch (this) {
      case SymptomSummaryRange.last7:
        return 7;
      case SymptomSummaryRange.last14:
        return 14;
      case SymptomSummaryRange.last30:
        return 30;
      case SymptomSummaryRange.last90:
        return 90;
      case SymptomSummaryRange.custom:
        return 0;
    }
  }

  String get label {
    switch (this) {
      case SymptomSummaryRange.last7:
        return 'Last 7 days';
      case SymptomSummaryRange.last14:
        return 'Last 14 days';
      case SymptomSummaryRange.last30:
        return 'Last 30 days';
      case SymptomSummaryRange.last90:
        return 'Last 90 days';
      case SymptomSummaryRange.custom:
        return 'Custom';
    }
  }
}

class SymptomDoctorSummary {
  const SymptomDoctorSummary({
    required this.windowLabel,
    required this.windowDays,
    required this.fromDate,
    required this.toDate,
    required this.compareWithPrevious,
    required this.symptomFocus,
    required this.entryCount,
    required this.totalMentions,
    required this.uniqueSymptoms,
    required this.activeDays,
    required this.topSymptoms,
    required this.worseningSymptoms,
    required this.improvingSymptoms,
    required this.text,
  });

  final String windowLabel;
  final int windowDays;
  final DateTime fromDate;
  final DateTime toDate;
  final bool compareWithPrevious;
  final String? symptomFocus;
  final int entryCount;
  final int totalMentions;
  final int uniqueSymptoms;
  final int activeDays;
  final List<MapEntry<String, int>> topSymptoms;
  final List<MapEntry<String, int>> worseningSymptoms;
  final List<MapEntry<String, int>> improvingSymptoms;
  final String text;
}

class SymptomSummaryService {
  SymptomSummaryService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<SymptomDoctorSummary> generateSummary(
    SymptomSummaryRange range,
  ) async {
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: range.days - 1));

    return generateSummaryForWindow(
      startDate: startDate,
      endDate: now,
      windowLabel: range.label,
      compareWithPrevious: true,
      symptomFocus: null,
    );
  }

  Future<SymptomDoctorSummary> generateSummaryForWindow({
    required DateTime startDate,
    required DateTime endDate,
    required String windowLabel,
    required bool compareWithPrevious,
    String? symptomFocus,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Please sign in to generate a summary.');
    }

    final start = _startOfDay(startDate);
    final endExclusive = _startOfDay(endDate).add(const Duration(days: 1));
    if (!endExclusive.isAfter(start)) {
      throw Exception('Please choose a valid date range.');
    }

    final windowDays = endExclusive.difference(start).inDays;
    final prevStart = start.subtract(Duration(days: windowDays));
    final normalizedFocus = _normalizeFocus(symptomFocus);

    final snapshot = await _firestore
        .collection('symptom_entries')
        .where('userId', isEqualTo: user.uid)
        .limit(2000)
        .get();

    final currentCounts = <String, int>{};
    final previousCounts = <String, int>{};
    var entryCount = 0;
    final activeDaysSet = <DateTime>{};

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final ts = data['createdAt'];
      if (ts is! Timestamp) {
        continue;
      }

      final createdAt = ts.toDate();
      final symptomsRaw = data['symptoms'];
      if (symptomsRaw is! List) {
        continue;
      }

      final symptoms = symptomsRaw
          .whereType<String>()
          .map((s) => s.trim().toLowerCase())
          .where((s) => s.isNotEmpty)
          .where((s) => _matchesFocus(s, normalizedFocus))
          .toList();

      if (symptoms.isEmpty) {
        continue;
      }

      if (!createdAt.isBefore(start) && createdAt.isBefore(endExclusive)) {
        entryCount += 1;
        activeDaysSet.add(_startOfDay(createdAt));
        for (final symptom in symptoms) {
          currentCounts[symptom] = (currentCounts[symptom] ?? 0) + 1;
        }
      } else if (compareWithPrevious &&
          !createdAt.isBefore(prevStart) &&
          createdAt.isBefore(start)) {
        for (final symptom in symptoms) {
          previousCounts[symptom] = (previousCounts[symptom] ?? 0) + 1;
        }
      }
    }

    final topSymptoms = currentCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final allSymptoms = <String>{...currentCounts.keys, ...previousCounts.keys};

    final worsening = <MapEntry<String, int>>[];
    final improving = <MapEntry<String, int>>[];

    for (final symptom in allSymptoms) {
      final curr = currentCounts[symptom] ?? 0;
      final prev = previousCounts[symptom] ?? 0;
      if (compareWithPrevious) {
        if (curr > prev) {
          worsening.add(MapEntry(symptom, curr - prev));
        } else if (prev > curr) {
          improving.add(MapEntry(symptom, prev - curr));
        }
      }
    }

    worsening.sort((a, b) => b.value.compareTo(a.value));
    improving.sort((a, b) => b.value.compareTo(a.value));

    final totalMentions = currentCounts.values.fold<int>(
      0,
      (acc, v) => acc + v,
    );
    final summaryText = _buildSummaryText(
      windowLabel: windowLabel,
      windowDays: windowDays,
      fromDate: start,
      toDate: endExclusive.subtract(const Duration(days: 1)),
      compareWithPrevious: compareWithPrevious,
      symptomFocus: normalizedFocus,
      entryCount: entryCount,
      totalMentions: totalMentions,
      uniqueSymptoms: currentCounts.length,
      activeDays: activeDaysSet.length,
      topSymptoms: topSymptoms.take(5).toList(),
      worseningSymptoms: worsening.take(3).toList(),
      improvingSymptoms: improving.take(3).toList(),
    );

    return SymptomDoctorSummary(
      windowLabel: windowLabel,
      windowDays: windowDays,
      fromDate: start,
      toDate: endExclusive.subtract(const Duration(days: 1)),
      compareWithPrevious: compareWithPrevious,
      symptomFocus: normalizedFocus,
      entryCount: entryCount,
      totalMentions: totalMentions,
      uniqueSymptoms: currentCounts.length,
      activeDays: activeDaysSet.length,
      topSymptoms: topSymptoms.take(5).toList(),
      worseningSymptoms: worsening.take(3).toList(),
      improvingSymptoms: improving.take(3).toList(),
      text: summaryText,
    );
  }

  String _buildSummaryText({
    required String windowLabel,
    required int windowDays,
    required DateTime fromDate,
    required DateTime toDate,
    required bool compareWithPrevious,
    required String? symptomFocus,
    required int entryCount,
    required int totalMentions,
    required int uniqueSymptoms,
    required int activeDays,
    required List<MapEntry<String, int>> topSymptoms,
    required List<MapEntry<String, int>> worseningSymptoms,
    required List<MapEntry<String, int>> improvingSymptoms,
  }) {
    final frequencyLine = activeDays == 0
        ? 'You did not log a clear symptom pattern during this time.'
        : activeDays <= (windowDays / 4).round()
        ? 'Your symptoms showed up once in a while.'
        : activeDays <= (windowDays / 2).round()
        ? 'Your symptoms showed up on several days.'
        : 'Your symptoms showed up on many days.';

    final topList = topSymptoms
        .take(3)
        .map((item) => _titleCase(item.key))
        .toList();
    final topLine = topList.isEmpty
        ? 'No one symptom stood out more than the others.'
        : topList.length == 1
        ? 'The symptom you logged most was ${topList.first}.'
        : 'The symptoms you logged most were ${topList.join(', ')}.';

    String? changeLine;
    if (compareWithPrevious) {
      final changeParts = <String>[];
      if (worseningSymptoms.isNotEmpty) {
        changeParts.add(
          '${_titleCase(worseningSymptoms.first.key)} showed up more often',
        );
      }
      if (improvingSymptoms.isNotEmpty) {
        changeParts.add(
          '${_titleCase(improvingSymptoms.first.key)} showed up less often',
        );
      }
      if (changeParts.isNotEmpty) {
        changeLine =
            'Compared with the earlier time period, ${changeParts.join('. ')}.';
      }
    }

    final overviewLine = entryCount == 0
        ? 'There were no symptom entries in this time range.'
        : entryCount == 1
        ? 'This summary is based on 1 symptom entry.'
        : 'This summary is based on $entryCount symptom entries across $activeDays days.';

    final lines = <String>[
      'Here is a simple look at your symptoms for $windowLabel.',
      '${_formatDate(fromDate)} to ${_formatDate(toDate)}',
      if (symptomFocus != null && symptomFocus.isNotEmpty)
        'Focused on: ${_titleCase(symptomFocus)}',
      '',
      overviewLine,
      frequencyLine,
      topLine,
      if (changeLine != null) changeLine,
    ];

    return lines.join('\n');
  }

  DateTime _startOfDay(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _titleCase(String text) {
    return text
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

  String? _normalizeFocus(String? focus) {
    final value = focus?.trim().toLowerCase();
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }

  bool _matchesFocus(String symptom, String? normalizedFocus) {
    if (normalizedFocus == null) {
      return true;
    }
    return symptom == normalizedFocus || symptom.contains(normalizedFocus);
  }
}
