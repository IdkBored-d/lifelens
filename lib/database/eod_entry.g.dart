// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'eod_entry.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetEodEntryCollection on Isar {
  IsarCollection<EodEntry> get eodEntrys => this.collection();
}

const EodEntrySchema = CollectionSchema(
  name: r'EodEntry',
  id: 7427511614600415612,
  properties: {
    r'correlationSummary': PropertySchema(
      id: 0,
      name: r'correlationSummary',
      type: IsarType.string,
    ),
    r'date': PropertySchema(id: 1, name: r'date', type: IsarType.string),
    r'fitnessScore': PropertySchema(
      id: 2,
      name: r'fitnessScore',
      type: IsarType.double,
    ),
    r'flagReason': PropertySchema(
      id: 3,
      name: r'flagReason',
      type: IsarType.string,
    ),
    r'flagged': PropertySchema(id: 4, name: r'flagged', type: IsarType.bool),
    r'generatedOnline': PropertySchema(
      id: 5,
      name: r'generatedOnline',
      type: IsarType.bool,
    ),
    r'moodEntryCount': PropertySchema(
      id: 6,
      name: r'moodEntryCount',
      type: IsarType.long,
    ),
    r'ragMatch': PropertySchema(
      id: 7,
      name: r'ragMatch',
      type: IsarType.string,
    ),
    r'summaryText': PropertySchema(
      id: 8,
      name: r'summaryText',
      type: IsarType.string,
    ),
    r'timestamp': PropertySchema(
      id: 9,
      name: r'timestamp',
      type: IsarType.dateTime,
    ),
  },

  estimateSize: _eodEntryEstimateSize,
  serialize: _eodEntrySerialize,
  deserialize: _eodEntryDeserialize,
  deserializeProp: _eodEntryDeserializeProp,
  idName: r'id',
  indexes: {
    r'date': IndexSchema(
      id: -7552997827385218417,
      name: r'date',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'date',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'flagged': IndexSchema(
      id: -5901966245719046565,
      name: r'flagged',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'flagged',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
    r'timestamp': IndexSchema(
      id: 1852253767416892198,
      name: r'timestamp',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'timestamp',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _eodEntryGetId,
  getLinks: _eodEntryGetLinks,
  attach: _eodEntryAttach,
  version: '3.3.2',
);

int _eodEntryEstimateSize(
  EodEntry object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.correlationSummary;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.date.length * 3;
  {
    final value = object.flagReason;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.ragMatch;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.summaryText.length * 3;
  return bytesCount;
}

void _eodEntrySerialize(
  EodEntry object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.correlationSummary);
  writer.writeString(offsets[1], object.date);
  writer.writeDouble(offsets[2], object.fitnessScore);
  writer.writeString(offsets[3], object.flagReason);
  writer.writeBool(offsets[4], object.flagged);
  writer.writeBool(offsets[5], object.generatedOnline);
  writer.writeLong(offsets[6], object.moodEntryCount);
  writer.writeString(offsets[7], object.ragMatch);
  writer.writeString(offsets[8], object.summaryText);
  writer.writeDateTime(offsets[9], object.timestamp);
}

EodEntry _eodEntryDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = EodEntry();
  object.correlationSummary = reader.readStringOrNull(offsets[0]);
  object.date = reader.readString(offsets[1]);
  object.fitnessScore = reader.readDouble(offsets[2]);
  object.flagReason = reader.readStringOrNull(offsets[3]);
  object.flagged = reader.readBool(offsets[4]);
  object.generatedOnline = reader.readBool(offsets[5]);
  object.id = id;
  object.moodEntryCount = reader.readLong(offsets[6]);
  object.ragMatch = reader.readStringOrNull(offsets[7]);
  object.summaryText = reader.readString(offsets[8]);
  object.timestamp = reader.readDateTime(offsets[9]);
  return object;
}

P _eodEntryDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readStringOrNull(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readDouble(offset)) as P;
    case 3:
      return (reader.readStringOrNull(offset)) as P;
    case 4:
      return (reader.readBool(offset)) as P;
    case 5:
      return (reader.readBool(offset)) as P;
    case 6:
      return (reader.readLong(offset)) as P;
    case 7:
      return (reader.readStringOrNull(offset)) as P;
    case 8:
      return (reader.readString(offset)) as P;
    case 9:
      return (reader.readDateTime(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _eodEntryGetId(EodEntry object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _eodEntryGetLinks(EodEntry object) {
  return [];
}

void _eodEntryAttach(IsarCollection<dynamic> col, Id id, EodEntry object) {
  object.id = id;
}

extension EodEntryByIndex on IsarCollection<EodEntry> {
  Future<EodEntry?> getByDate(String date) {
    return getByIndex(r'date', [date]);
  }

  EodEntry? getByDateSync(String date) {
    return getByIndexSync(r'date', [date]);
  }

  Future<bool> deleteByDate(String date) {
    return deleteByIndex(r'date', [date]);
  }

  bool deleteByDateSync(String date) {
    return deleteByIndexSync(r'date', [date]);
  }

  Future<List<EodEntry?>> getAllByDate(List<String> dateValues) {
    final values = dateValues.map((e) => [e]).toList();
    return getAllByIndex(r'date', values);
  }

  List<EodEntry?> getAllByDateSync(List<String> dateValues) {
    final values = dateValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'date', values);
  }

  Future<int> deleteAllByDate(List<String> dateValues) {
    final values = dateValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'date', values);
  }

  int deleteAllByDateSync(List<String> dateValues) {
    final values = dateValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'date', values);
  }

  Future<Id> putByDate(EodEntry object) {
    return putByIndex(r'date', object);
  }

  Id putByDateSync(EodEntry object, {bool saveLinks = true}) {
    return putByIndexSync(r'date', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByDate(List<EodEntry> objects) {
    return putAllByIndex(r'date', objects);
  }

  List<Id> putAllByDateSync(List<EodEntry> objects, {bool saveLinks = true}) {
    return putAllByIndexSync(r'date', objects, saveLinks: saveLinks);
  }
}

extension EodEntryQueryWhereSort on QueryBuilder<EodEntry, EodEntry, QWhere> {
  QueryBuilder<EodEntry, EodEntry, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterWhere> anyFlagged() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'flagged'),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterWhere> anyTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'timestamp'),
      );
    });
  }
}

