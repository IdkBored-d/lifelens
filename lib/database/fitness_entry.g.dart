// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fitness_entry.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetFitnessEntryCollection on Isar {
  IsarCollection<FitnessEntry> get fitnessEntrys => this.collection();
}

const FitnessEntrySchema = CollectionSchema(
  name: r'FitnessEntry',
  id: 1692341650945572040,
  properties: {
    r'activityIndex': PropertySchema(
      id: 0,
      name: r'activityIndex',
      type: IsarType.double,
    ),
    r'age': PropertySchema(id: 1, name: r'age', type: IsarType.double),
    r'bmi': PropertySchema(id: 2, name: r'bmi', type: IsarType.double),
    r'confidenceOk': PropertySchema(
      id: 3,
      name: r'confidenceOk',
      type: IsarType.bool,
    ),
    r'dataFreshnessFlagged': PropertySchema(
      id: 4,
      name: r'dataFreshnessFlagged',
      type: IsarType.bool,
    ),
    r'date': PropertySchema(id: 5, name: r'date', type: IsarType.string),
    r'fitProbability': PropertySchema(
      id: 6,
      name: r'fitProbability',
      type: IsarType.double,
    ),
    r'fitnessScore': PropertySchema(
      id: 7,
      name: r'fitnessScore',
      type: IsarType.double,
    ),
    r'healthDataTimestamp': PropertySchema(
      id: 8,
      name: r'healthDataTimestamp',
      type: IsarType.dateTime,
    ),
    r'heartRate': PropertySchema(
      id: 9,
      name: r'heartRate',
      type: IsarType.double,
    ),
    r'inferenceTimestamp': PropertySchema(
      id: 10,
      name: r'inferenceTimestamp',
      type: IsarType.dateTime,
    ),
    r'isFit': PropertySchema(id: 11, name: r'isFit', type: IsarType.bool),
    r'isMale': PropertySchema(id: 12, name: r'isMale', type: IsarType.bool),
    r'isOnboardingSnapshot': PropertySchema(
      id: 13,
      name: r'isOnboardingSnapshot',
      type: IsarType.bool,
    ),
    r'nutritionQuality': PropertySchema(
      id: 14,
      name: r'nutritionQuality',
      type: IsarType.double,
    ),
    r'sleepHours': PropertySchema(
      id: 15,
      name: r'sleepHours',
      type: IsarType.double,
    ),
    r'smokes': PropertySchema(id: 16, name: r'smokes', type: IsarType.bool),
  },

  estimateSize: _fitnessEntryEstimateSize,
  serialize: _fitnessEntrySerialize,
  deserialize: _fitnessEntryDeserialize,
  deserializeProp: _fitnessEntryDeserializeProp,
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
    r'inferenceTimestamp': IndexSchema(
      id: -4925102662655602386,
      name: r'inferenceTimestamp',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'inferenceTimestamp',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _fitnessEntryGetId,
  getLinks: _fitnessEntryGetLinks,
  attach: _fitnessEntryAttach,
  version: '3.3.2',
);

int _fitnessEntryEstimateSize(
  FitnessEntry object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.date.length * 3;
  return bytesCount;
}

void _fitnessEntrySerialize(
  FitnessEntry object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDouble(offsets[0], object.activityIndex);
  writer.writeDouble(offsets[1], object.age);
  writer.writeDouble(offsets[2], object.bmi);
  writer.writeBool(offsets[3], object.confidenceOk);
  writer.writeBool(offsets[4], object.dataFreshnessFlagged);
  writer.writeString(offsets[5], object.date);
  writer.writeDouble(offsets[6], object.fitProbability);
  writer.writeDouble(offsets[7], object.fitnessScore);
  writer.writeDateTime(offsets[8], object.healthDataTimestamp);
  writer.writeDouble(offsets[9], object.heartRate);
  writer.writeDateTime(offsets[10], object.inferenceTimestamp);
  writer.writeBool(offsets[11], object.isFit);
  writer.writeBool(offsets[12], object.isMale);
  writer.writeBool(offsets[13], object.isOnboardingSnapshot);
  writer.writeDouble(offsets[14], object.nutritionQuality);
  writer.writeDouble(offsets[15], object.sleepHours);
  writer.writeBool(offsets[16], object.smokes);
}

FitnessEntry _fitnessEntryDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = FitnessEntry();
  object.activityIndex = reader.readDouble(offsets[0]);
  object.age = reader.readDouble(offsets[1]);
  object.bmi = reader.readDouble(offsets[2]);
  object.confidenceOk = reader.readBool(offsets[3]);
  object.dataFreshnessFlagged = reader.readBool(offsets[4]);
  object.date = reader.readString(offsets[5]);
  object.fitProbability = reader.readDouble(offsets[6]);
  object.fitnessScore = reader.readDouble(offsets[7]);
  object.healthDataTimestamp = reader.readDateTime(offsets[8]);
  object.heartRate = reader.readDouble(offsets[9]);
  object.id = id;
  object.inferenceTimestamp = reader.readDateTime(offsets[10]);
  object.isFit = reader.readBool(offsets[11]);
  object.isMale = reader.readBool(offsets[12]);
  object.isOnboardingSnapshot = reader.readBool(offsets[13]);
  object.nutritionQuality = reader.readDouble(offsets[14]);
  object.sleepHours = reader.readDouble(offsets[15]);
  object.smokes = reader.readBool(offsets[16]);
  return object;
}

