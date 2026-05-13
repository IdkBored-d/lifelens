// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mood_entry.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetMoodEntryCollection on Isar {
  IsarCollection<MoodEntry> get moodEntrys => this.collection();
}

const MoodEntrySchema = CollectionSchema(
  name: r'MoodEntry',
  id: -3945731646672296789,
  properties: {
    r'condensedLog': PropertySchema(
      id: 0,
      name: r'condensedLog',
      type: IsarType.string,
    ),
    r'date': PropertySchema(id: 1, name: r'date', type: IsarType.string),
    r'fitnessScoreSnapshot': PropertySchema(
      id: 2,
      name: r'fitnessScoreSnapshot',
      type: IsarType.double,
    ),
    r'mobileBertPrediction': PropertySchema(
      id: 3,
      name: r'mobileBertPrediction',
      type: IsarType.string,
    ),
    r'mobileBertTopProb': PropertySchema(
      id: 4,
      name: r'mobileBertTopProb',
      type: IsarType.double,
    ),
    r'rawLog': PropertySchema(id: 5, name: r'rawLog', type: IsarType.string),
    r'resolvedBy': PropertySchema(
      id: 6,
      name: r'resolvedBy',
      type: IsarType.string,
    ),
    r'resolvedMood': PropertySchema(
      id: 7,
      name: r'resolvedMood',
      type: IsarType.string,
    ),
    r'responseText': PropertySchema(
      id: 8,
      name: r'responseText',
      type: IsarType.string,
    ),
    r'timestamp': PropertySchema(
      id: 9,
      name: r'timestamp',
      type: IsarType.dateTime,
    ),
  },

  estimateSize: _moodEntryEstimateSize,
  serialize: _moodEntrySerialize,
  deserialize: _moodEntryDeserialize,
  deserializeProp: _moodEntryDeserializeProp,
  idName: r'id',
  indexes: {
    r'date': IndexSchema(
      id: -7552997827385218417,
      name: r'date',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'date',
          type: IndexType.hash,
          caseSensitive: true,
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

  getId: _moodEntryGetId,
  getLinks: _moodEntryGetLinks,
  attach: _moodEntryAttach,
  version: '3.3.2',
);

int _moodEntryEstimateSize(
  MoodEntry object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.condensedLog.length * 3;
  bytesCount += 3 + object.date.length * 3;
  {
    final value = object.mobileBertPrediction;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.rawLog.length * 3;
  bytesCount += 3 + object.resolvedBy.length * 3;
  bytesCount += 3 + object.resolvedMood.length * 3;
  bytesCount += 3 + object.responseText.length * 3;
  return bytesCount;
}

void _moodEntrySerialize(
  MoodEntry object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.condensedLog);
  writer.writeString(offsets[1], object.date);
  writer.writeDouble(offsets[2], object.fitnessScoreSnapshot);
  writer.writeString(offsets[3], object.mobileBertPrediction);
  writer.writeDouble(offsets[4], object.mobileBertTopProb);
  writer.writeString(offsets[5], object.rawLog);
  writer.writeString(offsets[6], object.resolvedBy);
  writer.writeString(offsets[7], object.resolvedMood);
  writer.writeString(offsets[8], object.responseText);
  writer.writeDateTime(offsets[9], object.timestamp);
}

MoodEntry _moodEntryDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = MoodEntry();
  object.condensedLog = reader.readString(offsets[0]);
  object.date = reader.readString(offsets[1]);
  object.fitnessScoreSnapshot = reader.readDouble(offsets[2]);
  object.id = id;
  object.mobileBertPrediction = reader.readStringOrNull(offsets[3]);
  object.mobileBertTopProb = reader.readDoubleOrNull(offsets[4]);
  object.rawLog = reader.readString(offsets[5]);
  object.resolvedBy = reader.readString(offsets[6]);
  object.resolvedMood = reader.readString(offsets[7]);
  object.responseText = reader.readString(offsets[8]);
  object.timestamp = reader.readDateTime(offsets[9]);
  return object;
}

P _moodEntryDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readDouble(offset)) as P;
    case 3:
      return (reader.readStringOrNull(offset)) as P;
    case 4:
      return (reader.readDoubleOrNull(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readString(offset)) as P;
    case 7:
      return (reader.readString(offset)) as P;
    case 8:
      return (reader.readString(offset)) as P;
    case 9:
      return (reader.readDateTime(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _moodEntryGetId(MoodEntry object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _moodEntryGetLinks(MoodEntry object) {
  return [];
}

void _moodEntryAttach(IsarCollection<dynamic> col, Id id, MoodEntry object) {
  object.id = id;
}

extension MoodEntryQueryWhereSort
    on QueryBuilder<MoodEntry, MoodEntry, QWhere> {
  QueryBuilder<MoodEntry, MoodEntry, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterWhere> anyTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'timestamp'),
      );
    });
  }
}

