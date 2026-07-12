// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'epub_book_progress.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetEpubBookProgressCollection on Isar {
  IsarCollection<EpubBookProgress> get epubBookProgress => this.collection();
}

const EpubBookProgressSchema = CollectionSchema(
  name: r'EpubBookProgress',
  id: -7135979847634917983,
  properties: {
    r'archivePath': PropertySchema(
      id: 0,
      name: r'archivePath',
      type: IsarType.string,
    ),
    r'author': PropertySchema(id: 1, name: r'author', type: IsarType.string),
    r'chapterIndex': PropertySchema(
      id: 2,
      name: r'chapterIndex',
      type: IsarType.long,
    ),
    r'characterCount': PropertySchema(
      id: 3,
      name: r'characterCount',
      type: IsarType.long,
    ),
    r'lastModified': PropertySchema(
      id: 4,
      name: r'lastModified',
      type: IsarType.long,
    ),
    r'mangaId': PropertySchema(id: 5, name: r'mangaId', type: IsarType.long),
    r'progress': PropertySchema(
      id: 6,
      name: r'progress',
      type: IsarType.double,
    ),
    r'title': PropertySchema(id: 7, name: r'title', type: IsarType.string),
  },

  estimateSize: _epubBookProgressEstimateSize,
  serialize: _epubBookProgressSerialize,
  deserialize: _epubBookProgressDeserialize,
  deserializeProp: _epubBookProgressDeserializeProp,
  idName: r'id',
  indexes: {
    r'mangaId_archivePath': IndexSchema(
      id: -2525302104089411744,
      name: r'mangaId_archivePath',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'mangaId',
          type: IndexType.value,
          caseSensitive: false,
        ),
        IndexPropertySchema(
          name: r'archivePath',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _epubBookProgressGetId,
  getLinks: _epubBookProgressGetLinks,
  attach: _epubBookProgressAttach,
  version: '3.3.2',
);

int _epubBookProgressEstimateSize(
  EpubBookProgress object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.archivePath.length * 3;
  {
    final value = object.author;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.title.length * 3;
  return bytesCount;
}

void _epubBookProgressSerialize(
  EpubBookProgress object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.archivePath);
  writer.writeString(offsets[1], object.author);
  writer.writeLong(offsets[2], object.chapterIndex);
  writer.writeLong(offsets[3], object.characterCount);
  writer.writeLong(offsets[4], object.lastModified);
  writer.writeLong(offsets[5], object.mangaId);
  writer.writeDouble(offsets[6], object.progress);
  writer.writeString(offsets[7], object.title);
}

EpubBookProgress _epubBookProgressDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = EpubBookProgress(
    archivePath: reader.readString(offsets[0]),
    author: reader.readStringOrNull(offsets[1]),
    chapterIndex: reader.readLongOrNull(offsets[2]) ?? 0,
    characterCount: reader.readLongOrNull(offsets[3]) ?? 0,
    id: id,
    lastModified: reader.readLongOrNull(offsets[4]),
    mangaId: reader.readLong(offsets[5]),
    progress: reader.readDoubleOrNull(offsets[6]) ?? 0,
    title: reader.readString(offsets[7]),
  );
  return object;
}

P _epubBookProgressDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readStringOrNull(offset)) as P;
    case 2:
      return (reader.readLongOrNull(offset) ?? 0) as P;
    case 3:
      return (reader.readLongOrNull(offset) ?? 0) as P;
    case 4:
      return (reader.readLongOrNull(offset)) as P;
    case 5:
      return (reader.readLong(offset)) as P;
    case 6:
      return (reader.readDoubleOrNull(offset) ?? 0) as P;
    case 7:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _epubBookProgressGetId(EpubBookProgress object) {
  return object.id ?? Isar.autoIncrement;
}

List<IsarLinkBase<dynamic>> _epubBookProgressGetLinks(EpubBookProgress object) {
  return [];
}

void _epubBookProgressAttach(
  IsarCollection<dynamic> col,
  Id id,
  EpubBookProgress object,
) {
  object.id = id;
}

extension EpubBookProgressByIndex on IsarCollection<EpubBookProgress> {
  Future<EpubBookProgress?> getByMangaIdArchivePath(
    int mangaId,
    String archivePath,
  ) {
    return getByIndex(r'mangaId_archivePath', [mangaId, archivePath]);
  }

  EpubBookProgress? getByMangaIdArchivePathSync(
    int mangaId,
    String archivePath,
  ) {
    return getByIndexSync(r'mangaId_archivePath', [mangaId, archivePath]);
  }