P _fitnessEntryDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDouble(offset)) as P;
    case 1:
      return (reader.readDouble(offset)) as P;
    case 2:
      return (reader.readDouble(offset)) as P;
    case 3:
      return (reader.readBool(offset)) as P;
    case 4:
      return (reader.readBool(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readDouble(offset)) as P;
    case 7:
      return (reader.readDouble(offset)) as P;
    case 8:
      return (reader.readDateTime(offset)) as P;
    case 9:
      return (reader.readDouble(offset)) as P;
    case 10:
      return (reader.readDateTime(offset)) as P;
    case 11:
      return (reader.readBool(offset)) as P;
    case 12:
      return (reader.readBool(offset)) as P;
    case 13:
      return (reader.readBool(offset)) as P;
    case 14:
      return (reader.readDouble(offset)) as P;
    case 15:
      return (reader.readDouble(offset)) as P;
    case 16:
      return (reader.readBool(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _fitnessEntryGetId(FitnessEntry object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _fitnessEntryGetLinks(FitnessEntry object) {
  return [];
}

void _fitnessEntryAttach(
  IsarCollection<dynamic> col,
  Id id,
  FitnessEntry object,
) {
  object.id = id;
}

extension FitnessEntryQueryWhereSort
    on QueryBuilder<FitnessEntry, FitnessEntry, QWhere> {
  QueryBuilder<FitnessEntry, FitnessEntry, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterWhere>
  anyInferenceTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'inferenceTimestamp'),
      );
    });
  }
}

