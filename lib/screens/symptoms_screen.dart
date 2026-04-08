import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lifelens/app_services.dart';
import 'package:lifelens/database/symptom_entry.dart';
import 'package:lifelens/services/symptom_summary_service.dart';
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

  bool _isSaving = false;
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
    final parsedSymptoms = _parseSymptoms();
    if (parsedSymptoms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter at least one symptom.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    final messenger = ScaffoldMessenger.of(context);

    try {
      final online = await AppServices.isOnline();
      final result = await AppServices.symptomPipeline.analyze(
        userSymptoms: parsedSymptoms.join(', '),
        isOnline:     online,
      );

      if (!mounted) return;

      HapticFeedback.mediumImpact();

      final topDiagnosis = result.diagnoses.isNotEmpty
          ? result.diagnoses.first.diseaseName
          : 'No triage decision';
      final urgentCount = result.diagnoses.where((d) => d.isUrgent).length;
      final urgentNote  = urgentCount > 0 ? ' · $urgentCount urgent' : '';

      messenger.showSnackBar(
        SnackBar(
          content: Text('Symptoms saved · $topDiagnosis$urgentNote'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );

      _symptomsController.clear();
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not save right now. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Stream<List<SymptomEntry>> _trendStream() {
    return AppServices.isar.watchRecentSymptomEntries();
  }

  _TrendSummary _buildTrendSummary(List<SymptomEntry> docs) {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final twoWeeksAgo = now.subtract(const Duration(days: 14));

    final recentCounts = <String, int>{};
    final previousCounts = <String, int>{};

    for (final doc in docs) {
      final createdAt = doc.timestamp;

      final symptoms = doc.symptomList
          .map((s) => s.trim().toLowerCase())
          .where((s) => s.isNotEmpty)
          .toList();

      if (createdAt.isAfter(weekAgo)) {
        for (final symptom in symptoms) {
          recentCounts[symptom] = (recentCounts[symptom] ?? 0) + 1;
        }
      } else if (createdAt.isAfter(twoWeeksAgo)) {
        for (final symptom in symptoms) {
          previousCounts[symptom] = (previousCounts[symptom] ?? 0) + 1;
        }
      }
    }

    final topRecent = recentCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final totalRecentMentions = recentCounts.values.fold<int>(
      0,
      (sum, value) => sum + value,
    );
    final totalPreviousMentions = previousCounts.values.fold<int>(
      0,
      (sum, value) => sum + value,
    );

    final worsening = <_WorseningItem>[];
    final allKeys = <String>{...recentCounts.keys, ...previousCounts.keys};
    for (final key in allKeys) {
      final recent = recentCounts[key] ?? 0;
      final previous = previousCounts[key] ?? 0;
      if (recent > previous && recent >= 2) {
        worsening.add(_WorseningItem(symptom: key, increase: recent - previous));
      }
    }
    worsening.sort((a, b) => b.increase.compareTo(a.increase));

    return _TrendSummary(
      topRecent: topRecent.take(3).toList(),
      worsening: worsening.take(3).toList(),
      totalRecentMentions: totalRecentMentions,
      totalPreviousMentions: totalPreviousMentions,
      uniqueSymptomsThisWeek: recentCounts.length,
    );
  }

  int _countSymptomInWindow(
    List<SymptomEntry> docs,
    String symptom,
    DateTime start,
    DateTime end,
  ) {
    var count = 0;
    for (final doc in docs) {
      final createdAt = doc.timestamp;
      if (createdAt.isBefore(start) || !createdAt.isBefore(end)) {
        continue;
      }

      final hasSymptom = doc.symptomList.any(
        (s) => s.trim().toLowerCase() == symptom,
      );

      if (hasSymptom) {
        count += 1;
      }
    }
    return count;
  }

  int _activeDaysWithSymptom(
    List<SymptomEntry> docs,
    String symptom,
    int days,
  ) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final daySet = <DateTime>{};

    for (final doc in docs) {
      final createdAt = doc.timestamp;
      if (!createdAt.isAfter(cutoff)) {
        continue;
      }

      final hasSymptom = doc.symptomList.any(
        (s) => s.trim().toLowerCase() == symptom,
      );

      if (hasSymptom) {
        daySet.add(_startOfDay(createdAt));
      }
    }

    return daySet.length;
  }

  List<int> _buildDailySeries(
    List<SymptomEntry> docs,
    String symptom,
  ) {
    final now = DateTime.now();
    final dayStarts = List<DateTime>.generate(
      14,
      (i) => _startOfDay(now.subtract(Duration(days: 13 - i))),
    );

    final countsByDay = <DateTime, int>{
      for (final day in dayStarts) day: 0,
    };

    for (final doc in docs) {
      final day = _startOfDay(doc.timestamp);
      if (!countsByDay.containsKey(day)) {
        continue;
      }

      final matches = doc.symptomList.any(
        (s) => s.trim().toLowerCase() == symptom,
      );

      if (matches) {
        countsByDay[day] = (countsByDay[day] ?? 0) + 1;
      }
    }

    return dayStarts.map((d) => countsByDay[d] ?? 0).toList();
  }

  DateTime _startOfDay(DateTime value) {
    return DateTime(value.year, value.month, value.day);
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

  Future<void> _pickCustomSummaryDate({required bool isStart}) async {
    final initial = isStart
        ? (_customSummaryStartDate ?? DateTime.now().subtract(const Duration(days: 14)))
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
        startDate = now.subtract(Duration(days: _selectedSummaryRange.days - 1));
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
        ShareParams(
          text: summary.text,
          subject: 'Symptom Summary',
        ),
      );
    } on MissingPluginException {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Share is not ready yet. Please fully restart the app and try again.'),
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
                      color: cs.primaryContainer.withOpacity(0.45),
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
                            color: cs.onPrimaryContainer.withOpacity(0.9),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _burdenLabel(summary),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onPrimaryContainer.withOpacity(0.95),
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
                            title: 'Symptoms showing up most often',
                            body: topSymptoms.isEmpty
                                ? 'No predominant symptom identified for this window.'
                              : topSymptoms.join(', '),
                          ),
                          const SizedBox(height: 10),
                          _ReportSectionCard(
                            title: 'Compared with the previous period',
                            body:
                              'Symptoms that increased:\n${worseningSymptoms.isEmpty ? 'None detected.' : worseningSymptoms.join(', ')}\n\n'
                              'Symptoms that improved:\n${improvingSymptoms.isEmpty ? 'None detected.' : improvingSymptoms.join(', ')}',
                          ),
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

  Future<void> _showTrendDetails(
    BuildContext context,
    String symptom,
    List<SymptomEntry> docs,
  ) async {
    final values = _buildDailySeries(docs, symptom);
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final twoWeeksAgo = now.subtract(const Duration(days: 14));

    final thisWeekCount = _countSymptomInWindow(docs, symptom, weekAgo, now);
    final lastWeekCount = _countSymptomInWindow(docs, symptom, twoWeeksAgo, weekAgo);
    final activeDays14 = _activeDaysWithSymptom(docs, symptom, 14);
    final delta = thisWeekCount - lastWeekCount;
    final trendText = delta > 0
        ? 'Up by $delta vs last week'
        : delta < 0
            ? 'Down by ${delta.abs()} vs last week'
            : 'Same as last week';

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        final cs = theme.colorScheme;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _titleCase(symptom),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Last 14 days',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MetricChip(label: 'This week', value: '$thisWeekCount'),
                  _MetricChip(label: 'Last week', value: '$lastWeekCount'),
                  _MetricChip(label: 'Active days', value: '$activeDays14/14'),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                trendText,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              _DailyTrendMiniChart(values: values),
              const SizedBox(height: 8),
              Text(
                'Each bar represents one day. Taller bars mean more entries for this symptom.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
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
                          color: cs.primaryContainer.withOpacity(0.45),
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
                      const _SectionHeader(title: 'Trends'),
                      const SizedBox(height: 8),
                      StreamBuilder<List<SymptomEntry>>(
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
                              'No symptom trends yet. Add a few entries to start seeing patterns.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            );
                          }

                          final summary = _buildTrendSummary(snapshot.data!);

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Top symptoms this week',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (summary.topRecent.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                _TrendBarChart(
                                  items: summary.topRecent,
                                  onTapSymptom: (symptom) {
                                    HapticFeedback.selectionClick();
                                    _showTrendDetails(
                                      context,
                                      symptom,
                                      snapshot.data!,
                                    );
                                  },
                                ),
                                Text(
                                  'Tip: tap a symptom bar for a detailed 14-day breakdown.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ] else ...[
                                const SizedBox(height: 6),
                                Text(
                                  'No symptoms logged in the last 7 days.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
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
                              color: cs.primaryContainer.withOpacity(0.6),
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
                                const _SectionHeader(title: 'Doctor Visit Summary'),
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
                      if (_selectedSummaryRange == SymptomSummaryRange.custom) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _pickCustomSummaryDate(isStart: true),
                              icon: const Icon(Icons.event_outlined),
                              label: Text(
                                _customSummaryStartDate == null
                                    ? 'Start date'
                                    : 'Start: ${_formatDate(_customSummaryStartDate!)}',
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _pickCustomSummaryDate(isStart: false),
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
                        subtitle: const Text('Shows what symptoms are increasing or improving.'),
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
                              color: cs.outlineVariant.withOpacity(0.5),
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
                    onPressed: _isSaving ? null : _saveSymptoms,
                    child: Text(_isSaving ? 'Saving...' : 'Save entry'),
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
        border: Border.all(color: cs.outlineVariant.withOpacity(0.45)),
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

class _TrendSummary {
  const _TrendSummary({
    required this.topRecent,
    required this.worsening,
    required this.totalRecentMentions,
    required this.totalPreviousMentions,
    required this.uniqueSymptomsThisWeek,
  });

  final List<MapEntry<String, int>> topRecent;
  final List<_WorseningItem> worsening;
  final int totalRecentMentions;
  final int totalPreviousMentions;
  final int uniqueSymptomsThisWeek;
}

class _WorseningItem {
  const _WorseningItem({required this.symptom, required this.increase});

  final String symptom;
  final int increase;
}

class _TrendBarChart extends StatelessWidget {
  const _TrendBarChart({
    required this.items,
    required this.onTapSymptom,
  });

  final List<MapEntry<String, int>> items;
  final ValueChanged<String> onTapSymptom;

  @override
  Widget build(BuildContext context) {
    final maxCount = items.fold<int>(0, (max, item) => item.value > max ? item.value : max);

    return Column(
      children: items.map((item) {
        final fraction = maxCount == 0 ? 0.0 : item.value / maxCount;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => onTapSymptom(item.key),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 90,
                      child: Text(
                        _titleCase(item.key),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: fraction,
                          minHeight: 10,
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .outlineVariant
                              .withOpacity(0.35),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${item.value}'),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _titleCase(String text) {
    return text
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }
}

class _DailyTrendMiniChart extends StatelessWidget {
  const _DailyTrendMiniChart({required this.values});

  final List<int> values;

  @override
  Widget build(BuildContext context) {
    final maxValue = values.fold<int>(0, (max, value) => value > max ? value : max);
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      height: 76,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: values.map((value) {
          final normalized = maxValue == 0 ? 0.0 : value / maxValue;
          final barHeight = 8 + (normalized * 56);

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Container(
                height: barHeight,
                decoration: BoxDecoration(
                  color: value > 0 ? cs.primary : cs.outlineVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onPrimaryContainer,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.labelLarge?.copyWith(
              color: cs.onPrimaryContainer,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
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
        border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
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
              ? SelectableText(
                  body,
                  style: theme.textTheme.bodySmall,
                )
              : Text(
                  body,
                  style: theme.textTheme.bodySmall,
                ),
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