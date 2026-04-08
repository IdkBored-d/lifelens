import 'package:flutter/material.dart';
import 'package:lifelens/app_services.dart';
import 'package:lifelens/database/isar_service.dart';
import 'package:lifelens/database/mood_entry.dart';
import 'package:lifelens/database/symptom_entry.dart';
import 'package:lifelens/database/fitness_entry.dart';
import 'package:lifelens/models/escalation_level.dart';        // ← ADD
import 'package:lifelens/models/mood_result.dart';             // ← ADD (kMobileBertLabels)
import 'package:lifelens/models/fitness_result.dart';
import 'package:lifelens/services/confidence_manager.dart';
import 'package:lifelens/services/quick_track_service.dart';   // ← ADD (MoodLogEntry, SymptomLogEntry)
import 'package:lifelens/database/eod_entry.dart';
import 'package:lifelens/services/gemma_model_manager.dart';


/// ─────────────────────────────────────────────────────────────────────────────
/// DEV TEST SCREEN
/// Drop this into your app temporarily for testing pipeline endpoints.
///
/// To use: navigate to this screen from anywhere, e.g. in main.dart:
///   home: const DevTestScreen()
///
/// Remove before shipping to production.
/// ─────────────────────────────────────────────────────────────────────────────
class DevTestScreen extends StatefulWidget {
  const DevTestScreen({super.key});

  @override
  State<DevTestScreen> createState() => _DevTestScreenState();
}

class _DevTestScreenState extends State<DevTestScreen> {
  final List<_TestResult> _results = [];
  bool _running = false;

  // ── Test runner ──────────────────────────────────────────────────────────────

  Future<void> _run(String label, Future<String> Function() test) async {
    setState(() {
      _running = true;
      _results.insert(0, _TestResult(label: label, status: _Status.running));
    });

    try {
      final output = await test();
      setState(() {
        _results[0] = _TestResult(
            label: label, status: _Status.pass, output: output);
      });
    } catch (e) {
      setState(() {
        _results[0] = _TestResult(
            label: label, status: _Status.fail, output: e.toString());
      });
    } finally {
      setState(() => _running = false);
    }
  }

  // ── Individual tests ─────────────────────────────────────────────────────────

  Future<String> _testConfidenceManager() async {
    final cm = ConfidenceManager();

    // MobileBERT — high confidence sadness
    final mb1 = cm.evaluateMobileBert([0.88, 0.05, 0.02, 0.03, 0.01, 0.01]);
    assert(mb1.topLabel == 'sadness', 'Expected sadness');
    assert(mb1.confidenceOk, 'Expected confidence OK');
    assert(mb1.escalation == EscalationLevel.base, 'Expected base');

    // MobileBERT — ambiguous (joy vs sadness too close)
    final mb2 = cm.evaluateMobileBert([0.40, 0.45, 0.05, 0.04, 0.03, 0.03]);
    assert(!mb2.confidenceOk, 'Expected escalation on ambiguous');
    assert(mb2.escalation == EscalationLevel.gemma, 'Expected gemma escalation');

    // MobileBERT — low confidence surprise
    final mb3 = cm.evaluateMobileBert([0.20, 0.15, 0.10, 0.15, 0.15, 0.25]);
    assert(!mb3.confidenceOk, 'Expected escalation on low confidence surprise');

    // DisEmbed — strong similar
    final de1 = cm.evaluateDisEmbed(0.71);
    assert(de1.prediction == 'similar', 'Expected similar');
    assert(de1.confidenceLevel == 'high', 'Expected high confidence');

    // DisEmbed — uncertain zone
    final de2 = cm.evaluateDisEmbed(0.40);
    assert(!de2.confidenceOk, 'Expected uncertain zone escalation');

    // DisEmbed — strong dissimilar
    final de3 = cm.evaluateDisEmbed(0.05);
    assert(de3.prediction == 'dissimilar', 'Expected dissimilar');

    // Fitness — high confidence fit
    final f1 = cm.evaluateFitness([0.10, 0.90]);
    assert(f1.isFit, 'Expected is_fit=true');
    assert(f1.confidenceOk, 'Expected confidence OK');

    // Fitness — low confidence
    final f2 = cm.evaluateFitness([0.40, 0.60]);
    assert(!f2.confidenceOk, 'Expected low confidence flag');

    return '✓ All 8 confidence manager cases passed\n'
        'MB sadness: ${mb1.topLabel} (${(mb1.topProb * 100).toStringAsFixed(1)}%) → ${mb1.escalation.name}\n'
        'MB ambiguous: ${mb2.topLabel} → ${mb2.escalation.name} (${mb2.reason})\n'
        'DE strong similar: ${de1.prediction} (${de1.confidenceLevel})\n'
        'DE uncertain: ${de2.prediction} → ${de2.escalation.name}\n'
        'Fitness high: fit=${f1.isFit} (${(f1.fitProbability * 100).toStringAsFixed(1)}%)\n'
        'Fitness low: confidenceOk=${f2.confidenceOk}';
  }

