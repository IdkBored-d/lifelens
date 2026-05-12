import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lifelens/app_services.dart';
import 'package:lifelens/database/symptom_entry.dart';
import 'package:lifelens/shared_widgets/log_button_content.dart';
import 'package:lifelens/services/mini_me_suggestions_inbox.dart';
import 'package:lifelens/services/symptom_auto_detector_service.dart';
import 'package:lifelens/services/tracking_reminder_service.dart';
import 'package:provider/provider.dart';

class SymptomsScreen extends StatefulWidget {
  const SymptomsScreen({super.key});

  @override
  State<SymptomsScreen> createState() => _SymptomsScreenState();
}

class _SymptomsScreenState extends State<SymptomsScreen> {
  final TextEditingController _symptomsController = TextEditingController();
  late final Stream<List<SymptomEntry>> _trendEntriesStream = AppServices.isar
      .watchRecentSymptomEntries();
  static const int _symptomWordLimit = 150;

  LogButtonVisualState _saveButtonState = LogButtonVisualState.idle;
  bool _showPreviousLogs = false;

  int _wordCount(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 0;
    return trimmed.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  }

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

    try {
      HapticFeedback.mediumImpact();

      final isOnline = await AppServices.isOnline();
      const List<String> miniMeTop3 = [];
      final now = DateTime.now();
      await AppServices.isar.writeSymptomEntry(
        SymptomEntry()
          ..date = now.toIso8601String().substring(0, 10)
          ..rawSymptoms = symptomsForPipeline.join(', ')
          ..symptomList = symptomsForPipeline
          ..predictedAilment = ''
          ..disEmbedScore = null
          ..diagnosesJson = '[]'
          ..resolvedBy = 'none'
          ..ragUsed = false
          ..wasOffline = !isOnline
          ..status = 'monitoring'
          ..timestamp = now
          ..updatedAt = now,
      );

      await TrackingReminderService.instance.handleLogRecorded();

      _symptomsController.clear();
      setState(() => _saveButtonState = LogButtonVisualState.success);
      if (mounted) {
        final inbox = context.read<MiniMeSuggestionsInbox>();
        if (miniMeTop3.isNotEmpty) {
          await inbox.enqueueSymptomInsight(
            topConditions: miniMeTop3,
            symptoms: symptomsForPipeline,
          );
        } else {
          await inbox.enqueueSymptomLogSaved(symptoms: symptomsForPipeline);
        }
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

  void _clearDraft() {
    FocusScope.of(context).unfocus();
    setState(() {
      _symptomsController.clear();
      _saveButtonState = LogButtonVisualState.idle;
    });
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
        title: const Text('Symptoms Log'),
        actions: [
          IconButton(
            tooltip: 'Clear draft',
            iconSize: 30,
            style: IconButton.styleFrom(
              minimumSize: const Size.square(52),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: _clearDraft,
            icon: const Icon(Icons.restart_alt_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.deferToChild,
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Log your symptoms',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Add a quick list or a short note. Use commas to separate symptoms.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 18),
                _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionHeader(title: 'Symptoms'),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _symptomsController,
                        maxLines: 5,
                        inputFormatters: const [
                          _WordLimitTextInputFormatter(_symptomWordLimit),
                        ],
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 16,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              "Example: headache, nausea, fatigue",
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                          Text(
                            '${_wordCount(_symptomsController.text)}/$_symptomWordLimit',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _HistoryDisclosureCard(
                  expanded: _showPreviousLogs,
                  onTap: () {
                    setState(() => _showPreviousLogs = !_showPreviousLogs);
                  },
                  child: _SymptomHistoryList(
                    entriesStream: _trendEntriesStream,
                    formatDateTime: _formatDateTime,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saveButtonState == LogButtonVisualState.loading
                        ? null
                        : _saveSymptoms,
                    child: LogButtonContent(
                      state: _saveButtonState,
                      idleLabel: 'Log symptom entry',
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: child,
    );
  }
}

class _WordLimitTextInputFormatter extends TextInputFormatter {
  const _WordLimitTextInputFormatter(this.maxWords);

  final int maxWords;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final trimmed = newValue.text.trim();
    if (trimmed.isEmpty) {
      return newValue;
    }

    final words = trimmed.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    if (words.length <= maxWords) {
      return newValue;
    }

    return oldValue;
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
                  Icon(Icons.healing_outlined, size: 20, color: cs.primary),
                  const SizedBox(width: 10),
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

class _SymptomHistoryList extends StatelessWidget {
  const _SymptomHistoryList({
    required this.entriesStream,
    required this.formatDateTime,
  });

  final Stream<List<SymptomEntry>> entriesStream;
  final String Function(DateTime date) formatDateTime;

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isTodayEntry(SymptomEntry entry) {
    final today = DateTime.now();
    final entryDate = DateTime.tryParse(entry.date);
    if (entryDate != null) {
      return _isSameDay(entryDate, today);
    }
    return _isSameDay(entry.timestamp, today);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return StreamBuilder<List<SymptomEntry>>(
      stream: entriesStream,
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

        final entries =
            snapshot.data!.where(_isTodayEntry).toList(growable: false)
              ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

        if (entries.isEmpty) {
          return Text(
            'No symptom entries yet today. Save one above and it will show up here.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: entries
              .take(10)
              .map(
                (entry) => _SymptomHistoryCard(
                  entry: entry,
                  formattedDateTime: formatDateTime(entry.timestamp),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _SymptomHistoryCard extends StatelessWidget {
  const _SymptomHistoryCard({
    required this.entry,
    required this.formattedDateTime,
  });

  final SymptomEntry entry;
  final String formattedDateTime;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
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
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            symptoms.isEmpty
                ? 'Symptom entry'
                : symptoms.map(_titleCase).join(', '),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formattedDateTime,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
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