  Future<bool> deleteByMangaIdArchivePath(int mangaId, String archivePath) {
    return deleteByIndex(r'mangaId_archivePath', [mangaId, archivePath]);
  }

  bool deleteByMangaIdArchivePathSync(int mangaId, String archivePath) {
    return deleteByIndexSync(r'mangaId_archivePath', [mangaId, archivePath]);
  }

  Future<List<EpubBookProgress?>> getAllByMangaIdArchivePath(
    List<int> mangaIdValues,
    List<String> archivePathValues,
  ) {
    final len = mangaIdValues.length;
    assert(
      archivePathValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([mangaIdValues[i], archivePathValues[i]]);
    }

    return getAllByIndex(r'mangaId_archivePath', values);
  }

  List<EpubBookProgress?> getAllByMangaIdArchivePathSync(
    List<int> mangaIdValues,
    List<String> archivePathValues,
  ) {
    final len = mangaIdValues.length;
    assert(
      archivePathValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([mangaIdValues[i], archivePathValues[i]]);
    }

    return getAllByIndexSync(r'mangaId_archivePath', values);
  }

  Future<int> deleteAllByMangaIdArchivePath(
    List<int> mangaIdValues,
    List<String> archivePathValues,
  ) {
    final len = mangaIdValues.length;
    assert(
      archivePathValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([mangaIdValues[i], archivePathValues[i]]);
    }

    return deleteAllByIndex(r'mangaId_archivePath', values);
  }

  int deleteAllByMangaIdArchivePathSync(
    List<int> mangaIdValues,
    List<String> archivePathValues,
  ) {
    final len = mangaIdValues.length;
    assert(
      archivePathValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([mangaIdValues[i], archivePathValues[i]]);
    }

    return deleteAllByIndexSync(r'mangaId_archivePath', values);
  }

  Future<Id> putByMangaIdArchivePath(EpubBookProgress object) {
    return putByIndex(r'mangaId_archivePath', object);
  }

