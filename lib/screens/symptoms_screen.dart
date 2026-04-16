import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lifelens/app_services.dart';
import 'package:lifelens/database/symptom_entry.dart';
import 'package:lifelens/shared_widgets/log_button_content.dart';
import 'package:lifelens/services/symptom_summary_service.dart';
import 'package:lifelens/services/symptom_auto_detector_service.dart';
import 'package:lifelens/services/tracking_reminder_service.dart';
import 'package:share_plus/share_plus.dart';

class SymptomsScreen extends StatefulWidget {
  const SymptomsScreen({super.key});

  @override
  State<SymptomsScreen> createState() => _SymptomsScreenState();
}

class _SymptomsScreenState extends State<SymptomsScreen> {
  final TextEditingController _symptomsController = TextEditingController();
  final TextEditingController _symptomFocusController = TextEditingController();
  final SymptomSummaryService _summaryService = SymptomSummaryService();

  LogButtonVisualState _saveButtonState = LogButtonVisualState.idle;
  bool _isGeneratingSummary = false;
  SymptomSummaryRange _selectedSummaryRange = SymptomSummaryRange.last30;
  DateTime? _customSummaryStartDate;
  DateTime? _customSummaryEndDate;
  bool _compareWithPreviousPeriod = true;
  SymptomDoctorSummary? _latestSummary;

  @override
  void dispose() {
    _symptomsController.dispose();
    _symptomFocusController.dispose();
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

  String _burdenLabel(SymptomDoctorSummary summary) {
    final activeDays = summary.activeDays;
    final totalDays = summary.windowDays;

    if (activeDays == 0) {
      return 'No clear symptom activity in this period.';
    }
    if (activeDays <= (totalDays / 4).round()) {
      return 'Symptoms showed up occasionally.';
    }
    if (activeDays <= (totalDays / 2).round()) {
      return 'Symptoms showed up regularly.';
    }
    return 'Symptoms showed up frequently.';
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

  Future<void> _pickCustomSummaryDate({required bool isStart}) async {
    final initial = isStart
        ? (_customSummaryStartDate ??
              DateTime.now().subtract(const Duration(days: 14)))
        : (_customSummaryEndDate ?? DateTime.now());

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      if (isStart) {
        _customSummaryStartDate = picked;
      } else {
        _customSummaryEndDate = picked;
      }
    });
  }