  Future<String> _testIsarWrite() async {
    final entry = MoodEntry()
      ..date                = '2026-03-21'
      ..rawLog              = 'Dev test entry — feeling good today!'
      ..condensedLog        = 'Feeling good today'
      ..resolvedMood        = 'joy'
      ..resolvedBy          = 'base'
      ..mobileBertPrediction = 'joy'
      ..mobileBertTopProb   = 0.91
      ..userConfirmed       = true
      ..responseText        = 'Great to hear you are feeling joyful!'
      ..fitnessScoreSnapshot = 72.0
      ..timestamp           = DateTime.now();

    await AppServices.isar.writeMoodEntry(entry);
    return '✓ MoodEntry written to ISAR';
  }

  Future<String> _testIsarRead() async {
    final entries = await AppServices.isar.getMoodEntriesForDate('2026-03-21');
    if (entries.isEmpty) {
      return '✗ No entries found — run Write test first';
    }
    final e = entries.last;
    return '✓ Read ${entries.length} entry/entries for 2026-03-21\n'
        'mood=${e.resolvedMood}, resolvedBy=${e.resolvedBy}\n'
        'fitnessSnapshot=${e.fitnessScoreSnapshot}, confirmed=${e.userConfirmed}';
  }

  Future<String> _testIsarSymptomWrite() async {
    final entry = SymptomEntry()
      ..date             = '2026-03-21'
      ..rawSymptoms      = 'Persistent cough, night sweats, fatigue'
      ..symptomList      = ['persistent cough', 'night sweats', 'fatigue']
      ..predictedAilment = 'Possible TB (dev test)'
      ..disEmbedScore    = 0.43
      ..diagnosesJson    = '{"diagnoses": [{"disease": "Test Disease", "reasoning": "test", "next_steps": "see a doctor", "is_urgent": false}]}'
      ..resolvedBy       = 'gemma2b'
      ..ragUsed          = false
      ..wasOffline       = true
      ..status           = 'active'
      ..timestamp        = DateTime.now()
      ..updatedAt        = DateTime.now();

    await AppServices.isar.writeSymptomEntry(entry);
    return '✓ SymptomEntry written to ISAR';
  }

  Future<String> _testIsarFitnessWrite() async {
    final entry = FitnessEntry()
      ..date                  = '2026-03-21'
      ..fitnessScore          = 72.4
      ..fitProbability        = 0.724
      ..isFit                 = true
      ..confidenceOk          = true
      ..dataFreshnessFlagged  = false
      ..age                   = 24
      ..bmi                   = 22.5
      ..heartRate             = 68
      ..sleepHours            = 7.5
      ..smokes                = false
      ..nutritionQuality      = 7.2
      ..activityIndex         = 6.8
      ..isMale                = true
      ..healthDataTimestamp   = DateTime.now()
      ..inferenceTimestamp    = DateTime.now();

    await AppServices.isar.writeFitnessEntry(entry);
    return '✓ FitnessEntry written to ISAR\n'
        'score=${entry.fitnessScore}, isFit=${entry.isFit}';
  }

  Future<String> _testIsarDaySnapshot() async {
    final snapshot = await AppServices.isar.getDaySnapshot('2026-03-21');
    return '✓ DaySnapshot for 2026-03-21\n'
        'moods=${snapshot.moods.length}, '
        'symptoms=${snapshot.symptoms.length}, '
        'hasFitness=${snapshot.hasFitness}, '
        'hasEod=${snapshot.hasEod}';
  }

