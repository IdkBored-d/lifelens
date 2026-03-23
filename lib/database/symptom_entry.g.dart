// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'symptom_entry.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetSymptomEntryCollection on Isar {
  IsarCollection<SymptomEntry> get symptomEntrys => this.collection();
}

const SymptomEntrySchema = CollectionSchema(
  name: r'SymptomEntry',
  id: 5241081634958873608,
  properties: {
    r'date': PropertySchema(
      id: 0,
      name: r'date',
      type: IsarType.string,
    ),
    r'diagnosesJson': PropertySchema(
      id: 1,
      name: r'diagnosesJson',
      type: IsarType.string,
    ),
    r'disEmbedScore': PropertySchema(
      id: 2,
      name: r'disEmbedScore',
      type: IsarType.double,
    ),
    r'predictedAilment': PropertySchema(
      id: 3,
      name: r'predictedAilment',
      type: IsarType.string,
    ),
    r'ragUsed': PropertySchema(
      id: 4,
      name: r'ragUsed',
      type: IsarType.bool,
    ),
    r'rawSymptoms': PropertySchema(
      id: 5,
      name: r'rawSymptoms',
      type: IsarType.string,
    ),
    r'resolvedBy': PropertySchema(
      id: 6,
      name: r'resolvedBy',
      type: IsarType.string,
    ),
    r'status': PropertySchema(
      id: 7,
      name: r'status',
      type: IsarType.string,
    ),
    r'statusUpdatedDate': PropertySchema(
      id: 8,
      name: r'statusUpdatedDate',
      type: IsarType.string,
    ),
    r'symptomList': PropertySchema(
      id: 9,
      name: r'symptomList',
      type: IsarType.stringList,
    ),
    r'timestamp': PropertySchema(
      id: 10,
      name: r'timestamp',
      type: IsarType.dateTime,
    ),
    r'updatedAt': PropertySchema(
      id: 11,
      name: r'updatedAt',
      type: IsarType.dateTime,
    ),
    r'wasOffline': PropertySchema(
      id: 12,
      name: r'wasOffline',
      type: IsarType.bool,
    )
  },
  estimateSize: _symptomEntryEstimateSize,
  serialize: _symptomEntrySerialize,
  deserialize: _symptomEntryDeserialize,
  deserializeProp: _symptomEntryDeserializeProp,
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
        )
      ],
    ),
    r'predictedAilment': IndexSchema(
      id: 5556288958411965805,
      name: r'predictedAilment',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'predictedAilment',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'status': IndexSchema(
      id: -107785170620420283,
      name: r'status',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'status',
          type: IndexType.hash,
          caseSensitive: true,
        )
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
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _symptomEntryGetId,
  getLinks: _symptomEntryGetLinks,
  attach: _symptomEntryAttach,
  version: '3.1.0+1',
);

int _symptomEntryEstimateSize(
  SymptomEntry object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.date.length * 3;
  bytesCount += 3 + object.diagnosesJson.length * 3;
  bytesCount += 3 + object.predictedAilment.length * 3;
  bytesCount += 3 + object.rawSymptoms.length * 3;
  bytesCount += 3 + object.resolvedBy.length * 3;
  bytesCount += 3 + object.status.length * 3;
  {
    final value = object.statusUpdatedDate;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.symptomList.length * 3;
  {
    for (var i = 0; i < object.symptomList.length; i++) {
      final value = object.symptomList[i];
      bytesCount += value.length * 3;
    }
  }
  return bytesCount;
}

void _symptomEntrySerialize(
  SymptomEntry object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.date);
  writer.writeString(offsets[1], object.diagnosesJson);
  writer.writeDouble(offsets[2], object.disEmbedScore);
  writer.writeString(offsets[3], object.predictedAilment);
  writer.writeBool(offsets[4], object.ragUsed);
  writer.writeString(offsets[5], object.rawSymptoms);
  writer.writeString(offsets[6], object.resolvedBy);
  writer.writeString(offsets[7], object.status);
  writer.writeString(offsets[8], object.statusUpdatedDate);
  writer.writeStringList(offsets[9], object.symptomList);
  writer.writeDateTime(offsets[10], object.timestamp);
  writer.writeDateTime(offsets[11], object.updatedAt);
  writer.writeBool(offsets[12], object.wasOffline);
}