extension EodEntryQueryWhere on QueryBuilder<EodEntry, EodEntry, QWhereClause> {
  QueryBuilder<EodEntry, EodEntry, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterWhereClause> idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterWhereClause> idGreaterThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerId,
          includeLower: includeLower,
          upper: upperId,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterWhereClause> dateEqualTo(String date) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'date', value: [date]),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterWhereClause> dateNotEqualTo(
    String date,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'date',
                lower: [],
                upper: [date],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'date',
                lower: [date],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'date',
                lower: [date],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'date',
                lower: [],
                upper: [date],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterWhereClause> flaggedEqualTo(
    bool flagged,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'flagged', value: [flagged]),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterWhereClause> flaggedNotEqualTo(
    bool flagged,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'flagged',
                lower: [],
                upper: [flagged],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'flagged',
                lower: [flagged],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'flagged',
                lower: [flagged],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'flagged',
                lower: [],
                upper: [flagged],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterWhereClause> timestampEqualTo(
    DateTime timestamp,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'timestamp', value: [timestamp]),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterWhereClause> timestampNotEqualTo(
    DateTime timestamp,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'timestamp',
                lower: [],
                upper: [timestamp],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'timestamp',
                lower: [timestamp],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'timestamp',
                lower: [timestamp],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'timestamp',
                lower: [],
                upper: [timestamp],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterWhereClause> timestampGreaterThan(
    DateTime timestamp, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'timestamp',
          lower: [timestamp],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterWhereClause> timestampLessThan(
    DateTime timestamp, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'timestamp',
          lower: [],
          upper: [timestamp],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterWhereClause> timestampBetween(
    DateTime lowerTimestamp,
    DateTime upperTimestamp, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'timestamp',
          lower: [lowerTimestamp],
          includeLower: includeLower,
          upper: [upperTimestamp],
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension EodEntryQueryFilter
    on QueryBuilder<EodEntry, EodEntry, QFilterCondition> {
  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition>
  correlationSummaryIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'correlationSummary'),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition>
  correlationSummaryIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'correlationSummary'),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition>
  correlationSummaryEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'correlationSummary',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition>
  correlationSummaryGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'correlationSummary',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition>
  correlationSummaryLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'correlationSummary',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition>
  correlationSummaryBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'correlationSummary',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition>
  correlationSummaryStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'correlationSummary',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition>
  correlationSummaryEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'correlationSummary',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition>
  correlationSummaryContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'correlationSummary',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition>
  correlationSummaryMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'correlationSummary',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition>
  correlationSummaryIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'correlationSummary', value: ''),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition>
  correlationSummaryIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'correlationSummary', value: ''),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition> dateEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'date',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition> dateGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'date',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition> dateLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'date',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition> dateBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'date',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition> dateStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'date',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition> dateEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'date',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition> dateContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'date',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition> dateMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'date',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition> dateIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'date', value: ''),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition> dateIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'date', value: ''),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition> fitnessScoreEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'fitnessScore',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition>
  fitnessScoreGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'fitnessScore',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition> fitnessScoreLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'fitnessScore',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition> fitnessScoreBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'fitnessScore',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition> flagReasonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'flagReason'),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition>
  flagReasonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'flagReason'),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition> flagReasonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'flagReason',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition> flagReasonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'flagReason',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition> flagReasonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'flagReason',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition> flagReasonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'flagReason',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition> flagReasonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'flagReason',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition> flagReasonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'flagReason',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition> flagReasonContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'flagReason',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition> flagReasonMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'flagReason',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition> flagReasonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'flagReason', value: ''),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition>
  flagReasonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'flagReason', value: ''),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition> flaggedEqualTo(
    bool value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'flagged', value: value),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition>
  generatedOnlineEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'generatedOnline', value: value),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition> moodEntryCountEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'moodEntryCount', value: value),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition>
  moodEntryCountGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'moodEntryCount',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition>
  moodEntryCountLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'moodEntryCount',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition> moodEntryCountBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'moodEntryCount',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition> ragMatchIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'ragMatch'),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition> ragMatchIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'ragMatch'),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition> ragMatchEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'ragMatch',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition> ragMatchGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'ragMatch',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition> ragMatchLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'ragMatch',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition> ragMatchBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'ragMatch',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition> ragMatchStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'ragMatch',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition> ragMatchEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'ragMatch',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition> ragMatchContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'ragMatch',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition> ragMatchMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'ragMatch',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition> ragMatchIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'ragMatch', value: ''),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition> ragMatchIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'ragMatch', value: ''),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition> summaryTextEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'summaryText',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition>
  summaryTextGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'summaryText',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition> summaryTextLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'summaryText',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition> summaryTextBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'summaryText',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition> summaryTextStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'summaryText',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition> summaryTextEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'summaryText',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition> summaryTextContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'summaryText',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition> summaryTextMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'summaryText',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition> summaryTextIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'summaryText', value: ''),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition>
  summaryTextIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'summaryText', value: ''),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition> timestampEqualTo(
    DateTime value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'timestamp', value: value),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition> timestampGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'timestamp',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition> timestampLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'timestamp',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterFilterCondition> timestampBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'timestamp',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension EodEntryQueryObject
    on QueryBuilder<EodEntry, EodEntry, QFilterCondition> {}

