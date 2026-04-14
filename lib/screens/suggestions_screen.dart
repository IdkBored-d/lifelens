import 'package:flutter/material.dart';
import 'package:lifelens/exercises/exercise_screen.dart';
import 'package:lifelens/moodlog_screen.dart';
import 'package:lifelens/screens/sleep_screen.dart';
import 'package:lifelens/screens/symptoms_screen.dart';
import 'package:lifelens/services/daily_suggestions_service.dart';
import 'package:lifelens/moodlog_store.dart';
import 'package:lifelens/sleep_store.dart';
import 'package:provider/provider.dart';

class SuggestionsScreen extends StatefulWidget {
  const SuggestionsScreen({super.key});

  @override
  State<SuggestionsScreen> createState() => _SuggestionsScreenState();
}

class _SuggestionsScreenState extends State<SuggestionsScreen> {
  DailySuggestionsSnapshot? _snapshot;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSuggestions();
    });
  }

  Future<void> _loadSuggestions({bool refreshStores = true}) async {
    final moodStore = context.read<MoodLogStore>();
    final sleepStore = context.read<SleepStore>();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (refreshStores) {
        await moodStore.refreshFromPersistence();
        await sleepStore.refresh();
      }

      final snapshot = await DailySuggestionsService.instance.buildSnapshot(
        moodStore: moodStore,
        sleepStore: sleepStore,
      );

      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not load suggestions right now.';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleSuggestionAction(DailySuggestion suggestion) async {
    final category = suggestion.category.toLowerCase();
    Widget? destination;

    if (category == 'mood' || category == 'follow-through') {
      destination = const MoodLogScreen(source: LogSource.tab);
    } else if (category == 'sleep') {
      destination = const SleepScreen();
    } else if (category == 'symptoms') {
      destination = const SymptomsScreen();
    } else if (category == 'exercise' || category == 'fitness') {
      destination = const ExerciseScreen();
    }

    if (destination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(suggestion.action),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => destination!));

    if (!mounted) return;
    await _loadSuggestions();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canPop = Navigator.canPop(context);

    return Scaffold(
      appBar: AppBar(
        leading: canPop ? const BackButton() : null,
        title: const Text('Suggestions'),
        actions: [
          IconButton(
            tooltip: 'Refresh suggestions',
            onPressed: _isLoading ? null : () => _loadSuggestions(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _loadSuggestions(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
            children: [
              Text(
                'What to do today',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              if (_isLoading) ...[
                const _SuggestionLoadingCard(),
                const SizedBox(height: 14),
                const _SuggestionLoadingCard(),
                const SizedBox(height: 14),
                const _SuggestionLoadingCard(),
              ] else if (_errorMessage != null) ...[
                _SuggestionsErrorCard(
                  message: _errorMessage!,
                  onRetry: _loadSuggestions,
                ),
              ] else if (_snapshot != null) ...[
                ..._snapshot!.suggestions.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _SuggestionCard(
                      suggestion: item,
                      onPressed: () => _handleSuggestionAction(item),
                    ),
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

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.suggestion,
    required this.onPressed,
  });

  final DailySuggestion suggestion;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(suggestion.icon, color: cs.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      suggestion.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            suggestion.action,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Open'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionsErrorCard extends StatelessWidget {
  const _SuggestionsErrorCard({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: onRetry,
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}

class _SuggestionLoadingCard extends StatelessWidget {
  const _SuggestionLoadingCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
      ),
    );
  }
}
