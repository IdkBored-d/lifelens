import 'dart:convert';
import 'package:http/http.dart' as http;

/// A single disease entry returned from Weaviate.
class WeaviateDisease {
  final String disease;
  final String symptoms;
  final String description;
  final double certainty; // Weaviate similarity score 0–1

  /// Comma-separated risk factor string from the Weaviate schema.
  /// Null when the field is absent from the collection.
  final String? riskFactors;

  /// Treatment / management steps from the Weaviate schema.
  /// Null when the field is absent from the collection.
  final String? treatment;

  const WeaviateDisease({
    required this.disease,
    required this.symptoms,
    required this.description,
    required this.certainty,
    this.riskFactors,
    this.treatment,
  });

  factory WeaviateDisease.fromJson(Map<String, dynamic> j) {
    final props     = j['properties'] as Map<String, dynamic>? ?? j;
    final meta      = j['_additional'] as Map<String, dynamic>? ?? {};
    return WeaviateDisease(
      disease:     props['disease'] as String? ?? '',
      symptoms:    props['symptoms'] as String? ?? '',
      description: props['description'] as String? ?? '',
      certainty:   (meta['certainty'] as num?)?.toDouble() ?? 0.0,
      riskFactors: props['risk_factors'] as String?,
      treatment:   props['treatment'] as String?,
    );
  }

  /// Format as a grounding block for MiniGen / Gemini prompts.
  /// NOTE: logic may be incorrect -- this is replacing our old version.
  String toPromptBlock() =>
      '• $disease: $description\n  Symptoms: $symptoms';
}

/// Thin Weaviate Cloud client.
/// Only used when the device is online.
/// MiniGen and Gemini call this to ground their responses.
/// NOTE: logic may be incorrect -- this is replacing our old version.
class WeaviateService {
  final String _host;       // e.g. "https://your-cluster.weaviate.network"
  final String _apiKey;     // Weaviate Cloud API key
  final String _className;  // Collection name, e.g. "Disease"

  // DisEmbed output dimensionality (must match what was used to seed Weaviate)
  static const int _vectorDim = 384;

  WeaviateService({
    required String host,
    required String apiKey,
    String className = 'Disease',
  })  : _host      = host,
        _apiKey    = apiKey,
        _className = className;

  /// Query Weaviate for the [topK] most similar diseases to [queryVector].
  ///
  /// [queryVector] is the DisEmbed embedding of the user's symptom text.
  /// Returns an empty list if the request fails — callers must handle offline.
  Future<List<WeaviateDisease>> queryByVector(
    List<double> queryVector, {
    int topK = 5,
  }) async {
    assert(queryVector.length == _vectorDim,
        'Query vector must be $_vectorDim dims, got ${queryVector.length}');

    final uri  = Uri.parse('$_host/v1/graphql');
    final body = jsonEncode({
      'query': '''
        {
          Get {
            $_className(
              nearVector: {
                vector: ${jsonEncode(queryVector)}
                certainty: 0.5
              }
              limit: $topK
            ) {
              disease
              symptoms
              description
              treatment
              risk_factors
              _additional { certainty }
            }
          }
        }
      ''',
    });

    try {
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type':    'application/json',
              'Authorization':   'Bearer $_apiKey',
              'X-Weaviate-Api-Key': _apiKey,
            },
            body: body,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        // Log error in production; return empty list for graceful degradation
        return [];
      }

      final decoded  = jsonDecode(response.body) as Map<String, dynamic>;
      final data     = decoded['data']?['Get']?[_className] as List<dynamic>?;
      if (data == null) return [];

      return data
          .map((e) => WeaviateDisease.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Format a list of Weaviate results into a grounding block for prompts.
  String buildRagContext(List<WeaviateDisease> results) {
    if (results.isEmpty) return '';
    final buffer = StringBuffer('--- RELEVANT CONDITIONS (RAG) ---\n');
    for (final r in results) {
      buffer.writeln(r.toPromptBlock());
    }
    return buffer.toString();
  }
}