extension FitnessEntryQueryWhere
    on QueryBuilder<FitnessEntry, FitnessEntry, QWhereClause> {
  QueryBuilder<FitnessEntry, FitnessEntry, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterWhereClause> idNotEqualTo(
    Id id,
  ) {
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

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterWhereClause> idGreaterThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterWhereClause> idBetween(
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

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterWhereClause> dateEqualTo(
    String date,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'date', value: [date]),
      );
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterWhereClause> dateNotEqualTo(
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

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterWhereClause>
  inferenceTimestampEqualTo(DateTime inferenceTimestamp) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'inferenceTimestamp',
          value: [inferenceTimestamp],
        ),
      );
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterWhereClause>
  inferenceTimestampNotEqualTo(DateTime inferenceTimestamp) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'inferenceTimestamp',
                lower: [],
                upper: [inferenceTimestamp],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'inferenceTimestamp',
                lower: [inferenceTimestamp],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'inferenceTimestamp',
                lower: [inferenceTimestamp],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'inferenceTimestamp',
                lower: [],
                upper: [inferenceTimestamp],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterWhereClause>
  inferenceTimestampGreaterThan(
    DateTime inferenceTimestamp, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'inferenceTimestamp',
          lower: [inferenceTimestamp],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterWhereClause>
  inferenceTimestampLessThan(
    DateTime inferenceTimestamp, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'inferenceTimestamp',
          lower: [],
          upper: [inferenceTimestamp],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterWhereClause>
  inferenceTimestampBetween(
    DateTime lowerInferenceTimestamp,
    DateTime upperInferenceTimestamp, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'inferenceTimestamp',
          lower: [lowerInferenceTimestamp],
          includeLower: includeLower,
          upper: [upperInferenceTimestamp],
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension FitnessEntryQueryFilter
    on QueryBuilder<FitnessEntry, FitnessEntry, QFilterCondition> {
  QueryBuilder<FitnessEntry, FitnessEntry, QAfterFilterCondition>
  activityIndexEqualTo(double value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'activityIndex',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterFilterCondition>
  activityIndexGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'activityIndex',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterFilterCondition>
  activityIndexLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'activityIndex',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterFilterCondition>
  activityIndexBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'activityIndex',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterFilterCondition> ageEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'age',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterFilterCondition>
  ageGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'age',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterFilterCondition> ageLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'age',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterFilterCondition> ageBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'age',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterFilterCondition> bmiEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'bmi',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterFilterCondition>
  bmiGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'bmi',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterFilterCondition> bmiLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'bmi',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterFilterCondition> bmiBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'bmi',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterFilterCondition>
  confidenceOkEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'confidenceOk', value: value),
      );
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterFilterCondition>
  dataFreshnessFlaggedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'dataFreshnessFlagged',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterFilterCondition> dateEqualTo(
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

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterFilterCondition>
  dateGreaterThan(
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

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterFilterCondition> dateLessThan(
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

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterFilterCondition> dateBetween(
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

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterFilterCondition>
  dateStartsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterFilterCondition> dateEndsWith(
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

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterFilterCondition> dateContains(
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

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterFilterCondition> dateMatches(
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

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterFilterCondition>
  dateIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'date', value: ''),
      );
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterFilterCondition>
  dateIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'date', value: ''),
      );
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterFilterCondition>
  fitProbabilityEqualTo(double value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'fitProbability',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterFilterCondition>
  fitProbabilityGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'fitProbability',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterFilterCondition>
  fitProbabilityLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'fitProbability',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterFilterCondition>
  fitProbabilityBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'fitProbability',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterFilterCondition>
  fitnessScoreEqualTo(double value, {double epsilon = Query.epsilon}) {
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

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterFilterCondition>
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

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterFilterCondition>
  fitnessScoreLessThan(
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

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterFilterCondition>
  fitnessScoreBetween(
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

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterFilterCondition>
  healthDataTimestampEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'healthDataTimestamp', value: value),
      );
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterFilterCondition>
  healthDataTimestampGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'healthDataTimestamp',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterFilterCondition>
  healthDataTimestampLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'healthDataTimestamp',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterFilterCondition>
  healthDataTimestampBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'healthDataTimestamp',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterFilterCondition>
  heartRateEqualTo(double value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'heartRate',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterFilterCondition>
  heartRateGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'heartRate',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterFilterCondition>
  heartRateLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'heartRate',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterFilterCondition>
  heartRateBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'heartRate',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterFilterCondition> idEqualTo(
    Id value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterFilterCondition> idGreaterThan(
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

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterFilterCondition> idBetween(
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

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterFilterCondition>
  inferenceTimestampEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'inferenceTimestamp', value: value),
      );
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterFilterCondition>
  inferenceTimestampGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'inferenceTimestamp',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterFilterCondition>
  inferenceTimestampLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'inferenceTimestamp',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterFilterCondition>
  inferenceTimestampBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'inferenceTimestamp',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterFilterCondition> isFitEqualTo(
    bool value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isFit', value: value),
      );
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterFilterCondition> isMaleEqualTo(
    bool value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isMale', value: value),
      );
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterFilterCondition>
  isOnboardingSnapshotEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'isOnboardingSnapshot',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterFilterCondition>
  nutritionQualityEqualTo(double value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'nutritionQuality',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterFilterCondition>
  nutritionQualityGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'nutritionQuality',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterFilterCondition>
  nutritionQualityLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'nutritionQuality',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterFilterCondition>
  nutritionQualityBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'nutritionQuality',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterFilterCondition>
  sleepHoursEqualTo(double value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'sleepHours',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterFilterCondition>
  sleepHoursGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'sleepHours',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterFilterCondition>
  sleepHoursLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'sleepHours',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterFilterCondition>
  sleepHoursBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'sleepHours',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterFilterCondition> smokesEqualTo(
    bool value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'smokes', value: value),
      );
    });
  }
}

extension FitnessEntryQueryObject
    on QueryBuilder<FitnessEntry, FitnessEntry, QFilterCondition> {}

extension FitnessEntryQueryLinks
    on QueryBuilder<FitnessEntry, FitnessEntry, QFilterCondition> {}

extension FitnessEntryQuerySortBy
    on QueryBuilder<FitnessEntry, FitnessEntry, QSortBy> {
  QueryBuilder<FitnessEntry, FitnessEntry, QAfterSortBy> sortByActivityIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'activityIndex', Sort.asc);
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterSortBy>
  sortByActivityIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'activityIndex', Sort.desc);
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterSortBy> sortByAge() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'age', Sort.asc);
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterSortBy> sortByAgeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'age', Sort.desc);
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterSortBy> sortByBmi() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bmi', Sort.asc);
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterSortBy> sortByBmiDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bmi', Sort.desc);
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterSortBy> sortByConfidenceOk() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'confidenceOk', Sort.asc);
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterSortBy>
  sortByConfidenceOkDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'confidenceOk', Sort.desc);
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterSortBy>
  sortByDataFreshnessFlagged() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dataFreshnessFlagged', Sort.asc);
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterSortBy>
  sortByDataFreshnessFlaggedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dataFreshnessFlagged', Sort.desc);
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterSortBy> sortByDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'date', Sort.asc);
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterSortBy> sortByDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'date', Sort.desc);
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterSortBy>
  sortByFitProbability() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fitProbability', Sort.asc);
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterSortBy>
  sortByFitProbabilityDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fitProbability', Sort.desc);
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterSortBy> sortByFitnessScore() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fitnessScore', Sort.asc);
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterSortBy>
  sortByFitnessScoreDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fitnessScore', Sort.desc);
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterSortBy>
  sortByHealthDataTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'healthDataTimestamp', Sort.asc);
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterSortBy>
  sortByHealthDataTimestampDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'healthDataTimestamp', Sort.desc);
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterSortBy> sortByHeartRate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'heartRate', Sort.asc);
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterSortBy> sortByHeartRateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'heartRate', Sort.desc);
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterSortBy>
  sortByInferenceTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'inferenceTimestamp', Sort.asc);
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterSortBy>
  sortByInferenceTimestampDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'inferenceTimestamp', Sort.desc);
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterSortBy> sortByIsFit() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isFit', Sort.asc);
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterSortBy> sortByIsFitDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isFit', Sort.desc);
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterSortBy> sortByIsMale() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isMale', Sort.asc);
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterSortBy> sortByIsMaleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isMale', Sort.desc);
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterSortBy>
  sortByIsOnboardingSnapshot() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isOnboardingSnapshot', Sort.asc);
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterSortBy>
  sortByIsOnboardingSnapshotDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isOnboardingSnapshot', Sort.desc);
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterSortBy>
  sortByNutritionQuality() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nutritionQuality', Sort.asc);
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterSortBy>
  sortByNutritionQualityDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nutritionQuality', Sort.desc);
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterSortBy> sortBySleepHours() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sleepHours', Sort.asc);
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterSortBy>
  sortBySleepHoursDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sleepHours', Sort.desc);
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterSortBy> sortBySmokes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'smokes', Sort.asc);
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterSortBy> sortBySmokesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'smokes', Sort.desc);
    });
  }
}

