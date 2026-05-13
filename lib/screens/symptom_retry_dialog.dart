import 'package:flutter/material.dart';
import 'package:lifelens/app_services.dart';
import 'package:lifelens/services/symptom_retry_service.dart';
import 'package:lifelens/services/weaviate_service.dart';

// ─────────────────────────────────────────────
// Chip tri-state
// ─────────────────────────────────────────────

enum _ChipState { unset, confirmed, denied }

class _ChipData {
  _ChipData(this.label);
  final String label;
  _ChipState state = _ChipState.unset;
}

// ─────────────────────────────────────────────
// Entry point helper
// ─────────────────────────────────────────────

/// Show the retry dialog and return `true` when the entry was refined.
///
/// Call this immediately after a low-confidence initial save.
///
/// [savedEntryId]  — Isar id of the just-saved [SymptomEntry].
/// [baseSymptoms]  — the symptom list used in the initial query.
/// [initialResults]— the Weaviate results from the initial (round-0) query.
/// [initialCertainty] — certainty from the round-0 query.
Future<bool> showSymptomRetryDialog(
  BuildContext context, {
  required int savedEntryId,
  required List<String> baseSymptoms,
  required List<WeaviateDisease> initialResults,
  required double initialCertainty,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => SymptomRetryDialog(
      savedEntryId: savedEntryId,
      baseSymptoms: baseSymptoms,
      initialResults: initialResults,
      initialCertainty: initialCertainty,
    ),
  );
  return result ?? false;
}

// ─────────────────────────────────────────────
// Dialog widget
// ─────────────────────────────────────────────

class SymptomRetryDialog extends StatefulWidget {
  const SymptomRetryDialog({
    super.key,
    required this.savedEntryId,
    required this.baseSymptoms,
    required this.initialResults,
    required this.initialCertainty,
  });

  final int savedEntryId;
  final List<String> baseSymptoms;
  final List<WeaviateDisease> initialResults;
  final double initialCertainty;

  @override
  State<SymptomRetryDialog> createState() => _SymptomRetryDialogState();
}

