/// Prompt construction and context assembly for MiniGen GGUF inference.
///
/// Encapsulates the fine-tune contract: context brackets, sliding-window
/// history pruning, and emoji sanitization.
///
/// NOTE: logic may be incorrect -- this is replacing our old version.
library;

/// Strips emoji characters from input. Unseen emoji in the BPE vocabulary
/// cause hallucinations in MiniGen.
String sanitizeInput(String input) =>
    input.replaceAll(RegExp(r'\p{Emoji}', unicode: true), '');

/// Sliding-window pruner — operates on the [history] list BEFORE string
/// assembly so no bracket is ever sliced mid-token.
///
/// Budget: 1800 tokens × 4 chars/token = 7 200 chars total.
/// Fixed overhead (context block + current user turn) is subtracted first;
/// the remainder is the history budget. Oldest entries are dropped until
/// the surviving tail fits.
String pruneHistory({
  required String contextBlock,
  required List<String> history,
  required String currentTurn,
}) {
  if (history.isEmpty) return '';

  const kMaxChars = 7200; // 1800 tokens × 4 chars
  final fixedChars = contextBlock.length + currentTurn.length + 2;
  final budgetChars = kMaxChars - fixedChars;
  if (budgetChars <= 0) return '';

  // Walk newest → oldest; accumulate until budget is exhausted.
  var totalChars = 0;
  var keepFrom = history.length;
  for (var i = history.length - 1; i >= 0; i--) {
    final cost = history[i].length + 1; // +1 for the joining '\n'
    if (totalChars + cost > budgetChars) break;
    totalChars += cost;
    keepFrom = i;
  }
  return history.sublist(keepFrom).join('\n');
}

/// Build the context block from key-value entries.
///
/// Rules:
///   • Context brackets are flush — ZERO whitespace between them.
///   • Null / empty entries are silently omitted.
String buildContextBlock(Map<String, String?> contextEntries) {
  return contextEntries.entries
      .where((e) => e.value != null && e.value!.isNotEmpty)
      .map((e) => '[${e.key}: ${e.value}]')
      .join(''); // flush — zero whitespace between brackets
}

/// Formats a prompt per MiniGen's fine-tune contract:
///   {context_block}\n{chat_history}\n<|user|>{userMessage}\n<|companion|>
///
/// Rules:
///   • Context brackets are flush — ZERO whitespace between them.
///   • Null / empty context entries are silently omitted.
///   • [chatHistory] entries are pruned oldest-first via [pruneHistory].
///   • [userMessage] is emoji-stripped via [sanitizeInput].
String buildPrompt({
  required Map<String, String?> contextEntries,
  List<String>? chatHistory,
  required String userMessage,
}) {
  final clean = sanitizeInput(userMessage);
  final block = buildContextBlock(contextEntries);
  final currentTurn = '<|user|>$clean\n<|companion|>';

  final history = pruneHistory(
    contextBlock: block,
    history: chatHistory ?? const [],
    currentTurn: currentTurn,
  );

  final parts = <String>[
    if (block.isNotEmpty) block,
    if (history.isNotEmpty) history,
    currentTurn,
  ];
  return parts.join('\n');
}