extension FitnessEntryQuerySortThenBy
    on QueryBuilder<FitnessEntry, FitnessEntry, QSortThenBy> {
  QueryBuilder<FitnessEntry, FitnessEntry, QAfterSortBy> thenByActivityIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'activityIndex', Sort.asc);
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterSortBy>
  thenByActivityIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'activityIndex', Sort.desc);
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterSortBy> thenByAge() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'age', Sort.asc);
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterSortBy> thenByAgeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'age', Sort.desc);
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterSortBy> thenByBmi() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bmi', Sort.asc);
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterSortBy> thenByBmiDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bmi', Sort.desc);
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterSortBy> thenByConfidenceOk() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'confidenceOk', Sort.asc);
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterSortBy>
  thenByConfidenceOkDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'confidenceOk', Sort.desc);
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterSortBy>
  thenByDataFreshnessFlagged() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dataFreshnessFlagged', Sort.asc);
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterSortBy>
  thenByDataFreshnessFlaggedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dataFreshnessFlagged', Sort.desc);
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterSortBy> thenByDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'date', Sort.asc);
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterSortBy> thenByDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'date', Sort.desc);
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterSortBy>
  thenByFitProbability() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fitProbability', Sort.asc);
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterSortBy>
  thenByFitProbabilityDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fitProbability', Sort.desc);
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterSortBy> thenByFitnessScore() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fitnessScore', Sort.asc);
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterSortBy>
  thenByFitnessScoreDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fitnessScore', Sort.desc);
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterSortBy>
  thenByHealthDataTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'healthDataTimestamp', Sort.asc);
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterSortBy>
  thenByHealthDataTimestampDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'healthDataTimestamp', Sort.desc);
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterSortBy> thenByHeartRate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'heartRate', Sort.asc);
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterSortBy> thenByHeartRateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'heartRate', Sort.desc);
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterSortBy>
  thenByInferenceTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'inferenceTimestamp', Sort.asc);
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterSortBy>
  thenByInferenceTimestampDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'inferenceTimestamp', Sort.desc);
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterSortBy> thenByIsFit() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isFit', Sort.asc);
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterSortBy> thenByIsFitDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isFit', Sort.desc);
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterSortBy> thenByIsMale() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isMale', Sort.asc);
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterSortBy> thenByIsMaleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isMale', Sort.desc);
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterSortBy>
  thenByIsOnboardingSnapshot() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isOnboardingSnapshot', Sort.asc);
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterSortBy>
  thenByIsOnboardingSnapshotDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isOnboardingSnapshot', Sort.desc);
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterSortBy>
  thenByNutritionQuality() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nutritionQuality', Sort.asc);
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterSortBy>
  thenByNutritionQualityDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nutritionQuality', Sort.desc);
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterSortBy> thenBySleepHours() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sleepHours', Sort.asc);
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterSortBy>
  thenBySleepHoursDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sleepHours', Sort.desc);
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterSortBy> thenBySmokes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'smokes', Sort.asc);
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QAfterSortBy> thenBySmokesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'smokes', Sort.desc);
    });
  }
}