SymptomEntry _symptomEntryDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = SymptomEntry();
  object.date = reader.readString(offsets[0]);
  object.diagnosesJson = reader.readString(offsets[1]);
  object.disEmbedScore = reader.readDoubleOrNull(offsets[2]);
  object.id = id;
  object.predictedAilment = reader.readString(offsets[3]);
  object.ragUsed = reader.readBool(offsets[4]);
  object.rawSymptoms = reader.readString(offsets[5]);
  object.resolvedBy = reader.readString(offsets[6]);
  object.status = reader.readString(offsets[7]);
  object.statusUpdatedDate = reader.readStringOrNull(offsets[8]);
  object.symptomList = reader.readStringList(offsets[9]) ?? [];
  object.timestamp = reader.readDateTime(offsets[10]);
  object.updatedAt = reader.readDateTime(offsets[11]);
  object.wasOffline = reader.readBool(offsets[12]);
  return object;
}

P _symptomEntryDeserializeProp<P>(
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
      return (reader.readDoubleOrNull(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readBool(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readString(offset)) as P;
    case 7:
      return (reader.readString(offset)) as P;
    case 8:
      return (reader.readStringOrNull(offset)) as P;
    case 9:
      return (reader.readStringList(offset) ?? []) as P;
    case 10:
      return (reader.readDateTime(offset)) as P;
    case 11:
      return (reader.readDateTime(offset)) as P;
    case 12:
      return (reader.readBool(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _symptomEntryGetId(SymptomEntry object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _symptomEntryGetLinks(SymptomEntry object) {
  return [];
}

void _symptomEntryAttach(
    IsarCollection<dynamic> col, Id id, SymptomEntry object) {
  object.id = id;
}

extension SymptomEntryQueryWhereSort
    on QueryBuilder<SymptomEntry, SymptomEntry, QWhere> {
  QueryBuilder<SymptomEntry, SymptomEntry, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterWhere> anyTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'timestamp'),
      );
    });
  }
}

extension SymptomEntryQueryWhere
    on QueryBuilder<SymptomEntry, SymptomEntry, QWhereClause> {
  QueryBuilder<SymptomEntry, SymptomEntry, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterWhereClause> idNotEqualTo(
      Id id) {
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

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterWhereClause> idGreaterThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterWhereClause> dateEqualTo(
      String date) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'date',
        value: [date],
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterWhereClause> dateNotEqualTo(
      String date) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'date',
              lower: [],
              upper: [date],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'date',
              lower: [date],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'date',
              lower: [date],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'date',
              lower: [],
              upper: [date],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterWhereClause>
      predictedAilmentEqualTo(String predictedAilment) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'predictedAilment',
        value: [predictedAilment],
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterWhereClause>
      predictedAilmentNotEqualTo(String predictedAilment) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'predictedAilment',
              lower: [],
              upper: [predictedAilment],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'predictedAilment',
              lower: [predictedAilment],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'predictedAilment',
              lower: [predictedAilment],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'predictedAilment',
              lower: [],
              upper: [predictedAilment],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterWhereClause> statusEqualTo(
      String status) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'status',
        value: [status],
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterWhereClause> statusNotEqualTo(
      String status) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'status',
              lower: [],
              upper: [status],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'status',
              lower: [status],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'status',
              lower: [status],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'status',
              lower: [],
              upper: [status],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterWhereClause> timestampEqualTo(
      DateTime timestamp) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'timestamp',
        value: [timestamp],
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterWhereClause>
      timestampNotEqualTo(DateTime timestamp) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'timestamp',
              lower: [],
              upper: [timestamp],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'timestamp',
              lower: [timestamp],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'timestamp',
              lower: [timestamp],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'timestamp',
              lower: [],
              upper: [timestamp],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterWhereClause>
      timestampGreaterThan(
    DateTime timestamp, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'timestamp',
        lower: [timestamp],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterWhereClause> timestampLessThan(
    DateTime timestamp, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'timestamp',
        lower: [],
        upper: [timestamp],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterWhereClause> timestampBetween(
    DateTime lowerTimestamp,
    DateTime upperTimestamp, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'timestamp',
        lower: [lowerTimestamp],
        includeLower: includeLower,
        upper: [upperTimestamp],
        includeUpper: includeUpper,
      ));
    });
  }
}