  Future<void> _generateDoctorSummary() async {
    if (_isGeneratingSummary) {
      return;
    }

    setState(() => _isGeneratingSummary = true);

    try {
      late final DateTime startDate;
      late final DateTime endDate;
      late final String windowLabel;

      if (_selectedSummaryRange == SymptomSummaryRange.custom) {
        if (_customSummaryStartDate == null || _customSummaryEndDate == null) {
          if (!mounted) {
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please choose both a start and end date.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }

        if (_customSummaryEndDate!.isBefore(_customSummaryStartDate!)) {
          if (!mounted) {
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('End date must be after the start date.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }

        startDate = _customSummaryStartDate!;
        endDate = _customSummaryEndDate!;
        windowLabel = 'Custom range';
      } else {
        final now = DateTime.now();
        startDate = now.subtract(
          Duration(days: _selectedSummaryRange.days - 1),
        );
        endDate = now;
        windowLabel = _selectedSummaryRange.label;
      }

      final summary = await _summaryService.generateSummaryForWindow(
        startDate: startDate,
        endDate: endDate,
        windowLabel: windowLabel,
        compareWithPrevious: _compareWithPreviousPeriod,
        symptomFocus: _symptomFocusController.text,
      );
      if (!mounted) {
        return;
      }

      setState(() => _latestSummary = summary);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Summary generated.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not generate summary right now.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isGeneratingSummary = false);
      }
    }
  }

  Future<void> _shareDoctorSummary() async {
    final summary = _latestSummary;
    if (summary == null) {
      return;
    }

    try {
      await SharePlus.instance.share(
        ShareParams(text: summary.text, subject: 'Symptom Summary'),
      );
    } on MissingPluginException {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Share is not ready yet. Please fully restart the app and try again.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open sharing right now.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _copyDoctorSummary() async {
    final summary = _latestSummary;
    if (summary == null) {
      return;
    }

    await Clipboard.setData(ClipboardData(text: summary.text));
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Summary copied to clipboard.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showFullSummarySheet() async {
    final summary = _latestSummary;
    if (summary == null) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        final cs = theme.colorScheme;

        final topSymptoms = summary.topSymptoms
            .map((e) => _titleCase(e.key))
            .toList();
        final worseningSymptoms = summary.worseningSymptoms
            .map((e) => _titleCase(e.key))
            .toList();
        final improvingSymptoms = summary.improvingSymptoms
            .map((e) => _titleCase(e.key))
            .toList();

        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.9,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your Symptom Summary',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: cs.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${summary.windowLabel} • ${_formatDate(summary.fromDate)} to ${_formatDate(summary.toDate)}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onPrimaryContainer.withValues(alpha: 0.9),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _burdenLabel(summary),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onPrimaryContainer.withValues(
                              alpha: 0.95,
                            ),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _copyDoctorSummary,
                        icon: const Icon(Icons.copy_outlined),
                        label: const Text('Copy'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _shareDoctorSummary,
                        icon: const Icon(Icons.ios_share_outlined),
                        label: const Text('Share'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _ReportSectionCard(
                            title: 'Most common symptoms',
                            body: topSymptoms.isEmpty
                                ? 'No main symptom stood out in this time.'
                                : topSymptoms.join(', '),
                          ),
                          if (summary.compareWithPrevious &&
                              (worseningSymptoms.isNotEmpty ||
                                  improvingSymptoms.isNotEmpty)) ...[
                            const SizedBox(height: 10),
                            _ReportSectionCard(
                              title: 'Simple changes',
                              body:
                                  '${worseningSymptoms.isEmpty ? 'No clear increases.' : 'More: ${worseningSymptoms.take(2).join(', ')}'}\n\n'
                                  '${improvingSymptoms.isEmpty ? 'No clear decreases.' : 'Less: ${improvingSymptoms.take(2).join(', ')}'}',
                            ),
                          ],
                          const SizedBox(height: 10),
                          _ReportSectionCard(
                            title: 'Plain-language summary',
                            body: summary.text,
                            selectable: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
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
                _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionHeader(title: 'Previously Logged Symptoms'),
                      const SizedBox(height: 8),
                      StreamBuilder<List<SymptomEntry>>(
                        stream: _trendStream(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
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

                          final entries = snapshot.data!
                              .toList(growable: false)
                            ..sort(
                              (a, b) => b.timestamp.compareTo(a.timestamp),
                            );

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Recent entries',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 10),
                              ...entries.take(10).map((entry) {
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        symptoms.isEmpty
                                            ? 'Symptom entry'
                                            : symptoms
                                                  .map(_titleCase)
                                                  .join(', '),
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
                              }),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: cs.primaryContainer.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.description_outlined,
                              size: 18,
                              color: cs.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _SectionHeader(
                                  title: 'Doctor Visit Summary',
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Clinical report for appointments and care discussions.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: SymptomSummaryRange.values.map((range) {
                          return FilterChip(
                            label: Text(range.label),
                            selected: _selectedSummaryRange == range,
                            showCheckmark: false,
                            onSelected: (selected) {
                              if (!selected) {
                                return;
                              }
                              setState(() => _selectedSummaryRange = range);
                            },
                          );
                        }).toList(),
                      ),
                      if (_selectedSummaryRange ==
                          SymptomSummaryRange.custom) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () =>
                                  _pickCustomSummaryDate(isStart: true),
                              icon: const Icon(Icons.event_outlined),
                              label: Text(
                                _customSummaryStartDate == null
                                    ? 'Start date'
                                    : 'Start: ${_formatDate(_customSummaryStartDate!)}',
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: () =>
                                  _pickCustomSummaryDate(isStart: false),
                              icon: const Icon(Icons.event_available_outlined),
                              label: Text(
                                _customSummaryEndDate == null
                                    ? 'End date'
                                    : 'End: ${_formatDate(_customSummaryEndDate!)}',
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      SwitchListTile.adaptive(
                        value: _compareWithPreviousPeriod,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Compare with previous period'),
                        subtitle: const Text(
                          'Adds a short note about what seems more or less common.',
                        ),
                        onChanged: (value) {
                          setState(() => _compareWithPreviousPeriod = value);
                        },
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _symptomFocusController,
                        decoration: const InputDecoration(
                          labelText: 'Focus symptom (optional)',
                          hintText: 'e.g. headache',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: _isGeneratingSummary
                                ? null
                                : _generateDoctorSummary,
                            icon: _isGeneratingSummary
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.summarize_outlined),
                            label: Text(
                              _isGeneratingSummary
                                  ? 'Generating...'
                                  : 'Generate summary',
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _latestSummary == null
                                ? null
                                : _shareDoctorSummary,
                            icon: const Icon(Icons.ios_share_outlined),
                            label: const Text('Share'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _latestSummary == null
                                ? null
                                : _copyDoctorSummary,
                            icon: const Icon(Icons.copy_outlined),
                            label: const Text('Copy'),
                          ),
                        ],
                      ),
                      if (_latestSummary != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: cs.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: cs.outlineVariant.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Clinical Snapshot • ${_latestSummary!.windowLabel}',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _burdenLabel(_latestSummary!),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _latestSummary!.text,
                                maxLines: 8,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall,
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  TextButton.icon(
                                    onPressed: _showFullSummarySheet,
                                    icon: const Icon(Icons.open_in_full),
                                    label: const Text('Open full report'),
                                  ),
                                  TextButton.icon(
                                    onPressed: _shareDoctorSummary,
                                    icon: const Icon(Icons.send_outlined),
                                    label: const Text('Share report'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
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

class _ReportSectionCard extends StatelessWidget {
  const _ReportSectionCard({
    required this.title,
    required this.body,
    this.selectable = false,
  });

  final String title;
  final String body;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          selectable
              ? SelectableText(body, style: theme.textTheme.bodySmall)
              : Text(body, style: theme.textTheme.bodySmall),
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