extension EodEntryQueryLinks
    on QueryBuilder<EodEntry, EodEntry, QFilterCondition> {}

extension EodEntryQuerySortBy on QueryBuilder<EodEntry, EodEntry, QSortBy> {
  QueryBuilder<EodEntry, EodEntry, QAfterSortBy> sortByCorrelationSummary() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'correlationSummary', Sort.asc);
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterSortBy>
  sortByCorrelationSummaryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'correlationSummary', Sort.desc);
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterSortBy> sortByDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'date', Sort.asc);
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterSortBy> sortByDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'date', Sort.desc);
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterSortBy> sortByFitnessScore() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fitnessScore', Sort.asc);
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterSortBy> sortByFitnessScoreDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fitnessScore', Sort.desc);
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterSortBy> sortByFlagReason() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'flagReason', Sort.asc);
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterSortBy> sortByFlagReasonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'flagReason', Sort.desc);
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterSortBy> sortByFlagged() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'flagged', Sort.asc);
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterSortBy> sortByFlaggedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'flagged', Sort.desc);
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterSortBy> sortByGeneratedOnline() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'generatedOnline', Sort.asc);
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterSortBy> sortByGeneratedOnlineDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'generatedOnline', Sort.desc);
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterSortBy> sortByMoodEntryCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'moodEntryCount', Sort.asc);
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterSortBy> sortByMoodEntryCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'moodEntryCount', Sort.desc);
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterSortBy> sortByRagMatch() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ragMatch', Sort.asc);
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterSortBy> sortByRagMatchDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ragMatch', Sort.desc);
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterSortBy> sortBySummaryText() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'summaryText', Sort.asc);
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterSortBy> sortBySummaryTextDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'summaryText', Sort.desc);
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterSortBy> sortByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.asc);
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterSortBy> sortByTimestampDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.desc);
    });
  }
}