extension MoodEntryQueryWhere
    on QueryBuilder<MoodEntry, MoodEntry, QWhereClause> {
  QueryBuilder<MoodEntry, MoodEntry, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterWhereClause> idNotEqualTo(Id id) {
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

  QueryBuilder<MoodEntry, MoodEntry, QAfterWhereClause> idGreaterThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterWhereClause> idBetween(
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

  QueryBuilder<MoodEntry, MoodEntry, QAfterWhereClause> dateEqualTo(
    String date,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'date', value: [date]),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterWhereClause> dateNotEqualTo(
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

  QueryBuilder<MoodEntry, MoodEntry, QAfterWhereClause> timestampEqualTo(
    DateTime timestamp,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'timestamp', value: [timestamp]),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterWhereClause> timestampNotEqualTo(
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

  QueryBuilder<MoodEntry, MoodEntry, QAfterWhereClause> timestampGreaterThan(
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

  QueryBuilder<MoodEntry, MoodEntry, QAfterWhereClause> timestampLessThan(
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

  QueryBuilder<MoodEntry, MoodEntry, QAfterWhereClause> timestampBetween(
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

extension MoodEntryQueryFilter
    on QueryBuilder<MoodEntry, MoodEntry, QFilterCondition> {
  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition> condensedLogEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'condensedLog',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition>
  condensedLogGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'condensedLog',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition>
  condensedLogLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'condensedLog',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition> condensedLogBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'condensedLog',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition>
  condensedLogStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'condensedLog',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition>
  condensedLogEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'condensedLog',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition>
  condensedLogContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'condensedLog',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition> condensedLogMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'condensedLog',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition>
  condensedLogIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'condensedLog', value: ''),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition>
  condensedLogIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'condensedLog', value: ''),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition> dateEqualTo(
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

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition> dateGreaterThan(
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

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition> dateLessThan(
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

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition> dateBetween(
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

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition> dateStartsWith(
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

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition> dateEndsWith(
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

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition> dateContains(
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

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition> dateMatches(
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

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition> dateIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'date', value: ''),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition> dateIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'date', value: ''),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition>
  fitnessScoreSnapshotEqualTo(double value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'fitnessScoreSnapshot',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition>
  fitnessScoreSnapshotGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'fitnessScoreSnapshot',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition>
  fitnessScoreSnapshotLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'fitnessScoreSnapshot',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition>
  fitnessScoreSnapshotBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'fitnessScoreSnapshot',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition> idEqualTo(
    Id value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition> idGreaterThan(
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

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition> idBetween(
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

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition>
  mobileBertPredictionIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'mobileBertPrediction'),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition>
  mobileBertPredictionIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'mobileBertPrediction'),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition>
  mobileBertPredictionEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'mobileBertPrediction',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition>
  mobileBertPredictionGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'mobileBertPrediction',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition>
  mobileBertPredictionLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'mobileBertPrediction',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition>
  mobileBertPredictionBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'mobileBertPrediction',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition>
  mobileBertPredictionStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'mobileBertPrediction',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition>
  mobileBertPredictionEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'mobileBertPrediction',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition>
  mobileBertPredictionContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'mobileBertPrediction',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition>
  mobileBertPredictionMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'mobileBertPrediction',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition>
  mobileBertPredictionIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'mobileBertPrediction', value: ''),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition>
  mobileBertPredictionIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          property: r'mobileBertPrediction',
          value: '',
        ),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition>
  mobileBertTopProbIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'mobileBertTopProb'),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition>
  mobileBertTopProbIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'mobileBertTopProb'),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition>
  mobileBertTopProbEqualTo(double? value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'mobileBertTopProb',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition>
  mobileBertTopProbGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'mobileBertTopProb',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition>
  mobileBertTopProbLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'mobileBertTopProb',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition>
  mobileBertTopProbBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'mobileBertTopProb',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition> rawLogEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'rawLog',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition> rawLogGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'rawLog',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition> rawLogLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'rawLog',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition> rawLogBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'rawLog',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition> rawLogStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'rawLog',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition> rawLogEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'rawLog',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition> rawLogContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'rawLog',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition> rawLogMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'rawLog',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition> rawLogIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'rawLog', value: ''),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition> rawLogIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'rawLog', value: ''),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition> resolvedByEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'resolvedBy',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition>
  resolvedByGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'resolvedBy',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition> resolvedByLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'resolvedBy',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition> resolvedByBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'resolvedBy',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition>
  resolvedByStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'resolvedBy',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition> resolvedByEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'resolvedBy',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition> resolvedByContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'resolvedBy',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition> resolvedByMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'resolvedBy',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition>
  resolvedByIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'resolvedBy', value: ''),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition>
  resolvedByIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'resolvedBy', value: ''),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition> resolvedMoodEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'resolvedMood',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition>
  resolvedMoodGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'resolvedMood',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition>
  resolvedMoodLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'resolvedMood',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition> resolvedMoodBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'resolvedMood',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition>
  resolvedMoodStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'resolvedMood',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition>
  resolvedMoodEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'resolvedMood',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition>
  resolvedMoodContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'resolvedMood',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition> resolvedMoodMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'resolvedMood',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition>
  resolvedMoodIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'resolvedMood', value: ''),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition>
  resolvedMoodIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'resolvedMood', value: ''),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition> responseTextEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'responseText',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition>
  responseTextGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'responseText',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition>
  responseTextLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'responseText',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition> responseTextBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'responseText',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition>
  responseTextStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'responseText',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition>
  responseTextEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'responseText',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition>
  responseTextContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'responseText',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition> responseTextMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'responseText',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition>
  responseTextIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'responseText', value: ''),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition>
  responseTextIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'responseText', value: ''),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition> timestampEqualTo(
    DateTime value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'timestamp', value: value),
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition>
  timestampGreaterThan(DateTime value, {bool include = false}) {
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

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition> timestampLessThan(
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

  QueryBuilder<MoodEntry, MoodEntry, QAfterFilterCondition> timestampBetween(
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

extension MoodEntryQueryObject
    on QueryBuilder<MoodEntry, MoodEntry, QFilterCondition> {}

extension MoodEntryQueryLinks
    on QueryBuilder<MoodEntry, MoodEntry, QFilterCondition> {}

extension MoodEntryQuerySortBy on QueryBuilder<MoodEntry, MoodEntry, QSortBy> {
  QueryBuilder<MoodEntry, MoodEntry, QAfterSortBy> sortByCondensedLog() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'condensedLog', Sort.asc);
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterSortBy> sortByCondensedLogDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'condensedLog', Sort.desc);
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterSortBy> sortByDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'date', Sort.asc);
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterSortBy> sortByDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'date', Sort.desc);
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterSortBy>
  sortByFitnessScoreSnapshot() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fitnessScoreSnapshot', Sort.asc);
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterSortBy>
  sortByFitnessScoreSnapshotDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fitnessScoreSnapshot', Sort.desc);
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterSortBy>
  sortByMobileBertPrediction() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mobileBertPrediction', Sort.asc);
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterSortBy>
  sortByMobileBertPredictionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mobileBertPrediction', Sort.desc);
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterSortBy> sortByMobileBertTopProb() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mobileBertTopProb', Sort.asc);
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterSortBy>
  sortByMobileBertTopProbDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mobileBertTopProb', Sort.desc);
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterSortBy> sortByRawLog() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rawLog', Sort.asc);
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterSortBy> sortByRawLogDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rawLog', Sort.desc);
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterSortBy> sortByResolvedBy() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolvedBy', Sort.asc);
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterSortBy> sortByResolvedByDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolvedBy', Sort.desc);
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterSortBy> sortByResolvedMood() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolvedMood', Sort.asc);
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterSortBy> sortByResolvedMoodDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolvedMood', Sort.desc);
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterSortBy> sortByResponseText() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'responseText', Sort.asc);
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterSortBy> sortByResponseTextDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'responseText', Sort.desc);
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterSortBy> sortByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.asc);
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterSortBy> sortByTimestampDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.desc);
    });
  }
}