extension SymptomEntryQueryFilter
    on QueryBuilder<SymptomEntry, SymptomEntry, QFilterCondition> {
  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition> dateEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'date',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      dateGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'date',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition> dateLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'date',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition> dateBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'date',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      dateStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'date',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition> dateEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'date',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition> dateContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'date',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition> dateMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'date',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      dateIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'date',
        value: '',
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      dateIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'date',
        value: '',
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      diagnosesJsonEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'diagnosesJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      diagnosesJsonGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'diagnosesJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      diagnosesJsonLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'diagnosesJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      diagnosesJsonBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'diagnosesJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      diagnosesJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'diagnosesJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      diagnosesJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'diagnosesJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      diagnosesJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'diagnosesJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      diagnosesJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'diagnosesJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      diagnosesJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'diagnosesJson',
        value: '',
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      diagnosesJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'diagnosesJson',
        value: '',
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      disEmbedScoreIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'disEmbedScore',
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      disEmbedScoreIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'disEmbedScore',
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      disEmbedScoreEqualTo(
    double? value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'disEmbedScore',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      disEmbedScoreGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'disEmbedScore',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      disEmbedScoreLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'disEmbedScore',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      disEmbedScoreBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'disEmbedScore',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      predictedAilmentEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'predictedAilment',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      predictedAilmentGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'predictedAilment',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      predictedAilmentLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'predictedAilment',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      predictedAilmentBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'predictedAilment',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      predictedAilmentStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'predictedAilment',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      predictedAilmentEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'predictedAilment',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      predictedAilmentContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'predictedAilment',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      predictedAilmentMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'predictedAilment',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      predictedAilmentIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'predictedAilment',
        value: '',
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      predictedAilmentIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'predictedAilment',
        value: '',
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      ragUsedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'ragUsed',
        value: value,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      rawSymptomsEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'rawSymptoms',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      rawSymptomsGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'rawSymptoms',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      rawSymptomsLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'rawSymptoms',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      rawSymptomsBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'rawSymptoms',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      rawSymptomsStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'rawSymptoms',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      rawSymptomsEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'rawSymptoms',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      rawSymptomsContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'rawSymptoms',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      rawSymptomsMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'rawSymptoms',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      rawSymptomsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'rawSymptoms',
        value: '',
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      rawSymptomsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'rawSymptoms',
        value: '',
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      resolvedByEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'resolvedBy',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      resolvedByGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'resolvedBy',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      resolvedByLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'resolvedBy',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      resolvedByBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'resolvedBy',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      resolvedByStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'resolvedBy',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      resolvedByEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'resolvedBy',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      resolvedByContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'resolvedBy',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      resolvedByMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'resolvedBy',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      resolvedByIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'resolvedBy',
        value: '',
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      resolvedByIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'resolvedBy',
        value: '',
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition> statusEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      statusGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      statusLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition> statusBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'status',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      statusStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      statusEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      statusContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition> statusMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'status',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      statusIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'status',
        value: '',
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      statusIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'status',
        value: '',
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      statusUpdatedDateIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'statusUpdatedDate',
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      statusUpdatedDateIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'statusUpdatedDate',
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      statusUpdatedDateEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'statusUpdatedDate',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      statusUpdatedDateGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'statusUpdatedDate',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      statusUpdatedDateLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'statusUpdatedDate',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      statusUpdatedDateBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'statusUpdatedDate',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      statusUpdatedDateStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'statusUpdatedDate',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      statusUpdatedDateEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'statusUpdatedDate',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      statusUpdatedDateContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'statusUpdatedDate',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      statusUpdatedDateMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'statusUpdatedDate',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      statusUpdatedDateIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'statusUpdatedDate',
        value: '',
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      statusUpdatedDateIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'statusUpdatedDate',
        value: '',
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      symptomListElementEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'symptomList',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      symptomListElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'symptomList',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      symptomListElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'symptomList',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      symptomListElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'symptomList',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      symptomListElementStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'symptomList',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      symptomListElementEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'symptomList',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      symptomListElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'symptomList',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      symptomListElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'symptomList',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      symptomListElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'symptomList',
        value: '',
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      symptomListElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'symptomList',
        value: '',
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      symptomListLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'symptomList',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      symptomListIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'symptomList',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      symptomListIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'symptomList',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      symptomListLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'symptomList',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      symptomListLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'symptomList',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      symptomListLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'symptomList',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      timestampEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'timestamp',
        value: value,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      timestampGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'timestamp',
        value: value,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      timestampLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'timestamp',
        value: value,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      timestampBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'timestamp',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      updatedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      updatedAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      updatedAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      updatedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'updatedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterFilterCondition>
      wasOfflineEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'wasOffline',
        value: value,
      ));
    });
  }
}