extension EodEntryQuerySortThenBy
    on QueryBuilder<EodEntry, EodEntry, QSortThenBy> {
  QueryBuilder<EodEntry, EodEntry, QAfterSortBy> thenByCorrelationSummary() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'correlationSummary', Sort.asc);
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterSortBy>
  thenByCorrelationSummaryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'correlationSummary', Sort.desc);
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterSortBy> thenByDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'date', Sort.asc);
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterSortBy> thenByDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'date', Sort.desc);
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterSortBy> thenByFitnessScore() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fitnessScore', Sort.asc);
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterSortBy> thenByFitnessScoreDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fitnessScore', Sort.desc);
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterSortBy> thenByFlagReason() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'flagReason', Sort.asc);
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterSortBy> thenByFlagReasonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'flagReason', Sort.desc);
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterSortBy> thenByFlagged() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'flagged', Sort.asc);
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterSortBy> thenByFlaggedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'flagged', Sort.desc);
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterSortBy> thenByGeneratedOnline() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'generatedOnline', Sort.asc);
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterSortBy> thenByGeneratedOnlineDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'generatedOnline', Sort.desc);
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterSortBy> thenByMoodEntryCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'moodEntryCount', Sort.asc);
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterSortBy> thenByMoodEntryCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'moodEntryCount', Sort.desc);
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterSortBy> thenByRagMatch() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ragMatch', Sort.asc);
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterSortBy> thenByRagMatchDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ragMatch', Sort.desc);
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterSortBy> thenBySummaryText() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'summaryText', Sort.asc);
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterSortBy> thenBySummaryTextDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'summaryText', Sort.desc);
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterSortBy> thenByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.asc);
    });
  }

  QueryBuilder<EodEntry, EodEntry, QAfterSortBy> thenByTimestampDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.desc);
    });
  }
}

extension EodEntryQueryWhereDistinct
    on QueryBuilder<EodEntry, EodEntry, QDistinct> {
  QueryBuilder<EodEntry, EodEntry, QDistinct> distinctByCorrelationSummary({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'correlationSummary',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<EodEntry, EodEntry, QDistinct> distinctByDate({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'date', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<EodEntry, EodEntry, QDistinct> distinctByFitnessScore() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'fitnessScore');
    });
  }

  QueryBuilder<EodEntry, EodEntry, QDistinct> distinctByFlagReason({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'flagReason', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<EodEntry, EodEntry, QDistinct> distinctByFlagged() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'flagged');
    });
  }

  QueryBuilder<EodEntry, EodEntry, QDistinct> distinctByGeneratedOnline() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'generatedOnline');
    });
  }

  QueryBuilder<EodEntry, EodEntry, QDistinct> distinctByMoodEntryCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'moodEntryCount');
    });
  }

  QueryBuilder<EodEntry, EodEntry, QDistinct> distinctByRagMatch({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'ragMatch', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<EodEntry, EodEntry, QDistinct> distinctBySummaryText({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'summaryText', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<EodEntry, EodEntry, QDistinct> distinctByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'timestamp');
    });
  }
}

extension EodEntryQueryProperty
    on QueryBuilder<EodEntry, EodEntry, QQueryProperty> {
  QueryBuilder<EodEntry, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<EodEntry, String?, QQueryOperations>
  correlationSummaryProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'correlationSummary');
    });
  }

  QueryBuilder<EodEntry, String, QQueryOperations> dateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'date');
    });
  }

  QueryBuilder<EodEntry, double, QQueryOperations> fitnessScoreProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'fitnessScore');
    });
  }

  QueryBuilder<EodEntry, String?, QQueryOperations> flagReasonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'flagReason');
    });
  }

  QueryBuilder<EodEntry, bool, QQueryOperations> flaggedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'flagged');
    });
  }

  QueryBuilder<EodEntry, bool, QQueryOperations> generatedOnlineProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'generatedOnline');
    });
  }

  QueryBuilder<EodEntry, int, QQueryOperations> moodEntryCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'moodEntryCount');
    });
  }

  QueryBuilder<EodEntry, String?, QQueryOperations> ragMatchProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'ragMatch');
    });
  }

  QueryBuilder<EodEntry, String, QQueryOperations> summaryTextProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'summaryText');
    });
  }

  QueryBuilder<EodEntry, DateTime, QQueryOperations> timestampProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'timestamp');
    });
  }
}