  Id putByMangaIdArchivePathSync(
    EpubBookProgress object, {
    bool saveLinks = true,
  }) {
    return putByIndexSync(r'mangaId_archivePath', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByMangaIdArchivePath(List<EpubBookProgress> objects) {
    return putAllByIndex(r'mangaId_archivePath', objects);
  }

  List<Id> putAllByMangaIdArchivePathSync(
    List<EpubBookProgress> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(
      r'mangaId_archivePath',
      objects,
      saveLinks: saveLinks,
    );
  }
}

extension EpubBookProgressQueryWhereSort
    on QueryBuilder<EpubBookProgress, EpubBookProgress, QWhere> {
  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension EpubBookProgressQueryWhere
    on QueryBuilder<EpubBookProgress, EpubBookProgress, QWhereClause> {
  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterWhereClause> idEqualTo(
    Id id,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterWhereClause>
  idNotEqualTo(Id id) {
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

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterWhereClause>
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterWhereClause>
  idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterWhereClause> idBetween(
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

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterWhereClause>
  mangaIdEqualToAnyArchivePath(int mangaId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'mangaId_archivePath',
          value: [mangaId],
        ),
      );
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterWhereClause>
  mangaIdNotEqualToAnyArchivePath(int mangaId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'mangaId_archivePath',
                lower: [],
                upper: [mangaId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'mangaId_archivePath',
                lower: [mangaId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'mangaId_archivePath',
                lower: [mangaId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'mangaId_archivePath',
                lower: [],
                upper: [mangaId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterWhereClause>
  mangaIdGreaterThanAnyArchivePath(int mangaId, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'mangaId_archivePath',
          lower: [mangaId],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterWhereClause>
  mangaIdLessThanAnyArchivePath(int mangaId, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'mangaId_archivePath',
          lower: [],
          upper: [mangaId],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterWhereClause>
  mangaIdBetweenAnyArchivePath(
    int lowerMangaId,
    int upperMangaId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'mangaId_archivePath',
          lower: [lowerMangaId],
          includeLower: includeLower,
          upper: [upperMangaId],
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterWhereClause>
  mangaIdArchivePathEqualTo(int mangaId, String archivePath) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'mangaId_archivePath',
          value: [mangaId, archivePath],
        ),
      );
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterWhereClause>
  mangaIdEqualToArchivePathNotEqualTo(int mangaId, String archivePath) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'mangaId_archivePath',
                lower: [mangaId],
                upper: [mangaId, archivePath],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'mangaId_archivePath',
                lower: [mangaId, archivePath],
                includeLower: false,
                upper: [mangaId],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'mangaId_archivePath',
                lower: [mangaId, archivePath],
                includeLower: false,
                upper: [mangaId],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'mangaId_archivePath',
                lower: [mangaId],
                upper: [mangaId, archivePath],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension EpubBookProgressQueryFilter
    on QueryBuilder<EpubBookProgress, EpubBookProgress, QFilterCondition> {
  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterFilterCondition>
  archivePathEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'archivePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterFilterCondition>
  archivePathGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'archivePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterFilterCondition>
  archivePathLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'archivePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterFilterCondition>
  archivePathBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'archivePath',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterFilterCondition>
  archivePathStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'archivePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterFilterCondition>
  archivePathEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'archivePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterFilterCondition>
  archivePathContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'archivePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterFilterCondition>
  archivePathMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'archivePath',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterFilterCondition>
  archivePathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'archivePath', value: ''),
      );
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterFilterCondition>
  archivePathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'archivePath', value: ''),
      );
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterFilterCondition>
  authorIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'author'),
      );
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterFilterCondition>
  authorIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'author'),
      );
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterFilterCondition>
  authorEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'author',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterFilterCondition>
  authorGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'author',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterFilterCondition>
  authorLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'author',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterFilterCondition>
  authorBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'author',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterFilterCondition>
  authorStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'author',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterFilterCondition>
  authorEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'author',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterFilterCondition>
  authorContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'author',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterFilterCondition>
  authorMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'author',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterFilterCondition>
  authorIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'author', value: ''),
      );
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterFilterCondition>
  authorIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'author', value: ''),
      );
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterFilterCondition>
  chapterIndexEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'chapterIndex', value: value),
      );
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterFilterCondition>
  chapterIndexGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'chapterIndex',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterFilterCondition>
  chapterIndexLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'chapterIndex',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterFilterCondition>
  chapterIndexBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'chapterIndex',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterFilterCondition>
  characterCountEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'characterCount', value: value),
      );
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterFilterCondition>
  characterCountGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'characterCount',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterFilterCondition>
  characterCountLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'characterCount',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterFilterCondition>
  characterCountBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'characterCount',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterFilterCondition>
  idIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'id'),
      );
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterFilterCondition>
  idIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'id'),
      );
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterFilterCondition>
  idEqualTo(Id? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterFilterCondition>
  idGreaterThan(Id? value, {bool include = false}) {
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

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterFilterCondition>
  idLessThan(Id? value, {bool include = false}) {
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

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterFilterCondition>
  idBetween(
    Id? lower,
    Id? upper, {
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

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterFilterCondition>
  lastModifiedIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'lastModified'),
      );
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterFilterCondition>
  lastModifiedIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'lastModified'),
      );
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterFilterCondition>
  lastModifiedEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'lastModified', value: value),
      );
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterFilterCondition>
  lastModifiedGreaterThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'lastModified',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterFilterCondition>
  lastModifiedLessThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'lastModified',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterFilterCondition>
  lastModifiedBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'lastModified',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterFilterCondition>
  mangaIdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'mangaId', value: value),
      );
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterFilterCondition>
  mangaIdGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'mangaId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterFilterCondition>
  mangaIdLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'mangaId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterFilterCondition>
  mangaIdBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'mangaId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterFilterCondition>
  progressEqualTo(double value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'progress',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterFilterCondition>
  progressGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'progress',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterFilterCondition>
  progressLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'progress',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterFilterCondition>
  progressBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'progress',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterFilterCondition>
  titleEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterFilterCondition>
  titleGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterFilterCondition>
  titleLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterFilterCondition>
  titleBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'title',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterFilterCondition>
  titleStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterFilterCondition>
  titleEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterFilterCondition>
  titleContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterFilterCondition>
  titleMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'title',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterFilterCondition>
  titleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'title', value: ''),
      );
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterFilterCondition>
  titleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'title', value: ''),
      );
    });
  }
}

extension EpubBookProgressQueryObject
    on QueryBuilder<EpubBookProgress, EpubBookProgress, QFilterCondition> {}

extension EpubBookProgressQueryLinks
    on QueryBuilder<EpubBookProgress, EpubBookProgress, QFilterCondition> {}