extension MoodEntryQuerySortThenBy
    on QueryBuilder<MoodEntry, MoodEntry, QSortThenBy> {
  QueryBuilder<MoodEntry, MoodEntry, QAfterSortBy> thenByCondensedLog() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'condensedLog', Sort.asc);
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterSortBy> thenByCondensedLogDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'condensedLog', Sort.desc);
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterSortBy> thenByDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'date', Sort.asc);
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterSortBy> thenByDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'date', Sort.desc);
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterSortBy>
  thenByFitnessScoreSnapshot() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fitnessScoreSnapshot', Sort.asc);
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterSortBy>
  thenByFitnessScoreSnapshotDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fitnessScoreSnapshot', Sort.desc);
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterSortBy>
  thenByMobileBertPrediction() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mobileBertPrediction', Sort.asc);
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterSortBy>
  thenByMobileBertPredictionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mobileBertPrediction', Sort.desc);
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterSortBy> thenByMobileBertTopProb() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mobileBertTopProb', Sort.asc);
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterSortBy>
  thenByMobileBertTopProbDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mobileBertTopProb', Sort.desc);
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterSortBy> thenByRawLog() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rawLog', Sort.asc);
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterSortBy> thenByRawLogDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rawLog', Sort.desc);
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterSortBy> thenByResolvedBy() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolvedBy', Sort.asc);
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterSortBy> thenByResolvedByDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolvedBy', Sort.desc);
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterSortBy> thenByResolvedMood() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolvedMood', Sort.asc);
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterSortBy> thenByResolvedMoodDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolvedMood', Sort.desc);
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterSortBy> thenByResponseText() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'responseText', Sort.asc);
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterSortBy> thenByResponseTextDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'responseText', Sort.desc);
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterSortBy> thenByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.asc);
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QAfterSortBy> thenByTimestampDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.desc);
    });
  }
}