extension SymptomEntryQueryObject
    on QueryBuilder<SymptomEntry, SymptomEntry, QFilterCondition> {}

extension SymptomEntryQueryLinks
    on QueryBuilder<SymptomEntry, SymptomEntry, QFilterCondition> {}

extension SymptomEntryQuerySortBy
    on QueryBuilder<SymptomEntry, SymptomEntry, QSortBy> {
  QueryBuilder<SymptomEntry, SymptomEntry, QAfterSortBy> sortByDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'date', Sort.asc);
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterSortBy> sortByDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'date', Sort.desc);
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterSortBy> sortByDiagnosesJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'diagnosesJson', Sort.asc);
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterSortBy>
      sortByDiagnosesJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'diagnosesJson', Sort.desc);
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterSortBy> sortByDisEmbedScore() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'disEmbedScore', Sort.asc);
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterSortBy>
      sortByDisEmbedScoreDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'disEmbedScore', Sort.desc);
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterSortBy>
      sortByPredictedAilment() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'predictedAilment', Sort.asc);
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterSortBy>
      sortByPredictedAilmentDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'predictedAilment', Sort.desc);
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterSortBy> sortByRagUsed() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ragUsed', Sort.asc);
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterSortBy> sortByRagUsedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ragUsed', Sort.desc);
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterSortBy> sortByRawSymptoms() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rawSymptoms', Sort.asc);
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterSortBy>
      sortByRawSymptomsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rawSymptoms', Sort.desc);
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterSortBy> sortByResolvedBy() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolvedBy', Sort.asc);
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterSortBy>
      sortByResolvedByDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolvedBy', Sort.desc);
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterSortBy> sortByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterSortBy> sortByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterSortBy>
      sortByStatusUpdatedDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'statusUpdatedDate', Sort.asc);
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterSortBy>
      sortByStatusUpdatedDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'statusUpdatedDate', Sort.desc);
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterSortBy> sortByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.asc);
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterSortBy> sortByTimestampDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.desc);
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterSortBy> sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterSortBy> sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterSortBy> sortByWasOffline() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'wasOffline', Sort.asc);
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterSortBy>
      sortByWasOfflineDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'wasOffline', Sort.desc);
    });
  }
}