extension FitnessEntryQueryWhereDistinct
    on QueryBuilder<FitnessEntry, FitnessEntry, QDistinct> {
  QueryBuilder<FitnessEntry, FitnessEntry, QDistinct>
  distinctByActivityIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'activityIndex');
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QDistinct> distinctByAge() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'age');
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QDistinct> distinctByBmi() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'bmi');
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QDistinct> distinctByConfidenceOk() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'confidenceOk');
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QDistinct>
  distinctByDataFreshnessFlagged() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'dataFreshnessFlagged');
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QDistinct> distinctByDate({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'date', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QDistinct>
  distinctByFitProbability() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'fitProbability');
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QDistinct> distinctByFitnessScore() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'fitnessScore');
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QDistinct>
  distinctByHealthDataTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'healthDataTimestamp');
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QDistinct> distinctByHeartRate() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'heartRate');
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QDistinct>
  distinctByInferenceTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'inferenceTimestamp');
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QDistinct> distinctByIsFit() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isFit');
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QDistinct> distinctByIsMale() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isMale');
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QDistinct>
  distinctByIsOnboardingSnapshot() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isOnboardingSnapshot');
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QDistinct>
  distinctByNutritionQuality() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'nutritionQuality');
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QDistinct> distinctBySleepHours() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sleepHours');
    });
  }

  QueryBuilder<FitnessEntry, FitnessEntry, QDistinct> distinctBySmokes() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'smokes');
    });
  }
}

extension FitnessEntryQueryProperty
    on QueryBuilder<FitnessEntry, FitnessEntry, QQueryProperty> {
  QueryBuilder<FitnessEntry, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<FitnessEntry, double, QQueryOperations> activityIndexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'activityIndex');
    });
  }

  QueryBuilder<FitnessEntry, double, QQueryOperations> ageProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'age');
    });
  }

  QueryBuilder<FitnessEntry, double, QQueryOperations> bmiProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'bmi');
    });
  }

  QueryBuilder<FitnessEntry, bool, QQueryOperations> confidenceOkProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'confidenceOk');
    });
  }

  QueryBuilder<FitnessEntry, bool, QQueryOperations>
  dataFreshnessFlaggedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'dataFreshnessFlagged');
    });
  }

  QueryBuilder<FitnessEntry, String, QQueryOperations> dateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'date');
    });
  }

  QueryBuilder<FitnessEntry, double, QQueryOperations>
  fitProbabilityProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'fitProbability');
    });
  }

  QueryBuilder<FitnessEntry, double, QQueryOperations> fitnessScoreProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'fitnessScore');
    });
  }

  QueryBuilder<FitnessEntry, DateTime, QQueryOperations>
  healthDataTimestampProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'healthDataTimestamp');
    });
  }

  QueryBuilder<FitnessEntry, double, QQueryOperations> heartRateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'heartRate');
    });
  }

  QueryBuilder<FitnessEntry, DateTime, QQueryOperations>
  inferenceTimestampProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'inferenceTimestamp');
    });
  }

  QueryBuilder<FitnessEntry, bool, QQueryOperations> isFitProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isFit');
    });
  }

  QueryBuilder<FitnessEntry, bool, QQueryOperations> isMaleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isMale');
    });
  }

  QueryBuilder<FitnessEntry, bool, QQueryOperations>
  isOnboardingSnapshotProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isOnboardingSnapshot');
    });
  }

  QueryBuilder<FitnessEntry, double, QQueryOperations>
  nutritionQualityProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'nutritionQuality');
    });
  }

  QueryBuilder<FitnessEntry, double, QQueryOperations> sleepHoursProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sleepHours');
    });
  }

  QueryBuilder<FitnessEntry, bool, QQueryOperations> smokesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'smokes');
    });
  }
}