class _SymptomRetryDialogState extends State<SymptomRetryDialog>
    with SingleTickerProviderStateMixin {
  final _service = SymptomRetryService();
  final _extraController = TextEditingController();

  late List<WeaviateDisease> _currentResults;
  late double _currentCertainty;
  late int _roundNum;

  final Set<String> _alreadyAsked = {};
  final List<String> _confirmedSymptoms = [];
  final List<String> _deniedSymptoms = [];
  List<_ChipData> _chips = [];

  bool _isQuerying = false;
  bool _done = false; // confidence reached or rounds exhausted
  bool _success = false; // confidence reached (vs exhausted)

  late AnimationController _barAnim;
  late Animation<double> _barValue;

  @override
  void initState() {
    super.initState();
    _currentResults = widget.initialResults;
    _currentCertainty = widget.initialCertainty;
    _roundNum = 1;

    _barAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _barValue = Tween<double>(
      begin: 0,
      end: _currentCertainty,
    ).animate(CurvedAnimation(parent: _barAnim, curve: Curves.easeOut));
    _barAnim.forward();

    _buildChips();
  }

  @override
  void dispose() {
    _barAnim.dispose();
    _extraController.dispose();
    super.dispose();
  }

  void _buildChips() {
    final candidates = _service.buildFollowUpCandidates(
      _currentResults,
      _alreadyAsked,
    );
    _chips = candidates.map(_ChipData.new).toList();
  }

  // ── Actions ─────────────────────────────────────────────────────────────────

  Future<void> _requery() async {
    if (_isQuerying) return;

    // Collect confirmed / denied from chips
    for (final chip in _chips) {
      final key = chip.label.toLowerCase();
      _alreadyAsked.add(key);
      if (chip.state == _ChipState.confirmed &&
          !_confirmedSymptoms.contains(chip.label)) {
        _confirmedSymptoms.add(chip.label);
      } else if (chip.state == _ChipState.denied &&
          !_deniedSymptoms.contains(chip.label)) {
        _deniedSymptoms.add(chip.label);
      }
    }

    // Collect free-text additions
    final extra = _extraController.text.trim();
    if (extra.isNotEmpty) {
      final extraSymptoms = extra
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      for (final s in extraSymptoms) {
        if (!_confirmedSymptoms.contains(s)) _confirmedSymptoms.add(s);
      }
      _extraController.clear();
    }

    setState(() => _isQuerying = true);

    try {
      final result = await _service.queryRound(
        baseSymptoms: widget.baseSymptoms,
        confirmed: _confirmedSymptoms,
        denied: _deniedSymptoms,
        roundNum: _roundNum,
      );

      final newCertainty = result.topCertainty;

      // Animate bar to new value
      _barAnim.stop();
      _barValue = Tween<double>(
        begin: _currentCertainty,
        end: newCertainty,
      ).animate(CurvedAnimation(parent: _barAnim, curve: Curves.easeOut));
      _barAnim.forward(from: 0);

      _currentResults = result.results;
      _currentCertainty = newCertainty;
      _roundNum = result.roundsUsed + 1;

      final done = result.confidenceOk || result.exhausted;

      // Persist the refined diagnosis
      if (done || result.confidenceOk) {
        await _persistRefinement(result);
      }

      if (done) {
        setState(() {
          _done = true;
          _success = result.confidenceOk;
          _isQuerying = false;
        });
      } else {
        _buildChips();
        setState(() => _isQuerying = false);
      }
    } catch (e) {
      setState(() => _isQuerying = false);
    }
  }

  Future<void> _skip() async {
    // Persist whatever we have as best-effort
    if (_currentResults.isNotEmpty) {
      final fakeResult = SymptomRetryResult(
        results: _currentResults,
        topCertainty: _currentCertainty,
        confidenceOk: false,
        roundsUsed: _roundNum,
      );
      await _persistRefinement(fakeResult);
    }
    if (mounted) Navigator.of(context).pop(false);
  }

  Future<void> _persistRefinement(SymptomRetryResult result) async {
    if (result.results.isEmpty) return;
    try {
      await AppServices.isar.updateSymptomDiagnosis(
        id: widget.savedEntryId,
        predictedAilment: result.results.first.disease,
        disEmbedScore: result.topCertainty,
        diagnosesJson: result.toDiagnosesJson(),
        resolvedBy: 'retry_${result.roundsUsed}',
        ragUsed: true,
      );
    } catch (e) {
      debugPrint('[SymptomRetryDialog] persist failed: $e');
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: _done ? _buildDoneState(theme, cs) : _buildQueryState(theme, cs),
          ),
        ),
      ),
    );
  }

  // ── Done state ──────────────────────────────────────────────────────────────

  Widget _buildDoneState(ThemeData theme, ColorScheme cs) {
    final icon = _success ? Icons.check_circle_rounded : Icons.info_rounded;
    final iconColor = _success ? Colors.green : cs.primary;
    final headline = _success
        ? 'Confidence reached!'
        : 'Best result saved';
    final sub = _success
        ? 'The entry has been updated with a higher-confidence diagnosis.'
        : 'We\'ve saved the best available result after ${SymptomRetryService.maxRounds} rounds.';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 52, color: iconColor),
        const SizedBox(height: 14),
        Text(
          headline,
          style: theme.textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w900),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          sub,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: cs.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        if (_currentResults.isNotEmpty) ...[
          const SizedBox(height: 16),
          _TopResultCard(
            result: _currentResults.first,
            certainty: _currentCertainty,
            theme: theme,
            cs: cs,
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Done'),
          ),
        ),
      ],
    );
  }

  // ── Query state ─────────────────────────────────────────────────────────────

  Widget _buildQueryState(ThemeData theme, ColorScheme cs) {
    final roundLabel =
        'Round ${_roundNum - 1} of ${SymptomRetryService.maxRounds}';
    final topResult =
        _currentResults.isNotEmpty ? _currentResults.first : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──────────────────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Let's narrow it down",
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    roundLabel,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: _isQuerying ? null : _skip,
              tooltip: 'Skip refinement',
            ),
          ],
        ),
        const SizedBox(height: 14),

        // ── Confidence bar ──────────────────────────────────────────────────
        _ConfidenceBar(
          animation: _barValue,
          cs: cs,
          theme: theme,
        ),
        const SizedBox(height: 16),

        // ── Current best guess ──────────────────────────────────────────────
        if (topResult != null) ...[
          Text(
            'Current best guess',
            style: theme.textTheme.labelMedium
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          _TopResultCard(
            result: topResult,
            certainty: _currentCertainty,
            theme: theme,
            cs: cs,
          ),
          const SizedBox(height: 16),
        ],

        // ── Logged symptoms recap ───────────────────────────────────────────
        Text(
          'Your symptoms',
          style: theme.textTheme.labelMedium
              ?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 6),
        _SymptomRecapChips(
          symptoms: [
            ...widget.baseSymptoms,
            ..._confirmedSymptoms,
          ],
          cs: cs,
        ),
        const SizedBox(height: 16),

        // ── Follow-up chips ─────────────────────────────────────────────────
        if (_chips.isNotEmpty) ...[
          Text(
            'Do any of these also apply?',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap once to confirm ✓, twice to deny ✗, three times to reset.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          _TriStateChipGrid(
            chips: _chips,
            cs: cs,
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: 16),
        ],

        // ── Free-text addition ──────────────────────────────────────────────
        Text(
          'Or add more symptoms',
          style: theme.textTheme.labelMedium
              ?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _extraController,
          enabled: !_isQuerying,
          decoration: const InputDecoration(
            hintText: 'e.g. vomiting, chills',
            isDense: true,
          ),
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: 20),

        // ── Actions ─────────────────────────────────────────────────────────
        Row(
          children: [
            TextButton(
              onPressed: _isQuerying ? null : _skip,
              child: const Text('Skip'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: _isQuerying ? null : _requery,
                child: _isQuerying
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Re-query →'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────

class _ConfidenceBar extends StatelessWidget {
  const _ConfidenceBar({
    required this.animation,
    required this.cs,
    required this.theme,
  });

  final Animation<double> animation;
  final ColorScheme cs;
  final ThemeData theme;

  Color _barColor(double v) {
    if (v >= 0.55) return Colors.green;
    if (v >= SymptomRetryService.confidenceThreshold) return Colors.orange;
    return cs.error;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) {
        final value = animation.value.clamp(0.0, 1.0);
        final pct = (value * 100).toStringAsFixed(1);
        final color = _barColor(value);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Confidence',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
                Text(
                  '$pct%',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 10,
                backgroundColor: cs.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TopResultCard extends StatelessWidget {
  const _TopResultCard({
    required this.result,
    required this.certainty,
    required this.theme,
    required this.cs,
  });

  final WeaviateDisease result;
  final double certainty;
  final ThemeData theme;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            result.disease.isEmpty ? '—' : result.disease,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          if (result.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              result.description.length > 120
                  ? '${result.description.substring(0, 120)}…'
                  : result.description,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _SymptomRecapChips extends StatelessWidget {
  const _SymptomRecapChips({required this.symptoms, required this.cs});

  final List<String> symptoms;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    if (symptoms.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: symptoms
          .map(
            (s) => Chip(
              label: Text(s),
              backgroundColor: cs.primaryContainer,
              labelStyle: TextStyle(
                color: cs.onPrimaryContainer,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
          )
          .toList(),
    );
  }
}

class _TriStateChipGrid extends StatelessWidget {
  const _TriStateChipGrid({
    required this.chips,
    required this.cs,
    required this.onChanged,
  });

  final List<_ChipData> chips;
  final ColorScheme cs;
  final VoidCallback onChanged;

  Color _bgColor(_ChipState state) {
    switch (state) {
      case _ChipState.confirmed:
        return Colors.green.withValues(alpha: 0.15);
      case _ChipState.denied:
        return cs.errorContainer;
      case _ChipState.unset:
        return cs.surfaceContainerHighest;
    }
  }

  Color _labelColor(_ChipState state) {
    switch (state) {
      case _ChipState.confirmed:
        return Colors.green.shade800;
      case _ChipState.denied:
        return cs.onErrorContainer;
      case _ChipState.unset:
        return cs.onSurfaceVariant;
    }
  }

  String _prefix(_ChipState state) {
    switch (state) {
      case _ChipState.confirmed:
        return '✓ ';
      case _ChipState.denied:
        return '✗ ';
      case _ChipState.unset:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chips.map((chip) {
        return GestureDetector(
          onTap: () {
            switch (chip.state) {
              case _ChipState.unset:
                chip.state = _ChipState.confirmed;
              case _ChipState.confirmed:
                chip.state = _ChipState.denied;
              case _ChipState.denied:
                chip.state = _ChipState.unset;
            }
            onChanged();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _bgColor(chip.state),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: chip.state == _ChipState.unset
                    ? cs.outline.withValues(alpha: 0.4)
                    : Colors.transparent,
              ),
            ),
            child: Text(
              '${_prefix(chip.state)}${chip.label}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _labelColor(chip.state),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