extension MoodEntryQueryWhereDistinct
    on QueryBuilder<MoodEntry, MoodEntry, QDistinct> {
  QueryBuilder<MoodEntry, MoodEntry, QDistinct> distinctByCondensedLog({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'condensedLog', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QDistinct> distinctByDate({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'date', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QDistinct>
  distinctByFitnessScoreSnapshot() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'fitnessScoreSnapshot');
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QDistinct> distinctByMobileBertPrediction({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'mobileBertPrediction',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QDistinct> distinctByMobileBertTopProb() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'mobileBertTopProb');
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QDistinct> distinctByRawLog({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'rawLog', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QDistinct> distinctByResolvedBy({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'resolvedBy', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QDistinct> distinctByResolvedMood({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'resolvedMood', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QDistinct> distinctByResponseText({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'responseText', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MoodEntry, MoodEntry, QDistinct> distinctByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'timestamp');
    });
  }
}

extension MoodEntryQueryProperty
    on QueryBuilder<MoodEntry, MoodEntry, QQueryProperty> {
  QueryBuilder<MoodEntry, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<MoodEntry, String, QQueryOperations> condensedLogProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'condensedLog');
    });
  }

  QueryBuilder<MoodEntry, String, QQueryOperations> dateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'date');
    });
  }

  QueryBuilder<MoodEntry, double, QQueryOperations>
  fitnessScoreSnapshotProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'fitnessScoreSnapshot');
    });
  }

  QueryBuilder<MoodEntry, String?, QQueryOperations>
  mobileBertPredictionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'mobileBertPrediction');
    });
  }

  QueryBuilder<MoodEntry, double?, QQueryOperations>
  mobileBertTopProbProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'mobileBertTopProb');
    });
  }

  QueryBuilder<MoodEntry, String, QQueryOperations> rawLogProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'rawLog');
    });
  }

  QueryBuilder<MoodEntry, String, QQueryOperations> resolvedByProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'resolvedBy');
    });
  }

  QueryBuilder<MoodEntry, String, QQueryOperations> resolvedMoodProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'resolvedMood');
    });
  }

  QueryBuilder<MoodEntry, String, QQueryOperations> responseTextProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'responseText');
    });
  }

  QueryBuilder<MoodEntry, DateTime, QQueryOperations> timestampProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'timestamp');
    });
  }
}