  Future<String> _testQuickTrackMood() async {
    await AppServices.quickTrack.writeMoodSummary(
      'Mood: Joy (1 day).\nFitness: up 5 pts over 14 days.\n\nDev test insight.',
    );
    final summary = await AppServices.quickTrack.readMoodSummary();
    return '✓ QuickTrack mood summary write succeeded\n'
        'Summary length: ${summary.length} chars\n'
        'Preview: ${summary.substring(0, summary.length.clamp(0, 80))}';
  }

  Future<String> _testQuickTrackSymptom() async {
    await AppServices.quickTrack.writeSymptomSummary(
      'Symptoms: Cough (active, 2 days), Fatigue (active, 1 day).\n\nDev test insight.',
    );
    final summary = await AppServices.quickTrack.readSymptomSummary();
    return '✓ QuickTrack symptom summary write succeeded\n'
        'Summary length: ${summary.length} chars';
  }

  Future<String> _testQuickTrackContext() async {
    final moodCtx    = await AppServices.quickTrack.buildMoodContext();
    final symptomCtx = await AppServices.quickTrack.buildSymptomContext();
    return '✓ Context strings built\n'
        'Mood context length: ${moodCtx.length} chars\n'
        'Symptom context length: ${symptomCtx.length} chars\n'
        'Mood preview: ${moodCtx.substring(0, moodCtx.length.clamp(0, 80))}...';
  }

  Future<String> _testMobileBert() async {
    if (!AppServices.mobileBert.isLoaded) {
      return '✗ MobileBERT not loaded — check asset path in app_services.dart';
    }
    final probs = await AppServices.mobileBert.classify(
      'I feel so incredibly happy today!',
      AppServices.mobileBertTokenize,
    );
    assert(probs.length == 6, 'Expected 6 class probabilities');
    final topIdx   = probs.indexWhere((p) => p == probs.reduce((a, b) => a > b ? a : b));
    final topLabel = kMobileBertLabels[topIdx];
    final topProb  = probs[topIdx];

    final cm     = ConfidenceManager();
    final result = cm.evaluateMobileBert(probs);

    return '✓ MobileBERT inference succeeded\n'
        'Input: "I feel so incredibly happy today!"\n'
        'Top prediction: $topLabel (${(topProb * 100).toStringAsFixed(1)}%)\n'
        'Confidence OK: ${result.confidenceOk}\n'
        'Escalation: ${result.escalation.name}\n'
        'All probs: ${probs.map((p) => p.toStringAsFixed(3)).toList()}';
  }

  Future<String> _testDisEmbed() async {
    if (!AppServices.disEmbed.isLoaded) {
      return '✗ DisEmbed not loaded — check asset path in app_services.dart';
    }

    const sentA = 'Persistent cough with blood-streaked sputum and night sweats.';
    const sentB = 'Fever, weight loss, and prolonged coughing.';
    const sentC = 'Runny nose and itchy eyes after going outside.';

    final embA = await AppServices.disEmbed.embed(sentA, AppServices.disEmbedTokenize);
    final embB = await AppServices.disEmbed.embed(sentB, AppServices.disEmbedTokenize);
    final embC = await AppServices.disEmbed.embed(sentC, AppServices.disEmbedTokenize);

    final simAB = AppServices.disEmbed.cosineSimilarity(embA, embB);
    final simAC = AppServices.disEmbed.cosineSimilarity(embA, embC);

    final cm      = ConfidenceManager();
    final resultAB = cm.evaluateDisEmbed(simAB);
    final resultAC = cm.evaluateDisEmbed(simAC);

    return '✓ DisEmbed inference succeeded\n'
        'Embedding dim: ${embA.length}\n'
        'Similar pair (TB-like) sim: ${simAB.toStringAsFixed(4)} → ${resultAB.prediction} (${resultAB.confidenceLevel})\n'
        'Dissimilar pair sim: ${simAC.toStringAsFixed(4)} → ${resultAC.prediction} (${resultAC.confidenceLevel})\n'
        'AB > AC (expected): ${simAB > simAC}';
  }