extension SymptomEntryQuerySortThenBy
    on QueryBuilder<SymptomEntry, SymptomEntry, QSortThenBy> {
  QueryBuilder<SymptomEntry, SymptomEntry, QAfterSortBy> thenByDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'date', Sort.asc);
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterSortBy> thenByDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'date', Sort.desc);
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterSortBy> thenByDiagnosesJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'diagnosesJson', Sort.asc);
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterSortBy>
      thenByDiagnosesJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'diagnosesJson', Sort.desc);
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterSortBy> thenByDisEmbedScore() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'disEmbedScore', Sort.asc);
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterSortBy>
      thenByDisEmbedScoreDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'disEmbedScore', Sort.desc);
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterSortBy>
      thenByPredictedAilment() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'predictedAilment', Sort.asc);
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterSortBy>
      thenByPredictedAilmentDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'predictedAilment', Sort.desc);
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterSortBy> thenByRagUsed() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ragUsed', Sort.asc);
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterSortBy> thenByRagUsedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ragUsed', Sort.desc);
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterSortBy> thenByRawSymptoms() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rawSymptoms', Sort.asc);
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterSortBy>
      thenByRawSymptomsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rawSymptoms', Sort.desc);
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterSortBy> thenByResolvedBy() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolvedBy', Sort.asc);
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterSortBy>
      thenByResolvedByDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolvedBy', Sort.desc);
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterSortBy> thenByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterSortBy> thenByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterSortBy>
      thenByStatusUpdatedDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'statusUpdatedDate', Sort.asc);
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterSortBy>
      thenByStatusUpdatedDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'statusUpdatedDate', Sort.desc);
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterSortBy> thenByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.asc);
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterSortBy> thenByTimestampDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.desc);
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterSortBy> thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterSortBy> thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterSortBy> thenByWasOffline() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'wasOffline', Sort.asc);
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QAfterSortBy>
      thenByWasOfflineDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'wasOffline', Sort.desc);
    });
  }
}

extension SymptomEntryQueryWhereDistinct
    on QueryBuilder<SymptomEntry, SymptomEntry, QDistinct> {
  QueryBuilder<SymptomEntry, SymptomEntry, QDistinct> distinctByDate(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'date', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QDistinct> distinctByDiagnosesJson(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'diagnosesJson',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QDistinct>
      distinctByDisEmbedScore() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'disEmbedScore');
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QDistinct>
      distinctByPredictedAilment({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'predictedAilment',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QDistinct> distinctByRagUsed() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'ragUsed');
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QDistinct> distinctByRawSymptoms(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'rawSymptoms', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QDistinct> distinctByResolvedBy(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'resolvedBy', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QDistinct> distinctByStatus(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'status', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QDistinct>
      distinctByStatusUpdatedDate({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'statusUpdatedDate',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QDistinct> distinctBySymptomList() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'symptomList');
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QDistinct> distinctByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'timestamp');
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QDistinct> distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }

  QueryBuilder<SymptomEntry, SymptomEntry, QDistinct> distinctByWasOffline() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'wasOffline');
    });
  }
}

extension SymptomEntryQueryProperty
    on QueryBuilder<SymptomEntry, SymptomEntry, QQueryProperty> {
  QueryBuilder<SymptomEntry, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<SymptomEntry, String, QQueryOperations> dateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'date');
    });
  }

  QueryBuilder<SymptomEntry, String, QQueryOperations> diagnosesJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'diagnosesJson');
    });
  }

  QueryBuilder<SymptomEntry, double?, QQueryOperations>
      disEmbedScoreProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'disEmbedScore');
    });
  }

  QueryBuilder<SymptomEntry, String, QQueryOperations>
      predictedAilmentProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'predictedAilment');
    });
  }

  QueryBuilder<SymptomEntry, bool, QQueryOperations> ragUsedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'ragUsed');
    });
  }

  QueryBuilder<SymptomEntry, String, QQueryOperations> rawSymptomsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'rawSymptoms');
    });
  }

  QueryBuilder<SymptomEntry, String, QQueryOperations> resolvedByProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'resolvedBy');
    });
  }

  QueryBuilder<SymptomEntry, String, QQueryOperations> statusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'status');
    });
  }

  QueryBuilder<SymptomEntry, String?, QQueryOperations>
      statusUpdatedDateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'statusUpdatedDate');
    });
  }

  QueryBuilder<SymptomEntry, List<String>, QQueryOperations>
      symptomListProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'symptomList');
    });
  }

  QueryBuilder<SymptomEntry, DateTime, QQueryOperations> timestampProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'timestamp');
    });
  }

  QueryBuilder<SymptomEntry, DateTime, QQueryOperations> updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }

  QueryBuilder<SymptomEntry, bool, QQueryOperations> wasOfflineProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'wasOffline');
    });
  }
}
