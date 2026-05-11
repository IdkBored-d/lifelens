import 'dart:io';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:dart_wordpiece/dart_wordpiece.dart';

void main() async {
  OrtEnv.instance.init();

  final vocabRaw = File('assets/models/vocab.txt').readAsStringSync();
  final vocab = VocabLoader.fromString(vocabRaw);
  final tokenizer = WordPieceTokenizer(vocab: vocab, config: TokenizerConfig(maxLength: 128, normalizeText: true));

  Map<String, List<int>> _tokenize(String text, int maxLen) {
    final output = tokenizer.encode(text);
    return {
      'input_ids': output.inputIds.take(maxLen).toList(),
      'attention_mask': output.attentionMask.take(maxLen).toList(),
    };
  }

  final bytes = File('assets/models/mobile_bert_emotion.onnx').readAsBytesSync();
  final opts = OrtSessionOptions();
  final session = OrtSession.fromBuffer(bytes, opts);
  
  Future<List<double>> classify(String text) async {
    final tokens = _tokenize(text, 128);
    final ids = tokens['input_ids']!;
    final mask = tokens['attention_mask']!;

    final inputIdsTensor = OrtValueTensor.createTensorWithDataList(ids, [1, 128]);
    final maskTensor = OrtValueTensor.createTensorWithDataList(mask, [1, 128]);

    final inputs = {'input_ids': inputIdsTensor, 'attention_mask': maskTensor};
    final runOptions = OrtRunOptions();
    final outputs = session.run(runOptions, inputs);
    
    final logits = (outputs[0]!.value as List<List<double>>)[0];
    
    inputIdsTensor.release();
    maskTensor.release();
    runOptions.release();
    for (final e in outputs) { e?.release(); }
    
    final maxVal = logits.reduce((a, b) => a > b ? a : b);
    var exps = logits.map((v) {
        double result = 1.0, term = 1.0, x = v - maxVal;
        for (var i = 1; i <= 20; i++) {
          term *= x / i;
          result += term;
        }
        return result;
    }).toList();
    final sum = exps.reduce((a, b) => a + b);
    return exps.map((e) => e / sum).toList();
  }

  final sentences = [
    "I feel so incredibly happy today!", // Expected Joy
    "I am very sad and depressed.", // Expected Sadness
    "I am so angry and furious!", // Expected Anger
    "I am terrified and scared.", // Expected Fear
    "Wow, I did not expect that!", // Expected Surprise
    "I love you so much.", // Expected Love
  ];

  for (var s in sentences) {
    final probs = await classify(s);
    final topId = probs.indexOf(probs.reduce((a, b) => a > b ? a : b));
    print("'$s' -> Top ID: $topId | Probs: ${probs.map((p) => p.toStringAsFixed(3)).toList()}");
  }
}