  Future<String> _testFitnessMlp() async {
    if (!AppServices.fitnessMlp.isLoaded) {
      return '✗ Fitness MLP not loaded — check asset path in app_services.dart';
    }

    final features = FitnessFeatures(
      age:              24,
      bmi:              22.5,
      heartRate:        68,
      sleepHours:       7.5,
      smokes:           0.0,
      nutritionQuality: 7.2,
      activityIndex:    6.8,
      genderM:          1.0,
    );

    final proba  = await AppServices.fitnessMlp.predict(features);
    final cm     = ConfidenceManager();
    final result = cm.evaluateFitness(proba);

    return '✓ Fitness MLP inference succeeded\n'
        'P(not fit)=${proba[0].toStringAsFixed(4)}, P(fit)=${proba[1].toStringAsFixed(4)}\n'
        'is_fit=${result.isFit}, score=${(result.fitProbability * 100).toStringAsFixed(1)}/100\n'
        'Confidence OK: ${result.confidenceOk}\n'
        'Escalation: ${result.escalation.name}';
  }

  Future<String> _testSyncCheck() async {
    final moodSummary    = await AppServices.quickTrack.readMoodSummary();
    final symptomSummary = await AppServices.quickTrack.readSymptomSummary();
    final convSummary    = await AppServices.quickTrack.readConversationSummary();
    return '✓ Quick-track summaries read\n'
        'Mood summary: ${moodSummary.isEmpty ? "(empty)" : "${moodSummary.length} chars"}\n'
        'Symptom summary: ${symptomSummary.isEmpty ? "(empty)" : "${symptomSummary.length} chars"}\n'
        'Conversation summary: ${convSummary.isEmpty ? "(empty)" : "${convSummary.length} chars"}';
  }

  Future<String> _testIsarEodWrite() async {
    final todayStr = DateTime.now().toIso8601String().split('T').first;
    final entry = EodEntry()
      ..date               = todayStr
      ..summaryText        = 'Dev test EOD summary: Fitness trend is up, mood was joyful.'
      ..correlationSummary = '{"flag": false, "summary": "Great day overall!"}'
      ..flagged            = false
      ..fitnessScore       = 72.4
      ..moodEntryCount     = 3
      ..generatedOnline    = false
      ..timestamp          = DateTime.now();

    // Calls the IsarService to write to the database
    await AppServices.isar.writeEodEntry(entry); 
    
    return '✓ EodEntry written to ISAR';
  }

  Future<String> _testIsarEodRead() async {
    final todayStr = DateTime.now().toIso8601String().split('T').first;
    final entry = await AppServices.isar.getEodEntry(todayStr);
    if (entry == null) {
      return '✗ No EOD entry found for $todayStr — run Write EOD Entry first';
    }
    return '✓ EOD entry found for $todayStr\n'
        'flagged=${entry.flagged}, fitnessScore=${entry.fitnessScore}\n'
        'moodEntryCount=${entry.moodEntryCount}, generatedOnline=${entry.generatedOnline}\n'
        'summary preview: ${entry.summaryText.substring(0, entry.summaryText.length.clamp(0, 80))}...';
  }

  Future<String> _testEodPipeline() async {
    final result = await AppServices.eodPipeline.runEndOfDay(isOnline: false);
    return '✓ EOD pipeline completed (offline/Gemma path)\n'
        'date=${result.date}\n'
        'flagged=${result.flagged}\n'
        'flagReason=${result.flagReason ?? "none"}\n'
        'fitnessScore=${result.fitnessScore}\n'
        'correlation=${result.correlation?.summary ?? "none"}\n'
        'summary preview: ${result.summary.substring(0, result.summary.length.clamp(0, 120))}...';
  }

  Future<String> _testGemmaStatus() async {
    final loaded    = AppServices.isGemmaLoaded;
    final savedPath = await GemmaModelManager.getSavedPath();
    return 'Gemma loaded: $loaded\n'
        'Saved path: ${savedPath.isEmpty ? "(none)" : savedPath}';
  }

  Future<String> _testGemmaInference() async {
    if (!AppServices.isGemmaLoaded) {
      return '✗ Gemma not loaded — complete setup or use Dev mode in GemmaSetupScreen';
    }
    const prompt =
        'Reply with exactly one sentence confirming you are Gemma 2 2B IT '
        'and are running on-device.';
    final response = await AppServices.gemma.generate(prompt);
    return '✓ Gemma inference succeeded\n'
        'Prompt: "$prompt"\n'
        'Response: $response';
  }