extension EpubBookProgressQuerySortBy
    on QueryBuilder<EpubBookProgress, EpubBookProgress, QSortBy> {
  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterSortBy>
  sortByArchivePath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'archivePath', Sort.asc);
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterSortBy>
  sortByArchivePathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'archivePath', Sort.desc);
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterSortBy>
  sortByAuthor() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'author', Sort.asc);
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterSortBy>
  sortByAuthorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'author', Sort.desc);
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterSortBy>
  sortByChapterIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chapterIndex', Sort.asc);
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterSortBy>
  sortByChapterIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chapterIndex', Sort.desc);
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterSortBy>
  sortByCharacterCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'characterCount', Sort.asc);
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterSortBy>
  sortByCharacterCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'characterCount', Sort.desc);
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterSortBy>
  sortByLastModified() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastModified', Sort.asc);
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterSortBy>
  sortByLastModifiedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastModified', Sort.desc);
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterSortBy>
  sortByMangaId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mangaId', Sort.asc);
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterSortBy>
  sortByMangaIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mangaId', Sort.desc);
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterSortBy>
  sortByProgress() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'progress', Sort.asc);
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterSortBy>
  sortByProgressDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'progress', Sort.desc);
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterSortBy> sortByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterSortBy>
  sortByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }
}

extension EpubBookProgressQuerySortThenBy
    on QueryBuilder<EpubBookProgress, EpubBookProgress, QSortThenBy> {
  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterSortBy>
  thenByArchivePath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'archivePath', Sort.asc);
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterSortBy>
  thenByArchivePathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'archivePath', Sort.desc);
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterSortBy>
  thenByAuthor() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'author', Sort.asc);
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterSortBy>
  thenByAuthorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'author', Sort.desc);
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterSortBy>
  thenByChapterIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chapterIndex', Sort.asc);
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterSortBy>
  thenByChapterIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chapterIndex', Sort.desc);
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterSortBy>
  thenByCharacterCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'characterCount', Sort.asc);
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterSortBy>
  thenByCharacterCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'characterCount', Sort.desc);
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterSortBy>
  thenByLastModified() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastModified', Sort.asc);
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterSortBy>
  thenByLastModifiedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastModified', Sort.desc);
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterSortBy>
  thenByMangaId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mangaId', Sort.asc);
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterSortBy>
  thenByMangaIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mangaId', Sort.desc);
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterSortBy>
  thenByProgress() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'progress', Sort.asc);
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterSortBy>
  thenByProgressDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'progress', Sort.desc);
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterSortBy> thenByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QAfterSortBy>
  thenByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }
}

extension EpubBookProgressQueryWhereDistinct
    on QueryBuilder<EpubBookProgress, EpubBookProgress, QDistinct> {
  QueryBuilder<EpubBookProgress, EpubBookProgress, QDistinct>
  distinctByArchivePath({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'archivePath', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QDistinct> distinctByAuthor({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'author', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QDistinct>
  distinctByChapterIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'chapterIndex');
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QDistinct>
  distinctByCharacterCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'characterCount');
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QDistinct>
  distinctByLastModified() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastModified');
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QDistinct>
  distinctByMangaId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'mangaId');
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QDistinct>
  distinctByProgress() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'progress');
    });
  }

  QueryBuilder<EpubBookProgress, EpubBookProgress, QDistinct> distinctByTitle({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'title', caseSensitive: caseSensitive);
    });
  }
}

extension EpubBookProgressQueryProperty
    on QueryBuilder<EpubBookProgress, EpubBookProgress, QQueryProperty> {
  QueryBuilder<EpubBookProgress, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<EpubBookProgress, String, QQueryOperations>
  archivePathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'archivePath');
    });
  }

  QueryBuilder<EpubBookProgress, String?, QQueryOperations> authorProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'author');
    });
  }

  QueryBuilder<EpubBookProgress, int, QQueryOperations> chapterIndexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'chapterIndex');
    });
  }

  QueryBuilder<EpubBookProgress, int, QQueryOperations>
  characterCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'characterCount');
    });
  }

  QueryBuilder<EpubBookProgress, int?, QQueryOperations>
  lastModifiedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastModified');
    });
  }

  QueryBuilder<EpubBookProgress, int, QQueryOperations> mangaIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'mangaId');
    });
  }

  QueryBuilder<EpubBookProgress, double, QQueryOperations> progressProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'progress');
    });
  }

  QueryBuilder<EpubBookProgress, String, QQueryOperations> titleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'title');
    });
  }
}
