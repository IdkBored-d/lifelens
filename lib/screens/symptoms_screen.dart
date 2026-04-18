import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lifelens/app_services.dart';
import 'package:lifelens/database/symptom_entry.dart';
import 'package:lifelens/shared_widgets/log_button_content.dart';
import 'package:lifelens/services/symptom_auto_detector_service.dart';
import 'package:lifelens/services/tracking_reminder_service.dart';

class SymptomsScreen extends StatefulWidget {
  const SymptomsScreen({super.key});

  @override
  State<SymptomsScreen> createState() => _SymptomsScreenState();
}

class _SymptomsScreenState extends State<SymptomsScreen> {
  final TextEditingController _symptomsController = TextEditingController();

  LogButtonVisualState _saveButtonState = LogButtonVisualState.idle;
  bool _showPreviousLogs = false;

  @override
  void dispose() {
    _symptomsController.dispose();
    super.dispose();
  }

  List<String> _parseSymptoms() {
    return _symptomsController.text
        .split(',')
        .map((symptom) => symptom.trim())
        .where((symptom) => symptom.isNotEmpty)
        .toList();
  }

  Future<void> _saveSymptoms() async {
    final rawInput = _symptomsController.text.trim();
    final parsedSymptoms = _parseSymptoms();
    final detectedSymptoms = SymptomAutoDetectorService.detectSymptomsFromText(
      rawInput,
    );
    final symptomsForPipeline = detectedSymptoms.isNotEmpty
        ? detectedSymptoms
        : parsedSymptoms;

    if (symptomsForPipeline.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter at least one symptom.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _saveButtonState = LogButtonVisualState.loading);

    final messenger = ScaffoldMessenger.of(context);
    String? syncWarning;

    try {
      HapticFeedback.mediumImpact();

      final savedAt = DateTime.now();
      await _saveSymptomsLocally(
        rawInput: rawInput,
        symptoms: symptomsForPipeline,
        timestamp: savedAt,
      );
      await TrackingReminderService.instance.handleLogRecorded();

      try {
        await _syncSymptomsToCloud(
          rawInput: rawInput,
          symptoms: symptomsForPipeline,
          timestamp: savedAt,
        );
      } catch (_) {
        syncWarning =
            'Saved on this device. Cloud sync failed for this symptom log.';
      }

      _symptomsController.clear();
      setState(() => _saveButtonState = LogButtonVisualState.success);
      if (syncWarning != null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(syncWarning),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      setState(() => _saveButtonState = LogButtonVisualState.idle);
    } catch (error) {
      if (!mounted) return;
      debugPrint('[SymptomsScreen] Save failed: $error');
      final errorMsg = error.toString();
      final truncated = errorMsg.length > 70
          ? '${errorMsg.substring(0, 70)}...'
          : errorMsg;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error: $truncated'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted && _saveButtonState == LogButtonVisualState.loading) {
        setState(() => _saveButtonState = LogButtonVisualState.idle);
      }
    }
  }

  Future<void> _syncSymptomsToCloud({
    required String rawInput,
    required List<String> symptoms,
    required DateTime timestamp,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return;
    }

    await FirebaseFirestore.instance.collection('symptom_entries').add({
      'userId': uid,
      'rawInput': rawInput,
      'symptoms': symptoms,
      'createdAt': Timestamp.fromDate(timestamp),
      'date': Timestamp.fromDate(timestamp),
    });
  }

  Future<void> _saveSymptomsLocally({
    required String rawInput,
    required List<String> symptoms,
    required DateTime timestamp,
  }) async {
    final today = timestamp.toIso8601String().split('T').first;

    final entry = SymptomEntry()
      ..date = today
      ..rawSymptoms = rawInput.isNotEmpty ? rawInput : symptoms.join(', ')
      ..symptomList = symptoms
      ..predictedAilment = 'tracking-only'
      ..disEmbedScore = null
      ..diagnosesJson = '[]'
      ..resolvedBy = 'tracking'
      ..ragUsed = false
      ..wasOffline = true
      ..status = 'active'
      ..timestamp = timestamp
      ..updatedAt = timestamp;

    await AppServices.isar.writeSymptomEntry(entry);
  }

  Stream<List<SymptomEntry>> _trendStream() {
    return AppServices.isar.watchRecentSymptomEntries();
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

  String _formatDateTime(DateTime date) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final meridiem = date.hour >= 12 ? 'PM' : 'AM';
    return '${_formatDate(date)} at $hour:$minute $meridiem';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final canPop = Navigator.canPop(context);

    return Scaffold(
      appBar: AppBar(
        leading: canPop ? const BackButton() : null,
        title: const Text('Symptoms'),
      ),
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.deferToChild,
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Track what you are feeling today.',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Type the symptoms you are having and save.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionHeader(title: 'Symptoms'),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _symptomsController,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          hintText: 'headache, nausea, fatigue',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          "Note: separate your symptoms with ','",
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _HistoryDisclosureCard(
                  expanded: _showPreviousLogs,
                  onTap: () {
                    setState(() => _showPreviousLogs = !_showPreviousLogs);
                  },
                  child: StreamBuilder<List<SymptomEntry>>(
                    stream: _trendStream(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: LinearProgressIndicator(minHeight: 3),
                        );
                      }

                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return Text(
                          'No symptom entries yet. Save one above and it will show up here.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        );
                      }

                      final entries = snapshot.data!.toList(growable: false)
                        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: entries
                            .take(10)
                            .map((entry) {
                              final symptoms = entry.symptomList.isNotEmpty
                                  ? entry.symptomList
                                  : entry.rawSymptoms
                                        .split(',')
                                        .map((item) => item.trim())
                                        .where((item) => item.isNotEmpty)
                                        .toList(growable: false);

                              return Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: cs.surface,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: cs.outlineVariant.withValues(
                                      alpha: 0.4,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      symptoms.isEmpty
                                          ? 'Symptom entry'
                                          : symptoms.map(_titleCase).join(', '),
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatDateTime(entry.timestamp),
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: cs.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              );
                            })
                            .toList(growable: false),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saveButtonState == LogButtonVisualState.loading
                        ? null
                        : _saveSymptoms,
                    child: LogButtonContent(
                      state: _saveButtonState,
                      idleLabel: 'Save entry',
                      loadingLabel: 'Saving symptoms',
                      successLabel: 'Saved',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
    );
  }
}

class _HistoryDisclosureCard extends StatelessWidget {
  const _HistoryDisclosureCard({
    required this.expanded,
    required this.onTap,
    required this.child,
  });

  final bool expanded;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      expanded ? 'Hide previous logs' : 'View previous logs',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[const SizedBox(height: 10), child],
        ],
      ),
    );
  }
}

String _titleCase(String text) {
  return text
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join(' ');
}