  Future<String> _testClearAll() async {
    await AppServices.isar.clearAll();
    final moodEntries    = await AppServices.isar.getMoodEntriesForDate('2026-03-21');
    final symptomEntries = await AppServices.isar.getAllSymptomEntries();
    return '✓ ISAR cleared\n'
        'Mood entries remaining: ${moodEntries.length}\n'
        'Symptom entries remaining: ${symptomEntries.length}';
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          '🛠 LifeLens Dev Tests',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: _running ? null : () => setState(() => _results.clear()),
            child: const Text('Clear', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
      body: Row(
        children: [
          // ── Left: test buttons ──────────────────────────────────────────────
          SizedBox(
            width: 220,
            child: Container(
              color: const Color(0xFF111111),
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _sectionHeader('CONFIDENCE'),
                  _testBtn('Confidence Manager', _testConfidenceManager),

                  _sectionHeader('ISAR DATABASE'),
                  _testBtn('Write Mood Entry', _testIsarWrite),
                  _testBtn('Read Mood Entry', _testIsarRead),
                  _testBtn('Write Symptom Entry', _testIsarSymptomWrite),
                  _testBtn('Write Fitness Entry', _testIsarFitnessWrite),
                  _testBtn('Day Snapshot', _testIsarDaySnapshot),
                  _testBtn('Write EOD Entry', _testIsarEodWrite),
                  _testBtn('Read EOD Entry', _testIsarEodRead),
                  _testBtn('Sync Check', _testSyncCheck),
                  _testBtn('⚠ Clear All ISAR', _testClearAll,
                      color: Colors.red.shade800),

                  _sectionHeader('QUICK-TRACK'),
                  _testBtn('Append Mood Log', _testQuickTrackMood),
                  _testBtn('Append Symptom Log', _testQuickTrackSymptom),
                  _testBtn('Build Context Strings', _testQuickTrackContext),

                  _sectionHeader('ONNX MODELS'),
                  _testBtn('MobileBERT Inference', _testMobileBert),
                  _testBtn('DisEmbed Inference', _testDisEmbed),
                  _testBtn('Fitness MLP Inference', _testFitnessMlp),

                  _sectionHeader('PIPELINES'),
                  _testBtn('EOD Pipeline (offline)', _testEodPipeline),

                  _sectionHeader('GEMMA'),
                  _testBtn('Gemma Status', _testGemmaStatus),
                  _testBtn('Gemma Inference', _testGemmaInference),
                ],
              ),
            ),
          ),

          // ── Right: results ──────────────────────────────────────────────────
          Expanded(
            child: _results.isEmpty
                ? const Center(
                    child: Text(
                      'Run a test to see results here.',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _results.length,
                    itemBuilder: (_, i) => _ResultCard(result: _results[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String label) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 4),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 10,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  Widget _testBtn(String label, Future<String> Function() fn,
      {Color? color}) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: ElevatedButton(
          onPressed: _running ? null : () => _run(label, fn),
          style: ElevatedButton.styleFrom(
            backgroundColor: color ?? const Color(0xFF2A2A2A),
            foregroundColor: Colors.white,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            textStyle: const TextStyle(fontSize: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6)),
          ),
          child: Text(label),
        ),
      );
}

// ── Result card ───────────────────────────────────────────────────────────────

class _ResultCard extends StatelessWidget {
  final _TestResult result;
  const _ResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final (icon, bg, border) = switch (result.status) {
      _Status.pass    => ('✓', const Color(0xFF0D2B1A), const Color(0xFF1DB954)),
      _Status.fail    => ('✗', const Color(0xFF2B0D0D), const Color(0xFFE53935)),
      _Status.running => ('⟳', const Color(0xFF1A1A0D), const Color(0xFFFFB300)),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(icon, style: TextStyle(color: border, fontSize: 14)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  result.label,
                  style: TextStyle(
                    color: border,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ]),
            if (result.output != null) ...[
              const SizedBox(height: 8),
              Text(
                result.output!,
                style: const TextStyle(
                  color: Color(0xFFCCCCCC),
                  fontSize: 11,
                  fontFamily: 'monospace',
                  height: 1.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Data types ────────────────────────────────────────────────────────────────

enum _Status { pass, fail, running }

class _TestResult {
  final String  label;
  final _Status status;
  final String? output;
  const _TestResult({required this.label, required this.status, this.output});
}
