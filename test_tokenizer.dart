import 'dart:io';
import 'package:dart_wordpiece/dart_wordpiece.dart';

void main() {
  final vocabRaw = File('assets/models/vocab.txt').readAsStringSync();
  final vocab = VocabLoader.fromString(vocabRaw);
  final tokenizer = WordPieceTokenizer(vocab: vocab, config: TokenizerConfig(maxLength: 128, normalizeText: true));
  
  final output = tokenizer.encode("I feel so incredibly happy today!");
  print("Input IDs: ${output.inputIds}");
}
