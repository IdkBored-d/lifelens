import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lifelens/models/sleep.dart';
import 'package:lifelens/moodlog_store.dart';
import 'package:lifelens/services/mini_me_suggestions_inbox.dart';
import 'package:lifelens/sleep_store.dart';
import 'package:lifelens/widgets/sleep_log_widget.dart';
import 'package:lifelens/widgets/sleep_tracking_widget.dart';
import 'package:provider/provider.dart';

class SleepScreen extends StatefulWidget {
  const SleepScreen({super.key});

  @override
  State<SleepScreen> createState() => _SleepScreenState();
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

class _SleepScreenState extends State<SleepScreen> {
  bool _showPreviousLogs = false;
  int _sleepFormVersion = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SleepStore>().refresh();
    });
  }

  Future<String?> _addSleepEntry(Sleep sleep) async {
    final sleepStore = context.read<SleepStore>();
    final message = await sleepStore.add(sleep);
    if (!mounted) return message;

    unawaited(
      context.read<MiniMeSuggestionsInbox>().refresh(
        moodStore: context.read<MoodLogStore>(),
        sleepStore: sleepStore,
        fromLog: true,
      ),
    );

    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
    }

    return message;
  }

  void _clearDraft() {
    FocusScope.of(context).unfocus();
    setState(() => _sleepFormVersion++);
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);
    final sleepSelection = context.select<SleepStore, _SleepScreenSelection>(
      (sleepStore) => _SleepScreenSelection.fromItems(sleepStore.items),
    );

    return Scaffold(
      appBar: AppBar(
        leading: canPop ? const BackButton() : null,
        title: const Text('Sleep Log'),
        backgroundColor: Colors.transparent,
        elevation: 0,
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SleepTrackingWidget(
                key: ValueKey(_sleepFormVersion),
                onSleepLogged: _addSleepEntry,
              ),
              const SizedBox(height: 24),
              _SleepHistoryDisclosure(
                expanded: _showPreviousLogs,
                onTap: () {
                  setState(() => _showPreviousLogs = !_showPreviousLogs);
                },
              ),
              if (_showPreviousLogs) ...[
                const SizedBox(height: 12),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: SleepLogWidget(sleepData: sleepSelection.items),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SleepScreenSelection {
  const _SleepScreenSelection({required this.items, required this.signature});

  factory _SleepScreenSelection.fromItems(List<Sleep> items) {
    final today = DateTime.now();
    final visibleItems = items
        .where((item) => _isSameDay(item.date, today))
        .take(20)
        .toList(growable: false);
    final signature = visibleItems
        .map(
          (item) =>
              '${item.date.microsecondsSinceEpoch}:${item.wakeTime.microsecondsSinceEpoch}:${item.duration.inMinutes}:${item.quality.name}:${item.notes}',
        )
        .join('|');
    return _SleepScreenSelection(
      items: visibleItems,
      signature: '${items.length}::$signature',
    );
  }

  final List<Sleep> items;
  final String signature;

  @override
  bool operator ==(Object other) =>
      other is _SleepScreenSelection && other.signature == signature;

  @override
  int get hashCode => signature.hashCode;
}

class _SleepHistoryDisclosure extends StatelessWidget {
  const _SleepHistoryDisclosure({required this.expanded, required this.onTap});

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.32),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.28)),
        ),
        child: Row(
          children: [
            Icon(Icons.bedtime_outlined, size: 20, color: cs.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                expanded ? 'Hide previous logs' : 'View previous logs',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
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
    );
  }
}
