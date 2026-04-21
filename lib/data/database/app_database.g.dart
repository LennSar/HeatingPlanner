// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ProjectsTable extends Projects with TableInfo<$ProjectsTable, Project> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProjectsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 255,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modifiedAtMeta = const VerificationMeta(
    'modifiedAt',
  );
  @override
  late final GeneratedColumn<DateTime> modifiedAt = GeneratedColumn<DateTime>(
    'modified_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _designOutdoorTempCMeta =
      const VerificationMeta('designOutdoorTempC');
  @override
  late final GeneratedColumn<double> designOutdoorTempC =
      GeneratedColumn<double>(
        'design_outdoor_temp_c',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
        defaultValue: const Constant(-12.0),
      );
  static const VerificationMeta _defaultIndoorTempCMeta =
      const VerificationMeta('defaultIndoorTempC');
  @override
  late final GeneratedColumn<double> defaultIndoorTempC =
      GeneratedColumn<double>(
        'default_indoor_temp_c',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
        defaultValue: const Constant(20.0),
      );
  static const VerificationMeta _floorHeightMmMeta = const VerificationMeta(
    'floorHeightMm',
  );
  @override
  late final GeneratedColumn<int> floorHeightMm = GeneratedColumn<int>(
    'floor_height_mm',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(2600),
  );
  static const VerificationMeta _unheatedSpaceTempCMeta =
      const VerificationMeta('unheatedSpaceTempC');
  @override
  late final GeneratedColumn<double> unheatedSpaceTempC =
      GeneratedColumn<double>(
        'unheated_space_temp_c',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
        defaultValue: const Constant(10.0),
      );
  static const VerificationMeta _locationJsonMeta = const VerificationMeta(
    'locationJson',
  );
  @override
  late final GeneratedColumn<String> locationJson = GeneratedColumn<String>(
    'location_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    createdAt,
    modifiedAt,
    designOutdoorTempC,
    defaultIndoorTempC,
    floorHeightMm,
    unheatedSpaceTempC,
    locationJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'projects';
  @override
  VerificationContext validateIntegrity(
    Insertable<Project> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('modified_at')) {
      context.handle(
        _modifiedAtMeta,
        modifiedAt.isAcceptableOrUnknown(data['modified_at']!, _modifiedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_modifiedAtMeta);
    }
    if (data.containsKey('design_outdoor_temp_c')) {
      context.handle(
        _designOutdoorTempCMeta,
        designOutdoorTempC.isAcceptableOrUnknown(
          data['design_outdoor_temp_c']!,
          _designOutdoorTempCMeta,
        ),
      );
    }
    if (data.containsKey('default_indoor_temp_c')) {
      context.handle(
        _defaultIndoorTempCMeta,
        defaultIndoorTempC.isAcceptableOrUnknown(
          data['default_indoor_temp_c']!,
          _defaultIndoorTempCMeta,
        ),
      );
    }
    if (data.containsKey('floor_height_mm')) {
      context.handle(
        _floorHeightMmMeta,
        floorHeightMm.isAcceptableOrUnknown(
          data['floor_height_mm']!,
          _floorHeightMmMeta,
        ),
      );
    }
    if (data.containsKey('unheated_space_temp_c')) {
      context.handle(
        _unheatedSpaceTempCMeta,
        unheatedSpaceTempC.isAcceptableOrUnknown(
          data['unheated_space_temp_c']!,
          _unheatedSpaceTempCMeta,
        ),
      );
    }
    if (data.containsKey('location_json')) {
      context.handle(
        _locationJsonMeta,
        locationJson.isAcceptableOrUnknown(
          data['location_json']!,
          _locationJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Project map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Project(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      modifiedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}modified_at'],
      )!,
      designOutdoorTempC: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}design_outdoor_temp_c'],
      )!,
      defaultIndoorTempC: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}default_indoor_temp_c'],
      )!,
      floorHeightMm: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}floor_height_mm'],
      )!,
      unheatedSpaceTempC: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}unheated_space_temp_c'],
      )!,
      locationJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location_json'],
      ),
    );
  }

  @override
  $ProjectsTable createAlias(String alias) {
    return $ProjectsTable(attachedDatabase, alias);
  }
}

class Project extends DataClass implements Insertable<Project> {
  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final double designOutdoorTempC;
  final double defaultIndoorTempC;
  final int floorHeightMm;
  final double unheatedSpaceTempC;

  /// Serialised JSON blob for the optional GeoLocation.
  final String? locationJson;
  const Project({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.modifiedAt,
    required this.designOutdoorTempC,
    required this.defaultIndoorTempC,
    required this.floorHeightMm,
    required this.unheatedSpaceTempC,
    this.locationJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['modified_at'] = Variable<DateTime>(modifiedAt);
    map['design_outdoor_temp_c'] = Variable<double>(designOutdoorTempC);
    map['default_indoor_temp_c'] = Variable<double>(defaultIndoorTempC);
    map['floor_height_mm'] = Variable<int>(floorHeightMm);
    map['unheated_space_temp_c'] = Variable<double>(unheatedSpaceTempC);
    if (!nullToAbsent || locationJson != null) {
      map['location_json'] = Variable<String>(locationJson);
    }
    return map;
  }

  ProjectsCompanion toCompanion(bool nullToAbsent) {
    return ProjectsCompanion(
      id: Value(id),
      name: Value(name),
      createdAt: Value(createdAt),
      modifiedAt: Value(modifiedAt),
      designOutdoorTempC: Value(designOutdoorTempC),
      defaultIndoorTempC: Value(defaultIndoorTempC),
      floorHeightMm: Value(floorHeightMm),
      unheatedSpaceTempC: Value(unheatedSpaceTempC),
      locationJson: locationJson == null && nullToAbsent
          ? const Value.absent()
          : Value(locationJson),
    );
  }

  factory Project.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Project(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      modifiedAt: serializer.fromJson<DateTime>(json['modifiedAt']),
      designOutdoorTempC: serializer.fromJson<double>(
        json['designOutdoorTempC'],
      ),
      defaultIndoorTempC: serializer.fromJson<double>(
        json['defaultIndoorTempC'],
      ),
      floorHeightMm: serializer.fromJson<int>(json['floorHeightMm']),
      unheatedSpaceTempC: serializer.fromJson<double>(
        json['unheatedSpaceTempC'],
      ),
      locationJson: serializer.fromJson<String?>(json['locationJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'modifiedAt': serializer.toJson<DateTime>(modifiedAt),
      'designOutdoorTempC': serializer.toJson<double>(designOutdoorTempC),
      'defaultIndoorTempC': serializer.toJson<double>(defaultIndoorTempC),
      'floorHeightMm': serializer.toJson<int>(floorHeightMm),
      'unheatedSpaceTempC': serializer.toJson<double>(unheatedSpaceTempC),
      'locationJson': serializer.toJson<String?>(locationJson),
    };
  }

  Project copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    DateTime? modifiedAt,
    double? designOutdoorTempC,
    double? defaultIndoorTempC,
    int? floorHeightMm,
    double? unheatedSpaceTempC,
    Value<String?> locationJson = const Value.absent(),
  }) => Project(
    id: id ?? this.id,
    name: name ?? this.name,
    createdAt: createdAt ?? this.createdAt,
    modifiedAt: modifiedAt ?? this.modifiedAt,
    designOutdoorTempC: designOutdoorTempC ?? this.designOutdoorTempC,
    defaultIndoorTempC: defaultIndoorTempC ?? this.defaultIndoorTempC,
    floorHeightMm: floorHeightMm ?? this.floorHeightMm,
    unheatedSpaceTempC: unheatedSpaceTempC ?? this.unheatedSpaceTempC,
    locationJson: locationJson.present ? locationJson.value : this.locationJson,
  );
  Project copyWithCompanion(ProjectsCompanion data) {
    return Project(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      modifiedAt: data.modifiedAt.present
          ? data.modifiedAt.value
          : this.modifiedAt,
      designOutdoorTempC: data.designOutdoorTempC.present
          ? data.designOutdoorTempC.value
          : this.designOutdoorTempC,
      defaultIndoorTempC: data.defaultIndoorTempC.present
          ? data.defaultIndoorTempC.value
          : this.defaultIndoorTempC,
      floorHeightMm: data.floorHeightMm.present
          ? data.floorHeightMm.value
          : this.floorHeightMm,
      unheatedSpaceTempC: data.unheatedSpaceTempC.present
          ? data.unheatedSpaceTempC.value
          : this.unheatedSpaceTempC,
      locationJson: data.locationJson.present
          ? data.locationJson.value
          : this.locationJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Project(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('modifiedAt: $modifiedAt, ')
          ..write('designOutdoorTempC: $designOutdoorTempC, ')
          ..write('defaultIndoorTempC: $defaultIndoorTempC, ')
          ..write('floorHeightMm: $floorHeightMm, ')
          ..write('unheatedSpaceTempC: $unheatedSpaceTempC, ')
          ..write('locationJson: $locationJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    createdAt,
    modifiedAt,
    designOutdoorTempC,
    defaultIndoorTempC,
    floorHeightMm,
    unheatedSpaceTempC,
    locationJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Project &&
          other.id == this.id &&
          other.name == this.name &&
          other.createdAt == this.createdAt &&
          other.modifiedAt == this.modifiedAt &&
          other.designOutdoorTempC == this.designOutdoorTempC &&
          other.defaultIndoorTempC == this.defaultIndoorTempC &&
          other.floorHeightMm == this.floorHeightMm &&
          other.unheatedSpaceTempC == this.unheatedSpaceTempC &&
          other.locationJson == this.locationJson);
}

class ProjectsCompanion extends UpdateCompanion<Project> {
  final Value<String> id;
  final Value<String> name;
  final Value<DateTime> createdAt;
  final Value<DateTime> modifiedAt;
  final Value<double> designOutdoorTempC;
  final Value<double> defaultIndoorTempC;
  final Value<int> floorHeightMm;
  final Value<double> unheatedSpaceTempC;
  final Value<String?> locationJson;
  final Value<int> rowid;
  const ProjectsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.modifiedAt = const Value.absent(),
    this.designOutdoorTempC = const Value.absent(),
    this.defaultIndoorTempC = const Value.absent(),
    this.floorHeightMm = const Value.absent(),
    this.unheatedSpaceTempC = const Value.absent(),
    this.locationJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProjectsCompanion.insert({
    required String id,
    required String name,
    required DateTime createdAt,
    required DateTime modifiedAt,
    this.designOutdoorTempC = const Value.absent(),
    this.defaultIndoorTempC = const Value.absent(),
    this.floorHeightMm = const Value.absent(),
    this.unheatedSpaceTempC = const Value.absent(),
    this.locationJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAt = Value(createdAt),
       modifiedAt = Value(modifiedAt);
  static Insertable<Project> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? modifiedAt,
    Expression<double>? designOutdoorTempC,
    Expression<double>? defaultIndoorTempC,
    Expression<int>? floorHeightMm,
    Expression<double>? unheatedSpaceTempC,
    Expression<String>? locationJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (createdAt != null) 'created_at': createdAt,
      if (modifiedAt != null) 'modified_at': modifiedAt,
      if (designOutdoorTempC != null)
        'design_outdoor_temp_c': designOutdoorTempC,
      if (defaultIndoorTempC != null)
        'default_indoor_temp_c': defaultIndoorTempC,
      if (floorHeightMm != null) 'floor_height_mm': floorHeightMm,
      if (unheatedSpaceTempC != null)
        'unheated_space_temp_c': unheatedSpaceTempC,
      if (locationJson != null) 'location_json': locationJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProjectsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<DateTime>? createdAt,
    Value<DateTime>? modifiedAt,
    Value<double>? designOutdoorTempC,
    Value<double>? defaultIndoorTempC,
    Value<int>? floorHeightMm,
    Value<double>? unheatedSpaceTempC,
    Value<String?>? locationJson,
    Value<int>? rowid,
  }) {
    return ProjectsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      designOutdoorTempC: designOutdoorTempC ?? this.designOutdoorTempC,
      defaultIndoorTempC: defaultIndoorTempC ?? this.defaultIndoorTempC,
      floorHeightMm: floorHeightMm ?? this.floorHeightMm,
      unheatedSpaceTempC: unheatedSpaceTempC ?? this.unheatedSpaceTempC,
      locationJson: locationJson ?? this.locationJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (modifiedAt.present) {
      map['modified_at'] = Variable<DateTime>(modifiedAt.value);
    }
    if (designOutdoorTempC.present) {
      map['design_outdoor_temp_c'] = Variable<double>(designOutdoorTempC.value);
    }
    if (defaultIndoorTempC.present) {
      map['default_indoor_temp_c'] = Variable<double>(defaultIndoorTempC.value);
    }
    if (floorHeightMm.present) {
      map['floor_height_mm'] = Variable<int>(floorHeightMm.value);
    }
    if (unheatedSpaceTempC.present) {
      map['unheated_space_temp_c'] = Variable<double>(unheatedSpaceTempC.value);
    }
    if (locationJson.present) {
      map['location_json'] = Variable<String>(locationJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProjectsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('modifiedAt: $modifiedAt, ')
          ..write('designOutdoorTempC: $designOutdoorTempC, ')
          ..write('defaultIndoorTempC: $defaultIndoorTempC, ')
          ..write('floorHeightMm: $floorHeightMm, ')
          ..write('unheatedSpaceTempC: $unheatedSpaceTempC, ')
          ..write('locationJson: $locationJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FloorsTable extends Floors with TableInfo<$FloorsTable, Floor> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FloorsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 100,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _levelMeta = const VerificationMeta('level');
  @override
  late final GeneratedColumn<int> level = GeneratedColumn<int>(
    'level',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _heightMmMeta = const VerificationMeta(
    'heightMm',
  );
  @override
  late final GeneratedColumn<int> heightMm = GeneratedColumn<int>(
    'height_mm',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(2600),
  );
  @override
  List<GeneratedColumn> get $columns => [id, projectId, name, level, heightMm];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'floors';
  @override
  VerificationContext validateIntegrity(
    Insertable<Floor> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('level')) {
      context.handle(
        _levelMeta,
        level.isAcceptableOrUnknown(data['level']!, _levelMeta),
      );
    }
    if (data.containsKey('height_mm')) {
      context.handle(
        _heightMmMeta,
        heightMm.isAcceptableOrUnknown(data['height_mm']!, _heightMmMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Floor map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Floor(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      level: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}level'],
      )!,
      heightMm: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}height_mm'],
      )!,
    );
  }

  @override
  $FloorsTable createAlias(String alias) {
    return $FloorsTable(attachedDatabase, alias);
  }
}

class Floor extends DataClass implements Insertable<Floor> {
  final String id;
  final String projectId;
  final String name;
  final int level;
  final int heightMm;
  const Floor({
    required this.id,
    required this.projectId,
    required this.name,
    required this.level,
    required this.heightMm,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['project_id'] = Variable<String>(projectId);
    map['name'] = Variable<String>(name);
    map['level'] = Variable<int>(level);
    map['height_mm'] = Variable<int>(heightMm);
    return map;
  }

  FloorsCompanion toCompanion(bool nullToAbsent) {
    return FloorsCompanion(
      id: Value(id),
      projectId: Value(projectId),
      name: Value(name),
      level: Value(level),
      heightMm: Value(heightMm),
    );
  }

  factory Floor.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Floor(
      id: serializer.fromJson<String>(json['id']),
      projectId: serializer.fromJson<String>(json['projectId']),
      name: serializer.fromJson<String>(json['name']),
      level: serializer.fromJson<int>(json['level']),
      heightMm: serializer.fromJson<int>(json['heightMm']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'projectId': serializer.toJson<String>(projectId),
      'name': serializer.toJson<String>(name),
      'level': serializer.toJson<int>(level),
      'heightMm': serializer.toJson<int>(heightMm),
    };
  }

  Floor copyWith({
    String? id,
    String? projectId,
    String? name,
    int? level,
    int? heightMm,
  }) => Floor(
    id: id ?? this.id,
    projectId: projectId ?? this.projectId,
    name: name ?? this.name,
    level: level ?? this.level,
    heightMm: heightMm ?? this.heightMm,
  );
  Floor copyWithCompanion(FloorsCompanion data) {
    return Floor(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      name: data.name.present ? data.name.value : this.name,
      level: data.level.present ? data.level.value : this.level,
      heightMm: data.heightMm.present ? data.heightMm.value : this.heightMm,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Floor(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('name: $name, ')
          ..write('level: $level, ')
          ..write('heightMm: $heightMm')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, projectId, name, level, heightMm);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Floor &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.name == this.name &&
          other.level == this.level &&
          other.heightMm == this.heightMm);
}

class FloorsCompanion extends UpdateCompanion<Floor> {
  final Value<String> id;
  final Value<String> projectId;
  final Value<String> name;
  final Value<int> level;
  final Value<int> heightMm;
  final Value<int> rowid;
  const FloorsCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.name = const Value.absent(),
    this.level = const Value.absent(),
    this.heightMm = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FloorsCompanion.insert({
    required String id,
    required String projectId,
    required String name,
    this.level = const Value.absent(),
    this.heightMm = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       projectId = Value(projectId),
       name = Value(name);
  static Insertable<Floor> custom({
    Expression<String>? id,
    Expression<String>? projectId,
    Expression<String>? name,
    Expression<int>? level,
    Expression<int>? heightMm,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (name != null) 'name': name,
      if (level != null) 'level': level,
      if (heightMm != null) 'height_mm': heightMm,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FloorsCompanion copyWith({
    Value<String>? id,
    Value<String>? projectId,
    Value<String>? name,
    Value<int>? level,
    Value<int>? heightMm,
    Value<int>? rowid,
  }) {
    return FloorsCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      name: name ?? this.name,
      level: level ?? this.level,
      heightMm: heightMm ?? this.heightMm,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (level.present) {
      map['level'] = Variable<int>(level.value);
    }
    if (heightMm.present) {
      map['height_mm'] = Variable<int>(heightMm.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FloorsCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('name: $name, ')
          ..write('level: $level, ')
          ..write('heightMm: $heightMm, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RoomsTable extends Rooms with TableInfo<$RoomsTable, Room> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RoomsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _floorIdMeta = const VerificationMeta(
    'floorId',
  );
  @override
  late final GeneratedColumn<String> floorId = GeneratedColumn<String>(
    'floor_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES floors (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 100,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetTempCMeta = const VerificationMeta(
    'targetTempC',
  );
  @override
  late final GeneratedColumn<double> targetTempC = GeneratedColumn<double>(
    'target_temp_c',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(20.0),
  );
  static const VerificationMeta _airChangeRateMeta = const VerificationMeta(
    'airChangeRate',
  );
  @override
  late final GeneratedColumn<double> airChangeRate = GeneratedColumn<double>(
    'air_change_rate',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.5),
  );
  static const VerificationMeta _polygonJsonMeta = const VerificationMeta(
    'polygonJson',
  );
  @override
  late final GeneratedColumn<String> polygonJson = GeneratedColumn<String>(
    'polygon_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _floorConstructionIdMeta =
      const VerificationMeta('floorConstructionId');
  @override
  late final GeneratedColumn<String> floorConstructionId =
      GeneratedColumn<String>(
        'floor_construction_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _ceilingConstructionIdMeta =
      const VerificationMeta('ceilingConstructionId');
  @override
  late final GeneratedColumn<String> ceilingConstructionId =
      GeneratedColumn<String>(
        'ceiling_construction_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _floorBoundaryMeta = const VerificationMeta(
    'floorBoundary',
  );
  @override
  late final GeneratedColumn<String> floorBoundary = GeneratedColumn<String>(
    'floor_boundary',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('ground'),
  );
  static const VerificationMeta _ceilingBoundaryMeta = const VerificationMeta(
    'ceilingBoundary',
  );
  @override
  late final GeneratedColumn<String> ceilingBoundary = GeneratedColumn<String>(
    'ceiling_boundary',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('exterior'),
  );
  static const VerificationMeta _floorAdjacentTempCMeta =
      const VerificationMeta('floorAdjacentTempC');
  @override
  late final GeneratedColumn<double> floorAdjacentTempC =
      GeneratedColumn<double>(
        'floor_adjacent_temp_c',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _ceilingAdjacentTempCMeta =
      const VerificationMeta('ceilingAdjacentTempC');
  @override
  late final GeneratedColumn<double> ceilingAdjacentTempC =
      GeneratedColumn<double>(
        'ceiling_adjacent_temp_c',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    floorId,
    name,
    targetTempC,
    airChangeRate,
    polygonJson,
    floorConstructionId,
    ceilingConstructionId,
    floorBoundary,
    ceilingBoundary,
    floorAdjacentTempC,
    ceilingAdjacentTempC,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rooms';
  @override
  VerificationContext validateIntegrity(
    Insertable<Room> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('floor_id')) {
      context.handle(
        _floorIdMeta,
        floorId.isAcceptableOrUnknown(data['floor_id']!, _floorIdMeta),
      );
    } else if (isInserting) {
      context.missing(_floorIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('target_temp_c')) {
      context.handle(
        _targetTempCMeta,
        targetTempC.isAcceptableOrUnknown(
          data['target_temp_c']!,
          _targetTempCMeta,
        ),
      );
    }
    if (data.containsKey('air_change_rate')) {
      context.handle(
        _airChangeRateMeta,
        airChangeRate.isAcceptableOrUnknown(
          data['air_change_rate']!,
          _airChangeRateMeta,
        ),
      );
    }
    if (data.containsKey('polygon_json')) {
      context.handle(
        _polygonJsonMeta,
        polygonJson.isAcceptableOrUnknown(
          data['polygon_json']!,
          _polygonJsonMeta,
        ),
      );
    }
    if (data.containsKey('floor_construction_id')) {
      context.handle(
        _floorConstructionIdMeta,
        floorConstructionId.isAcceptableOrUnknown(
          data['floor_construction_id']!,
          _floorConstructionIdMeta,
        ),
      );
    }
    if (data.containsKey('ceiling_construction_id')) {
      context.handle(
        _ceilingConstructionIdMeta,
        ceilingConstructionId.isAcceptableOrUnknown(
          data['ceiling_construction_id']!,
          _ceilingConstructionIdMeta,
        ),
      );
    }
    if (data.containsKey('floor_boundary')) {
      context.handle(
        _floorBoundaryMeta,
        floorBoundary.isAcceptableOrUnknown(
          data['floor_boundary']!,
          _floorBoundaryMeta,
        ),
      );
    }
    if (data.containsKey('ceiling_boundary')) {
      context.handle(
        _ceilingBoundaryMeta,
        ceilingBoundary.isAcceptableOrUnknown(
          data['ceiling_boundary']!,
          _ceilingBoundaryMeta,
        ),
      );
    }
    if (data.containsKey('floor_adjacent_temp_c')) {
      context.handle(
        _floorAdjacentTempCMeta,
        floorAdjacentTempC.isAcceptableOrUnknown(
          data['floor_adjacent_temp_c']!,
          _floorAdjacentTempCMeta,
        ),
      );
    }
    if (data.containsKey('ceiling_adjacent_temp_c')) {
      context.handle(
        _ceilingAdjacentTempCMeta,
        ceilingAdjacentTempC.isAcceptableOrUnknown(
          data['ceiling_adjacent_temp_c']!,
          _ceilingAdjacentTempCMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Room map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Room(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      floorId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}floor_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      targetTempC: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}target_temp_c'],
      )!,
      airChangeRate: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}air_change_rate'],
      )!,
      polygonJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}polygon_json'],
      )!,
      floorConstructionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}floor_construction_id'],
      ),
      ceilingConstructionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ceiling_construction_id'],
      ),
      floorBoundary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}floor_boundary'],
      )!,
      ceilingBoundary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ceiling_boundary'],
      )!,
      floorAdjacentTempC: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}floor_adjacent_temp_c'],
      ),
      ceilingAdjacentTempC: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}ceiling_adjacent_temp_c'],
      ),
    );
  }

  @override
  $RoomsTable createAlias(String alias) {
    return $RoomsTable(attachedDatabase, alias);
  }
}

class Room extends DataClass implements Insertable<Room> {
  final String id;
  final String floorId;
  final String name;
  final double targetTempC;
  final double airChangeRate;

  /// JSON array of {x, y} objects representing the room polygon in mm.
  final String polygonJson;

  /// UUID of the floor construction; null = not assigned.
  final String? floorConstructionId;

  /// UUID of the ceiling construction; null = not assigned.
  final String? ceilingConstructionId;

  /// Boundary condition below the floor slab (stored as enum name).
  final String floorBoundary;

  /// Boundary condition above the ceiling slab (stored as enum name).
  final String ceilingBoundary;

  /// Per-room adjacent temperature (°C) for the floor boundary.
  /// Null = use project-level default.
  final double? floorAdjacentTempC;

  /// Per-room adjacent temperature (°C) for the ceiling boundary.
  /// Null = use project-level default.
  final double? ceilingAdjacentTempC;
  const Room({
    required this.id,
    required this.floorId,
    required this.name,
    required this.targetTempC,
    required this.airChangeRate,
    required this.polygonJson,
    this.floorConstructionId,
    this.ceilingConstructionId,
    required this.floorBoundary,
    required this.ceilingBoundary,
    this.floorAdjacentTempC,
    this.ceilingAdjacentTempC,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['floor_id'] = Variable<String>(floorId);
    map['name'] = Variable<String>(name);
    map['target_temp_c'] = Variable<double>(targetTempC);
    map['air_change_rate'] = Variable<double>(airChangeRate);
    map['polygon_json'] = Variable<String>(polygonJson);
    if (!nullToAbsent || floorConstructionId != null) {
      map['floor_construction_id'] = Variable<String>(floorConstructionId);
    }
    if (!nullToAbsent || ceilingConstructionId != null) {
      map['ceiling_construction_id'] = Variable<String>(ceilingConstructionId);
    }
    map['floor_boundary'] = Variable<String>(floorBoundary);
    map['ceiling_boundary'] = Variable<String>(ceilingBoundary);
    if (!nullToAbsent || floorAdjacentTempC != null) {
      map['floor_adjacent_temp_c'] = Variable<double>(floorAdjacentTempC);
    }
    if (!nullToAbsent || ceilingAdjacentTempC != null) {
      map['ceiling_adjacent_temp_c'] = Variable<double>(ceilingAdjacentTempC);
    }
    return map;
  }

  RoomsCompanion toCompanion(bool nullToAbsent) {
    return RoomsCompanion(
      id: Value(id),
      floorId: Value(floorId),
      name: Value(name),
      targetTempC: Value(targetTempC),
      airChangeRate: Value(airChangeRate),
      polygonJson: Value(polygonJson),
      floorConstructionId: floorConstructionId == null && nullToAbsent
          ? const Value.absent()
          : Value(floorConstructionId),
      ceilingConstructionId: ceilingConstructionId == null && nullToAbsent
          ? const Value.absent()
          : Value(ceilingConstructionId),
      floorBoundary: Value(floorBoundary),
      ceilingBoundary: Value(ceilingBoundary),
      floorAdjacentTempC: floorAdjacentTempC == null && nullToAbsent
          ? const Value.absent()
          : Value(floorAdjacentTempC),
      ceilingAdjacentTempC: ceilingAdjacentTempC == null && nullToAbsent
          ? const Value.absent()
          : Value(ceilingAdjacentTempC),
    );
  }

  factory Room.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Room(
      id: serializer.fromJson<String>(json['id']),
      floorId: serializer.fromJson<String>(json['floorId']),
      name: serializer.fromJson<String>(json['name']),
      targetTempC: serializer.fromJson<double>(json['targetTempC']),
      airChangeRate: serializer.fromJson<double>(json['airChangeRate']),
      polygonJson: serializer.fromJson<String>(json['polygonJson']),
      floorConstructionId: serializer.fromJson<String?>(
        json['floorConstructionId'],
      ),
      ceilingConstructionId: serializer.fromJson<String?>(
        json['ceilingConstructionId'],
      ),
      floorBoundary: serializer.fromJson<String>(json['floorBoundary']),
      ceilingBoundary: serializer.fromJson<String>(json['ceilingBoundary']),
      floorAdjacentTempC: serializer.fromJson<double?>(
        json['floorAdjacentTempC'],
      ),
      ceilingAdjacentTempC: serializer.fromJson<double?>(
        json['ceilingAdjacentTempC'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'floorId': serializer.toJson<String>(floorId),
      'name': serializer.toJson<String>(name),
      'targetTempC': serializer.toJson<double>(targetTempC),
      'airChangeRate': serializer.toJson<double>(airChangeRate),
      'polygonJson': serializer.toJson<String>(polygonJson),
      'floorConstructionId': serializer.toJson<String?>(floorConstructionId),
      'ceilingConstructionId': serializer.toJson<String?>(
        ceilingConstructionId,
      ),
      'floorBoundary': serializer.toJson<String>(floorBoundary),
      'ceilingBoundary': serializer.toJson<String>(ceilingBoundary),
      'floorAdjacentTempC': serializer.toJson<double?>(floorAdjacentTempC),
      'ceilingAdjacentTempC': serializer.toJson<double?>(ceilingAdjacentTempC),
    };
  }

  Room copyWith({
    String? id,
    String? floorId,
    String? name,
    double? targetTempC,
    double? airChangeRate,
    String? polygonJson,
    Value<String?> floorConstructionId = const Value.absent(),
    Value<String?> ceilingConstructionId = const Value.absent(),
    String? floorBoundary,
    String? ceilingBoundary,
    Value<double?> floorAdjacentTempC = const Value.absent(),
    Value<double?> ceilingAdjacentTempC = const Value.absent(),
  }) => Room(
    id: id ?? this.id,
    floorId: floorId ?? this.floorId,
    name: name ?? this.name,
    targetTempC: targetTempC ?? this.targetTempC,
    airChangeRate: airChangeRate ?? this.airChangeRate,
    polygonJson: polygonJson ?? this.polygonJson,
    floorConstructionId: floorConstructionId.present
        ? floorConstructionId.value
        : this.floorConstructionId,
    ceilingConstructionId: ceilingConstructionId.present
        ? ceilingConstructionId.value
        : this.ceilingConstructionId,
    floorBoundary: floorBoundary ?? this.floorBoundary,
    ceilingBoundary: ceilingBoundary ?? this.ceilingBoundary,
    floorAdjacentTempC: floorAdjacentTempC.present
        ? floorAdjacentTempC.value
        : this.floorAdjacentTempC,
    ceilingAdjacentTempC: ceilingAdjacentTempC.present
        ? ceilingAdjacentTempC.value
        : this.ceilingAdjacentTempC,
  );
  Room copyWithCompanion(RoomsCompanion data) {
    return Room(
      id: data.id.present ? data.id.value : this.id,
      floorId: data.floorId.present ? data.floorId.value : this.floorId,
      name: data.name.present ? data.name.value : this.name,
      targetTempC: data.targetTempC.present
          ? data.targetTempC.value
          : this.targetTempC,
      airChangeRate: data.airChangeRate.present
          ? data.airChangeRate.value
          : this.airChangeRate,
      polygonJson: data.polygonJson.present
          ? data.polygonJson.value
          : this.polygonJson,
      floorConstructionId: data.floorConstructionId.present
          ? data.floorConstructionId.value
          : this.floorConstructionId,
      ceilingConstructionId: data.ceilingConstructionId.present
          ? data.ceilingConstructionId.value
          : this.ceilingConstructionId,
      floorBoundary: data.floorBoundary.present
          ? data.floorBoundary.value
          : this.floorBoundary,
      ceilingBoundary: data.ceilingBoundary.present
          ? data.ceilingBoundary.value
          : this.ceilingBoundary,
      floorAdjacentTempC: data.floorAdjacentTempC.present
          ? data.floorAdjacentTempC.value
          : this.floorAdjacentTempC,
      ceilingAdjacentTempC: data.ceilingAdjacentTempC.present
          ? data.ceilingAdjacentTempC.value
          : this.ceilingAdjacentTempC,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Room(')
          ..write('id: $id, ')
          ..write('floorId: $floorId, ')
          ..write('name: $name, ')
          ..write('targetTempC: $targetTempC, ')
          ..write('airChangeRate: $airChangeRate, ')
          ..write('polygonJson: $polygonJson, ')
          ..write('floorConstructionId: $floorConstructionId, ')
          ..write('ceilingConstructionId: $ceilingConstructionId, ')
          ..write('floorBoundary: $floorBoundary, ')
          ..write('ceilingBoundary: $ceilingBoundary, ')
          ..write('floorAdjacentTempC: $floorAdjacentTempC, ')
          ..write('ceilingAdjacentTempC: $ceilingAdjacentTempC')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    floorId,
    name,
    targetTempC,
    airChangeRate,
    polygonJson,
    floorConstructionId,
    ceilingConstructionId,
    floorBoundary,
    ceilingBoundary,
    floorAdjacentTempC,
    ceilingAdjacentTempC,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Room &&
          other.id == this.id &&
          other.floorId == this.floorId &&
          other.name == this.name &&
          other.targetTempC == this.targetTempC &&
          other.airChangeRate == this.airChangeRate &&
          other.polygonJson == this.polygonJson &&
          other.floorConstructionId == this.floorConstructionId &&
          other.ceilingConstructionId == this.ceilingConstructionId &&
          other.floorBoundary == this.floorBoundary &&
          other.ceilingBoundary == this.ceilingBoundary &&
          other.floorAdjacentTempC == this.floorAdjacentTempC &&
          other.ceilingAdjacentTempC == this.ceilingAdjacentTempC);
}

class RoomsCompanion extends UpdateCompanion<Room> {
  final Value<String> id;
  final Value<String> floorId;
  final Value<String> name;
  final Value<double> targetTempC;
  final Value<double> airChangeRate;
  final Value<String> polygonJson;
  final Value<String?> floorConstructionId;
  final Value<String?> ceilingConstructionId;
  final Value<String> floorBoundary;
  final Value<String> ceilingBoundary;
  final Value<double?> floorAdjacentTempC;
  final Value<double?> ceilingAdjacentTempC;
  final Value<int> rowid;
  const RoomsCompanion({
    this.id = const Value.absent(),
    this.floorId = const Value.absent(),
    this.name = const Value.absent(),
    this.targetTempC = const Value.absent(),
    this.airChangeRate = const Value.absent(),
    this.polygonJson = const Value.absent(),
    this.floorConstructionId = const Value.absent(),
    this.ceilingConstructionId = const Value.absent(),
    this.floorBoundary = const Value.absent(),
    this.ceilingBoundary = const Value.absent(),
    this.floorAdjacentTempC = const Value.absent(),
    this.ceilingAdjacentTempC = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RoomsCompanion.insert({
    required String id,
    required String floorId,
    required String name,
    this.targetTempC = const Value.absent(),
    this.airChangeRate = const Value.absent(),
    this.polygonJson = const Value.absent(),
    this.floorConstructionId = const Value.absent(),
    this.ceilingConstructionId = const Value.absent(),
    this.floorBoundary = const Value.absent(),
    this.ceilingBoundary = const Value.absent(),
    this.floorAdjacentTempC = const Value.absent(),
    this.ceilingAdjacentTempC = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       floorId = Value(floorId),
       name = Value(name);
  static Insertable<Room> custom({
    Expression<String>? id,
    Expression<String>? floorId,
    Expression<String>? name,
    Expression<double>? targetTempC,
    Expression<double>? airChangeRate,
    Expression<String>? polygonJson,
    Expression<String>? floorConstructionId,
    Expression<String>? ceilingConstructionId,
    Expression<String>? floorBoundary,
    Expression<String>? ceilingBoundary,
    Expression<double>? floorAdjacentTempC,
    Expression<double>? ceilingAdjacentTempC,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (floorId != null) 'floor_id': floorId,
      if (name != null) 'name': name,
      if (targetTempC != null) 'target_temp_c': targetTempC,
      if (airChangeRate != null) 'air_change_rate': airChangeRate,
      if (polygonJson != null) 'polygon_json': polygonJson,
      if (floorConstructionId != null)
        'floor_construction_id': floorConstructionId,
      if (ceilingConstructionId != null)
        'ceiling_construction_id': ceilingConstructionId,
      if (floorBoundary != null) 'floor_boundary': floorBoundary,
      if (ceilingBoundary != null) 'ceiling_boundary': ceilingBoundary,
      if (floorAdjacentTempC != null)
        'floor_adjacent_temp_c': floorAdjacentTempC,
      if (ceilingAdjacentTempC != null)
        'ceiling_adjacent_temp_c': ceilingAdjacentTempC,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RoomsCompanion copyWith({
    Value<String>? id,
    Value<String>? floorId,
    Value<String>? name,
    Value<double>? targetTempC,
    Value<double>? airChangeRate,
    Value<String>? polygonJson,
    Value<String?>? floorConstructionId,
    Value<String?>? ceilingConstructionId,
    Value<String>? floorBoundary,
    Value<String>? ceilingBoundary,
    Value<double?>? floorAdjacentTempC,
    Value<double?>? ceilingAdjacentTempC,
    Value<int>? rowid,
  }) {
    return RoomsCompanion(
      id: id ?? this.id,
      floorId: floorId ?? this.floorId,
      name: name ?? this.name,
      targetTempC: targetTempC ?? this.targetTempC,
      airChangeRate: airChangeRate ?? this.airChangeRate,
      polygonJson: polygonJson ?? this.polygonJson,
      floorConstructionId: floorConstructionId ?? this.floorConstructionId,
      ceilingConstructionId:
          ceilingConstructionId ?? this.ceilingConstructionId,
      floorBoundary: floorBoundary ?? this.floorBoundary,
      ceilingBoundary: ceilingBoundary ?? this.ceilingBoundary,
      floorAdjacentTempC: floorAdjacentTempC ?? this.floorAdjacentTempC,
      ceilingAdjacentTempC: ceilingAdjacentTempC ?? this.ceilingAdjacentTempC,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (floorId.present) {
      map['floor_id'] = Variable<String>(floorId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (targetTempC.present) {
      map['target_temp_c'] = Variable<double>(targetTempC.value);
    }
    if (airChangeRate.present) {
      map['air_change_rate'] = Variable<double>(airChangeRate.value);
    }
    if (polygonJson.present) {
      map['polygon_json'] = Variable<String>(polygonJson.value);
    }
    if (floorConstructionId.present) {
      map['floor_construction_id'] = Variable<String>(
        floorConstructionId.value,
      );
    }
    if (ceilingConstructionId.present) {
      map['ceiling_construction_id'] = Variable<String>(
        ceilingConstructionId.value,
      );
    }
    if (floorBoundary.present) {
      map['floor_boundary'] = Variable<String>(floorBoundary.value);
    }
    if (ceilingBoundary.present) {
      map['ceiling_boundary'] = Variable<String>(ceilingBoundary.value);
    }
    if (floorAdjacentTempC.present) {
      map['floor_adjacent_temp_c'] = Variable<double>(floorAdjacentTempC.value);
    }
    if (ceilingAdjacentTempC.present) {
      map['ceiling_adjacent_temp_c'] = Variable<double>(
        ceilingAdjacentTempC.value,
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RoomsCompanion(')
          ..write('id: $id, ')
          ..write('floorId: $floorId, ')
          ..write('name: $name, ')
          ..write('targetTempC: $targetTempC, ')
          ..write('airChangeRate: $airChangeRate, ')
          ..write('polygonJson: $polygonJson, ')
          ..write('floorConstructionId: $floorConstructionId, ')
          ..write('ceilingConstructionId: $ceilingConstructionId, ')
          ..write('floorBoundary: $floorBoundary, ')
          ..write('ceilingBoundary: $ceilingBoundary, ')
          ..write('floorAdjacentTempC: $floorAdjacentTempC, ')
          ..write('ceilingAdjacentTempC: $ceilingAdjacentTempC, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WallConstructionsTable extends WallConstructions
    with TableInfo<$WallConstructionsTable, WallConstruction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WallConstructionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 200,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rsiMeta = const VerificationMeta('rsi');
  @override
  late final GeneratedColumn<double> rsi = GeneratedColumn<double>(
    'rsi',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.13),
  );
  static const VerificationMeta _rseMeta = const VerificationMeta('rse');
  @override
  late final GeneratedColumn<double> rse = GeneratedColumn<double>(
    'rse',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.04),
  );
  static const VerificationMeta _isPresetMeta = const VerificationMeta(
    'isPreset',
  );
  @override
  late final GeneratedColumn<int> isPreset = GeneratedColumn<int>(
    'is_preset',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, rsi, rse, isPreset];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'wall_constructions';
  @override
  VerificationContext validateIntegrity(
    Insertable<WallConstruction> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('rsi')) {
      context.handle(
        _rsiMeta,
        rsi.isAcceptableOrUnknown(data['rsi']!, _rsiMeta),
      );
    }
    if (data.containsKey('rse')) {
      context.handle(
        _rseMeta,
        rse.isAcceptableOrUnknown(data['rse']!, _rseMeta),
      );
    }
    if (data.containsKey('is_preset')) {
      context.handle(
        _isPresetMeta,
        isPreset.isAcceptableOrUnknown(data['is_preset']!, _isPresetMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WallConstruction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WallConstruction(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      rsi: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}rsi'],
      )!,
      rse: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}rse'],
      )!,
      isPreset: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}is_preset'],
      )!,
    );
  }

  @override
  $WallConstructionsTable createAlias(String alias) {
    return $WallConstructionsTable(attachedDatabase, alias);
  }
}

class WallConstruction extends DataClass
    implements Insertable<WallConstruction> {
  final String id;
  final String name;
  final double rsi;
  final double rse;

  /// 1 = preset, 0 = regular construction.
  final int isPreset;
  const WallConstruction({
    required this.id,
    required this.name,
    required this.rsi,
    required this.rse,
    required this.isPreset,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['rsi'] = Variable<double>(rsi);
    map['rse'] = Variable<double>(rse);
    map['is_preset'] = Variable<int>(isPreset);
    return map;
  }

  WallConstructionsCompanion toCompanion(bool nullToAbsent) {
    return WallConstructionsCompanion(
      id: Value(id),
      name: Value(name),
      rsi: Value(rsi),
      rse: Value(rse),
      isPreset: Value(isPreset),
    );
  }

  factory WallConstruction.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WallConstruction(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      rsi: serializer.fromJson<double>(json['rsi']),
      rse: serializer.fromJson<double>(json['rse']),
      isPreset: serializer.fromJson<int>(json['isPreset']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'rsi': serializer.toJson<double>(rsi),
      'rse': serializer.toJson<double>(rse),
      'isPreset': serializer.toJson<int>(isPreset),
    };
  }

  WallConstruction copyWith({
    String? id,
    String? name,
    double? rsi,
    double? rse,
    int? isPreset,
  }) => WallConstruction(
    id: id ?? this.id,
    name: name ?? this.name,
    rsi: rsi ?? this.rsi,
    rse: rse ?? this.rse,
    isPreset: isPreset ?? this.isPreset,
  );
  WallConstruction copyWithCompanion(WallConstructionsCompanion data) {
    return WallConstruction(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      rsi: data.rsi.present ? data.rsi.value : this.rsi,
      rse: data.rse.present ? data.rse.value : this.rse,
      isPreset: data.isPreset.present ? data.isPreset.value : this.isPreset,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WallConstruction(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('rsi: $rsi, ')
          ..write('rse: $rse, ')
          ..write('isPreset: $isPreset')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, rsi, rse, isPreset);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WallConstruction &&
          other.id == this.id &&
          other.name == this.name &&
          other.rsi == this.rsi &&
          other.rse == this.rse &&
          other.isPreset == this.isPreset);
}

class WallConstructionsCompanion extends UpdateCompanion<WallConstruction> {
  final Value<String> id;
  final Value<String> name;
  final Value<double> rsi;
  final Value<double> rse;
  final Value<int> isPreset;
  final Value<int> rowid;
  const WallConstructionsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.rsi = const Value.absent(),
    this.rse = const Value.absent(),
    this.isPreset = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WallConstructionsCompanion.insert({
    required String id,
    required String name,
    this.rsi = const Value.absent(),
    this.rse = const Value.absent(),
    this.isPreset = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<WallConstruction> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<double>? rsi,
    Expression<double>? rse,
    Expression<int>? isPreset,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (rsi != null) 'rsi': rsi,
      if (rse != null) 'rse': rse,
      if (isPreset != null) 'is_preset': isPreset,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WallConstructionsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<double>? rsi,
    Value<double>? rse,
    Value<int>? isPreset,
    Value<int>? rowid,
  }) {
    return WallConstructionsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      rsi: rsi ?? this.rsi,
      rse: rse ?? this.rse,
      isPreset: isPreset ?? this.isPreset,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (rsi.present) {
      map['rsi'] = Variable<double>(rsi.value);
    }
    if (rse.present) {
      map['rse'] = Variable<double>(rse.value);
    }
    if (isPreset.present) {
      map['is_preset'] = Variable<int>(isPreset.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WallConstructionsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('rsi: $rsi, ')
          ..write('rse: $rse, ')
          ..write('isPreset: $isPreset, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WallSegmentsTable extends WallSegments
    with TableInfo<$WallSegmentsTable, WallSegment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WallSegmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roomIdMeta = const VerificationMeta('roomId');
  @override
  late final GeneratedColumn<String> roomId = GeneratedColumn<String>(
    'room_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES rooms (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _startPointJsonMeta = const VerificationMeta(
    'startPointJson',
  );
  @override
  late final GeneratedColumn<String> startPointJson = GeneratedColumn<String>(
    'start_point_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endPointJsonMeta = const VerificationMeta(
    'endPointJson',
  );
  @override
  late final GeneratedColumn<String> endPointJson = GeneratedColumn<String>(
    'end_point_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _wallTypeMeta = const VerificationMeta(
    'wallType',
  );
  @override
  late final GeneratedColumn<String> wallType = GeneratedColumn<String>(
    'wall_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('exterior'),
  );
  static const VerificationMeta _constructionIdMeta = const VerificationMeta(
    'constructionId',
  );
  @override
  late final GeneratedColumn<String> constructionId = GeneratedColumn<String>(
    'construction_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES wall_constructions (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _adjacentRoomIdMeta = const VerificationMeta(
    'adjacentRoomId',
  );
  @override
  late final GeneratedColumn<String> adjacentRoomId = GeneratedColumn<String>(
    'adjacent_room_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES rooms (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _orientationMeta = const VerificationMeta(
    'orientation',
  );
  @override
  late final GeneratedColumn<String> orientation = GeneratedColumn<String>(
    'orientation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('north'),
  );
  static const VerificationMeta _mirrorIdMeta = const VerificationMeta(
    'mirrorId',
  );
  @override
  late final GeneratedColumn<String> mirrorId = GeneratedColumn<String>(
    'mirror_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES wall_segments (id) ON DELETE SET NULL',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    roomId,
    startPointJson,
    endPointJson,
    wallType,
    constructionId,
    adjacentRoomId,
    orientation,
    mirrorId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'wall_segments';
  @override
  VerificationContext validateIntegrity(
    Insertable<WallSegment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('room_id')) {
      context.handle(
        _roomIdMeta,
        roomId.isAcceptableOrUnknown(data['room_id']!, _roomIdMeta),
      );
    } else if (isInserting) {
      context.missing(_roomIdMeta);
    }
    if (data.containsKey('start_point_json')) {
      context.handle(
        _startPointJsonMeta,
        startPointJson.isAcceptableOrUnknown(
          data['start_point_json']!,
          _startPointJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startPointJsonMeta);
    }
    if (data.containsKey('end_point_json')) {
      context.handle(
        _endPointJsonMeta,
        endPointJson.isAcceptableOrUnknown(
          data['end_point_json']!,
          _endPointJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_endPointJsonMeta);
    }
    if (data.containsKey('wall_type')) {
      context.handle(
        _wallTypeMeta,
        wallType.isAcceptableOrUnknown(data['wall_type']!, _wallTypeMeta),
      );
    }
    if (data.containsKey('construction_id')) {
      context.handle(
        _constructionIdMeta,
        constructionId.isAcceptableOrUnknown(
          data['construction_id']!,
          _constructionIdMeta,
        ),
      );
    }
    if (data.containsKey('adjacent_room_id')) {
      context.handle(
        _adjacentRoomIdMeta,
        adjacentRoomId.isAcceptableOrUnknown(
          data['adjacent_room_id']!,
          _adjacentRoomIdMeta,
        ),
      );
    }
    if (data.containsKey('orientation')) {
      context.handle(
        _orientationMeta,
        orientation.isAcceptableOrUnknown(
          data['orientation']!,
          _orientationMeta,
        ),
      );
    }
    if (data.containsKey('mirror_id')) {
      context.handle(
        _mirrorIdMeta,
        mirrorId.isAcceptableOrUnknown(data['mirror_id']!, _mirrorIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WallSegment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WallSegment(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      roomId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}room_id'],
      )!,
      startPointJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}start_point_json'],
      )!,
      endPointJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}end_point_json'],
      )!,
      wallType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}wall_type'],
      )!,
      constructionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}construction_id'],
      ),
      adjacentRoomId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}adjacent_room_id'],
      ),
      orientation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}orientation'],
      )!,
      mirrorId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mirror_id'],
      ),
    );
  }

  @override
  $WallSegmentsTable createAlias(String alias) {
    return $WallSegmentsTable(attachedDatabase, alias);
  }
}

class WallSegment extends DataClass implements Insertable<WallSegment> {
  final String id;
  final String roomId;

  /// JSON {x,y} for the start vertex.
  final String startPointJson;

  /// JSON {x,y} for the end vertex.
  final String endPointJson;
  final String wallType;
  final String? constructionId;
  final String? adjacentRoomId;
  final String orientation;

  /// UUID of the mirror wall in an ADR-001 pair.
  ///
  /// Nullable self-referencing FK. Set to NULL via `ON DELETE SET NULL`
  /// when the partner wall is deleted (ADR-011 Rule 5).
  final String? mirrorId;
  const WallSegment({
    required this.id,
    required this.roomId,
    required this.startPointJson,
    required this.endPointJson,
    required this.wallType,
    this.constructionId,
    this.adjacentRoomId,
    required this.orientation,
    this.mirrorId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['room_id'] = Variable<String>(roomId);
    map['start_point_json'] = Variable<String>(startPointJson);
    map['end_point_json'] = Variable<String>(endPointJson);
    map['wall_type'] = Variable<String>(wallType);
    if (!nullToAbsent || constructionId != null) {
      map['construction_id'] = Variable<String>(constructionId);
    }
    if (!nullToAbsent || adjacentRoomId != null) {
      map['adjacent_room_id'] = Variable<String>(adjacentRoomId);
    }
    map['orientation'] = Variable<String>(orientation);
    if (!nullToAbsent || mirrorId != null) {
      map['mirror_id'] = Variable<String>(mirrorId);
    }
    return map;
  }

  WallSegmentsCompanion toCompanion(bool nullToAbsent) {
    return WallSegmentsCompanion(
      id: Value(id),
      roomId: Value(roomId),
      startPointJson: Value(startPointJson),
      endPointJson: Value(endPointJson),
      wallType: Value(wallType),
      constructionId: constructionId == null && nullToAbsent
          ? const Value.absent()
          : Value(constructionId),
      adjacentRoomId: adjacentRoomId == null && nullToAbsent
          ? const Value.absent()
          : Value(adjacentRoomId),
      orientation: Value(orientation),
      mirrorId: mirrorId == null && nullToAbsent
          ? const Value.absent()
          : Value(mirrorId),
    );
  }

  factory WallSegment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WallSegment(
      id: serializer.fromJson<String>(json['id']),
      roomId: serializer.fromJson<String>(json['roomId']),
      startPointJson: serializer.fromJson<String>(json['startPointJson']),
      endPointJson: serializer.fromJson<String>(json['endPointJson']),
      wallType: serializer.fromJson<String>(json['wallType']),
      constructionId: serializer.fromJson<String?>(json['constructionId']),
      adjacentRoomId: serializer.fromJson<String?>(json['adjacentRoomId']),
      orientation: serializer.fromJson<String>(json['orientation']),
      mirrorId: serializer.fromJson<String?>(json['mirrorId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'roomId': serializer.toJson<String>(roomId),
      'startPointJson': serializer.toJson<String>(startPointJson),
      'endPointJson': serializer.toJson<String>(endPointJson),
      'wallType': serializer.toJson<String>(wallType),
      'constructionId': serializer.toJson<String?>(constructionId),
      'adjacentRoomId': serializer.toJson<String?>(adjacentRoomId),
      'orientation': serializer.toJson<String>(orientation),
      'mirrorId': serializer.toJson<String?>(mirrorId),
    };
  }

  WallSegment copyWith({
    String? id,
    String? roomId,
    String? startPointJson,
    String? endPointJson,
    String? wallType,
    Value<String?> constructionId = const Value.absent(),
    Value<String?> adjacentRoomId = const Value.absent(),
    String? orientation,
    Value<String?> mirrorId = const Value.absent(),
  }) => WallSegment(
    id: id ?? this.id,
    roomId: roomId ?? this.roomId,
    startPointJson: startPointJson ?? this.startPointJson,
    endPointJson: endPointJson ?? this.endPointJson,
    wallType: wallType ?? this.wallType,
    constructionId: constructionId.present
        ? constructionId.value
        : this.constructionId,
    adjacentRoomId: adjacentRoomId.present
        ? adjacentRoomId.value
        : this.adjacentRoomId,
    orientation: orientation ?? this.orientation,
    mirrorId: mirrorId.present ? mirrorId.value : this.mirrorId,
  );
  WallSegment copyWithCompanion(WallSegmentsCompanion data) {
    return WallSegment(
      id: data.id.present ? data.id.value : this.id,
      roomId: data.roomId.present ? data.roomId.value : this.roomId,
      startPointJson: data.startPointJson.present
          ? data.startPointJson.value
          : this.startPointJson,
      endPointJson: data.endPointJson.present
          ? data.endPointJson.value
          : this.endPointJson,
      wallType: data.wallType.present ? data.wallType.value : this.wallType,
      constructionId: data.constructionId.present
          ? data.constructionId.value
          : this.constructionId,
      adjacentRoomId: data.adjacentRoomId.present
          ? data.adjacentRoomId.value
          : this.adjacentRoomId,
      orientation: data.orientation.present
          ? data.orientation.value
          : this.orientation,
      mirrorId: data.mirrorId.present ? data.mirrorId.value : this.mirrorId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WallSegment(')
          ..write('id: $id, ')
          ..write('roomId: $roomId, ')
          ..write('startPointJson: $startPointJson, ')
          ..write('endPointJson: $endPointJson, ')
          ..write('wallType: $wallType, ')
          ..write('constructionId: $constructionId, ')
          ..write('adjacentRoomId: $adjacentRoomId, ')
          ..write('orientation: $orientation, ')
          ..write('mirrorId: $mirrorId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    roomId,
    startPointJson,
    endPointJson,
    wallType,
    constructionId,
    adjacentRoomId,
    orientation,
    mirrorId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WallSegment &&
          other.id == this.id &&
          other.roomId == this.roomId &&
          other.startPointJson == this.startPointJson &&
          other.endPointJson == this.endPointJson &&
          other.wallType == this.wallType &&
          other.constructionId == this.constructionId &&
          other.adjacentRoomId == this.adjacentRoomId &&
          other.orientation == this.orientation &&
          other.mirrorId == this.mirrorId);
}

class WallSegmentsCompanion extends UpdateCompanion<WallSegment> {
  final Value<String> id;
  final Value<String> roomId;
  final Value<String> startPointJson;
  final Value<String> endPointJson;
  final Value<String> wallType;
  final Value<String?> constructionId;
  final Value<String?> adjacentRoomId;
  final Value<String> orientation;
  final Value<String?> mirrorId;
  final Value<int> rowid;
  const WallSegmentsCompanion({
    this.id = const Value.absent(),
    this.roomId = const Value.absent(),
    this.startPointJson = const Value.absent(),
    this.endPointJson = const Value.absent(),
    this.wallType = const Value.absent(),
    this.constructionId = const Value.absent(),
    this.adjacentRoomId = const Value.absent(),
    this.orientation = const Value.absent(),
    this.mirrorId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WallSegmentsCompanion.insert({
    required String id,
    required String roomId,
    required String startPointJson,
    required String endPointJson,
    this.wallType = const Value.absent(),
    this.constructionId = const Value.absent(),
    this.adjacentRoomId = const Value.absent(),
    this.orientation = const Value.absent(),
    this.mirrorId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       roomId = Value(roomId),
       startPointJson = Value(startPointJson),
       endPointJson = Value(endPointJson);
  static Insertable<WallSegment> custom({
    Expression<String>? id,
    Expression<String>? roomId,
    Expression<String>? startPointJson,
    Expression<String>? endPointJson,
    Expression<String>? wallType,
    Expression<String>? constructionId,
    Expression<String>? adjacentRoomId,
    Expression<String>? orientation,
    Expression<String>? mirrorId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (roomId != null) 'room_id': roomId,
      if (startPointJson != null) 'start_point_json': startPointJson,
      if (endPointJson != null) 'end_point_json': endPointJson,
      if (wallType != null) 'wall_type': wallType,
      if (constructionId != null) 'construction_id': constructionId,
      if (adjacentRoomId != null) 'adjacent_room_id': adjacentRoomId,
      if (orientation != null) 'orientation': orientation,
      if (mirrorId != null) 'mirror_id': mirrorId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WallSegmentsCompanion copyWith({
    Value<String>? id,
    Value<String>? roomId,
    Value<String>? startPointJson,
    Value<String>? endPointJson,
    Value<String>? wallType,
    Value<String?>? constructionId,
    Value<String?>? adjacentRoomId,
    Value<String>? orientation,
    Value<String?>? mirrorId,
    Value<int>? rowid,
  }) {
    return WallSegmentsCompanion(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      startPointJson: startPointJson ?? this.startPointJson,
      endPointJson: endPointJson ?? this.endPointJson,
      wallType: wallType ?? this.wallType,
      constructionId: constructionId ?? this.constructionId,
      adjacentRoomId: adjacentRoomId ?? this.adjacentRoomId,
      orientation: orientation ?? this.orientation,
      mirrorId: mirrorId ?? this.mirrorId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (roomId.present) {
      map['room_id'] = Variable<String>(roomId.value);
    }
    if (startPointJson.present) {
      map['start_point_json'] = Variable<String>(startPointJson.value);
    }
    if (endPointJson.present) {
      map['end_point_json'] = Variable<String>(endPointJson.value);
    }
    if (wallType.present) {
      map['wall_type'] = Variable<String>(wallType.value);
    }
    if (constructionId.present) {
      map['construction_id'] = Variable<String>(constructionId.value);
    }
    if (adjacentRoomId.present) {
      map['adjacent_room_id'] = Variable<String>(adjacentRoomId.value);
    }
    if (orientation.present) {
      map['orientation'] = Variable<String>(orientation.value);
    }
    if (mirrorId.present) {
      map['mirror_id'] = Variable<String>(mirrorId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WallSegmentsCompanion(')
          ..write('id: $id, ')
          ..write('roomId: $roomId, ')
          ..write('startPointJson: $startPointJson, ')
          ..write('endPointJson: $endPointJson, ')
          ..write('wallType: $wallType, ')
          ..write('constructionId: $constructionId, ')
          ..write('adjacentRoomId: $adjacentRoomId, ')
          ..write('orientation: $orientation, ')
          ..write('mirrorId: $mirrorId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WindowsTable extends Windows with TableInfo<$WindowsTable, Window> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WindowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _wallSegmentIdMeta = const VerificationMeta(
    'wallSegmentId',
  );
  @override
  late final GeneratedColumn<String> wallSegmentId = GeneratedColumn<String>(
    'wall_segment_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES wall_segments (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _positionOnWallMmMeta = const VerificationMeta(
    'positionOnWallMm',
  );
  @override
  late final GeneratedColumn<double> positionOnWallMm = GeneratedColumn<double>(
    'position_on_wall_mm',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _widthMmMeta = const VerificationMeta(
    'widthMm',
  );
  @override
  late final GeneratedColumn<int> widthMm = GeneratedColumn<int>(
    'width_mm',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1200),
  );
  static const VerificationMeta _heightMmMeta = const VerificationMeta(
    'heightMm',
  );
  @override
  late final GeneratedColumn<int> heightMm = GeneratedColumn<int>(
    'height_mm',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1400),
  );
  static const VerificationMeta _sillHeightMmMeta = const VerificationMeta(
    'sillHeightMm',
  );
  @override
  late final GeneratedColumn<int> sillHeightMm = GeneratedColumn<int>(
    'sill_height_mm',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(900),
  );
  static const VerificationMeta _uValueMeta = const VerificationMeta('uValue');
  @override
  late final GeneratedColumn<double> uValue = GeneratedColumn<double>(
    'u_value',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1.3),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    wallSegmentId,
    positionOnWallMm,
    widthMm,
    heightMm,
    sillHeightMm,
    uValue,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'windows';
  @override
  VerificationContext validateIntegrity(
    Insertable<Window> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('wall_segment_id')) {
      context.handle(
        _wallSegmentIdMeta,
        wallSegmentId.isAcceptableOrUnknown(
          data['wall_segment_id']!,
          _wallSegmentIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_wallSegmentIdMeta);
    }
    if (data.containsKey('position_on_wall_mm')) {
      context.handle(
        _positionOnWallMmMeta,
        positionOnWallMm.isAcceptableOrUnknown(
          data['position_on_wall_mm']!,
          _positionOnWallMmMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_positionOnWallMmMeta);
    }
    if (data.containsKey('width_mm')) {
      context.handle(
        _widthMmMeta,
        widthMm.isAcceptableOrUnknown(data['width_mm']!, _widthMmMeta),
      );
    }
    if (data.containsKey('height_mm')) {
      context.handle(
        _heightMmMeta,
        heightMm.isAcceptableOrUnknown(data['height_mm']!, _heightMmMeta),
      );
    }
    if (data.containsKey('sill_height_mm')) {
      context.handle(
        _sillHeightMmMeta,
        sillHeightMm.isAcceptableOrUnknown(
          data['sill_height_mm']!,
          _sillHeightMmMeta,
        ),
      );
    }
    if (data.containsKey('u_value')) {
      context.handle(
        _uValueMeta,
        uValue.isAcceptableOrUnknown(data['u_value']!, _uValueMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Window map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Window(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      wallSegmentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}wall_segment_id'],
      )!,
      positionOnWallMm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}position_on_wall_mm'],
      )!,
      widthMm: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}width_mm'],
      )!,
      heightMm: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}height_mm'],
      )!,
      sillHeightMm: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sill_height_mm'],
      )!,
      uValue: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}u_value'],
      )!,
    );
  }

  @override
  $WindowsTable createAlias(String alias) {
    return $WindowsTable(attachedDatabase, alias);
  }
}

class Window extends DataClass implements Insertable<Window> {
  final String id;
  final String wallSegmentId;
  final double positionOnWallMm;
  final int widthMm;
  final int heightMm;
  final int sillHeightMm;
  final double uValue;
  const Window({
    required this.id,
    required this.wallSegmentId,
    required this.positionOnWallMm,
    required this.widthMm,
    required this.heightMm,
    required this.sillHeightMm,
    required this.uValue,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['wall_segment_id'] = Variable<String>(wallSegmentId);
    map['position_on_wall_mm'] = Variable<double>(positionOnWallMm);
    map['width_mm'] = Variable<int>(widthMm);
    map['height_mm'] = Variable<int>(heightMm);
    map['sill_height_mm'] = Variable<int>(sillHeightMm);
    map['u_value'] = Variable<double>(uValue);
    return map;
  }

  WindowsCompanion toCompanion(bool nullToAbsent) {
    return WindowsCompanion(
      id: Value(id),
      wallSegmentId: Value(wallSegmentId),
      positionOnWallMm: Value(positionOnWallMm),
      widthMm: Value(widthMm),
      heightMm: Value(heightMm),
      sillHeightMm: Value(sillHeightMm),
      uValue: Value(uValue),
    );
  }

  factory Window.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Window(
      id: serializer.fromJson<String>(json['id']),
      wallSegmentId: serializer.fromJson<String>(json['wallSegmentId']),
      positionOnWallMm: serializer.fromJson<double>(json['positionOnWallMm']),
      widthMm: serializer.fromJson<int>(json['widthMm']),
      heightMm: serializer.fromJson<int>(json['heightMm']),
      sillHeightMm: serializer.fromJson<int>(json['sillHeightMm']),
      uValue: serializer.fromJson<double>(json['uValue']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'wallSegmentId': serializer.toJson<String>(wallSegmentId),
      'positionOnWallMm': serializer.toJson<double>(positionOnWallMm),
      'widthMm': serializer.toJson<int>(widthMm),
      'heightMm': serializer.toJson<int>(heightMm),
      'sillHeightMm': serializer.toJson<int>(sillHeightMm),
      'uValue': serializer.toJson<double>(uValue),
    };
  }

  Window copyWith({
    String? id,
    String? wallSegmentId,
    double? positionOnWallMm,
    int? widthMm,
    int? heightMm,
    int? sillHeightMm,
    double? uValue,
  }) => Window(
    id: id ?? this.id,
    wallSegmentId: wallSegmentId ?? this.wallSegmentId,
    positionOnWallMm: positionOnWallMm ?? this.positionOnWallMm,
    widthMm: widthMm ?? this.widthMm,
    heightMm: heightMm ?? this.heightMm,
    sillHeightMm: sillHeightMm ?? this.sillHeightMm,
    uValue: uValue ?? this.uValue,
  );
  Window copyWithCompanion(WindowsCompanion data) {
    return Window(
      id: data.id.present ? data.id.value : this.id,
      wallSegmentId: data.wallSegmentId.present
          ? data.wallSegmentId.value
          : this.wallSegmentId,
      positionOnWallMm: data.positionOnWallMm.present
          ? data.positionOnWallMm.value
          : this.positionOnWallMm,
      widthMm: data.widthMm.present ? data.widthMm.value : this.widthMm,
      heightMm: data.heightMm.present ? data.heightMm.value : this.heightMm,
      sillHeightMm: data.sillHeightMm.present
          ? data.sillHeightMm.value
          : this.sillHeightMm,
      uValue: data.uValue.present ? data.uValue.value : this.uValue,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Window(')
          ..write('id: $id, ')
          ..write('wallSegmentId: $wallSegmentId, ')
          ..write('positionOnWallMm: $positionOnWallMm, ')
          ..write('widthMm: $widthMm, ')
          ..write('heightMm: $heightMm, ')
          ..write('sillHeightMm: $sillHeightMm, ')
          ..write('uValue: $uValue')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    wallSegmentId,
    positionOnWallMm,
    widthMm,
    heightMm,
    sillHeightMm,
    uValue,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Window &&
          other.id == this.id &&
          other.wallSegmentId == this.wallSegmentId &&
          other.positionOnWallMm == this.positionOnWallMm &&
          other.widthMm == this.widthMm &&
          other.heightMm == this.heightMm &&
          other.sillHeightMm == this.sillHeightMm &&
          other.uValue == this.uValue);
}

class WindowsCompanion extends UpdateCompanion<Window> {
  final Value<String> id;
  final Value<String> wallSegmentId;
  final Value<double> positionOnWallMm;
  final Value<int> widthMm;
  final Value<int> heightMm;
  final Value<int> sillHeightMm;
  final Value<double> uValue;
  final Value<int> rowid;
  const WindowsCompanion({
    this.id = const Value.absent(),
    this.wallSegmentId = const Value.absent(),
    this.positionOnWallMm = const Value.absent(),
    this.widthMm = const Value.absent(),
    this.heightMm = const Value.absent(),
    this.sillHeightMm = const Value.absent(),
    this.uValue = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WindowsCompanion.insert({
    required String id,
    required String wallSegmentId,
    required double positionOnWallMm,
    this.widthMm = const Value.absent(),
    this.heightMm = const Value.absent(),
    this.sillHeightMm = const Value.absent(),
    this.uValue = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       wallSegmentId = Value(wallSegmentId),
       positionOnWallMm = Value(positionOnWallMm);
  static Insertable<Window> custom({
    Expression<String>? id,
    Expression<String>? wallSegmentId,
    Expression<double>? positionOnWallMm,
    Expression<int>? widthMm,
    Expression<int>? heightMm,
    Expression<int>? sillHeightMm,
    Expression<double>? uValue,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (wallSegmentId != null) 'wall_segment_id': wallSegmentId,
      if (positionOnWallMm != null) 'position_on_wall_mm': positionOnWallMm,
      if (widthMm != null) 'width_mm': widthMm,
      if (heightMm != null) 'height_mm': heightMm,
      if (sillHeightMm != null) 'sill_height_mm': sillHeightMm,
      if (uValue != null) 'u_value': uValue,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WindowsCompanion copyWith({
    Value<String>? id,
    Value<String>? wallSegmentId,
    Value<double>? positionOnWallMm,
    Value<int>? widthMm,
    Value<int>? heightMm,
    Value<int>? sillHeightMm,
    Value<double>? uValue,
    Value<int>? rowid,
  }) {
    return WindowsCompanion(
      id: id ?? this.id,
      wallSegmentId: wallSegmentId ?? this.wallSegmentId,
      positionOnWallMm: positionOnWallMm ?? this.positionOnWallMm,
      widthMm: widthMm ?? this.widthMm,
      heightMm: heightMm ?? this.heightMm,
      sillHeightMm: sillHeightMm ?? this.sillHeightMm,
      uValue: uValue ?? this.uValue,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (wallSegmentId.present) {
      map['wall_segment_id'] = Variable<String>(wallSegmentId.value);
    }
    if (positionOnWallMm.present) {
      map['position_on_wall_mm'] = Variable<double>(positionOnWallMm.value);
    }
    if (widthMm.present) {
      map['width_mm'] = Variable<int>(widthMm.value);
    }
    if (heightMm.present) {
      map['height_mm'] = Variable<int>(heightMm.value);
    }
    if (sillHeightMm.present) {
      map['sill_height_mm'] = Variable<int>(sillHeightMm.value);
    }
    if (uValue.present) {
      map['u_value'] = Variable<double>(uValue.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WindowsCompanion(')
          ..write('id: $id, ')
          ..write('wallSegmentId: $wallSegmentId, ')
          ..write('positionOnWallMm: $positionOnWallMm, ')
          ..write('widthMm: $widthMm, ')
          ..write('heightMm: $heightMm, ')
          ..write('sillHeightMm: $sillHeightMm, ')
          ..write('uValue: $uValue, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DoorsTable extends Doors with TableInfo<$DoorsTable, Door> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DoorsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _wallSegmentIdMeta = const VerificationMeta(
    'wallSegmentId',
  );
  @override
  late final GeneratedColumn<String> wallSegmentId = GeneratedColumn<String>(
    'wall_segment_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES wall_segments (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _positionOnWallMmMeta = const VerificationMeta(
    'positionOnWallMm',
  );
  @override
  late final GeneratedColumn<double> positionOnWallMm = GeneratedColumn<double>(
    'position_on_wall_mm',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _widthMmMeta = const VerificationMeta(
    'widthMm',
  );
  @override
  late final GeneratedColumn<int> widthMm = GeneratedColumn<int>(
    'width_mm',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(900),
  );
  static const VerificationMeta _heightMmMeta = const VerificationMeta(
    'heightMm',
  );
  @override
  late final GeneratedColumn<int> heightMm = GeneratedColumn<int>(
    'height_mm',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(2100),
  );
  static const VerificationMeta _sillHeightMmMeta = const VerificationMeta(
    'sillHeightMm',
  );
  @override
  late final GeneratedColumn<int> sillHeightMm = GeneratedColumn<int>(
    'sill_height_mm',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _uValueMeta = const VerificationMeta('uValue');
  @override
  late final GeneratedColumn<double> uValue = GeneratedColumn<double>(
    'u_value',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(2.0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    wallSegmentId,
    positionOnWallMm,
    widthMm,
    heightMm,
    sillHeightMm,
    uValue,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'doors';
  @override
  VerificationContext validateIntegrity(
    Insertable<Door> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('wall_segment_id')) {
      context.handle(
        _wallSegmentIdMeta,
        wallSegmentId.isAcceptableOrUnknown(
          data['wall_segment_id']!,
          _wallSegmentIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_wallSegmentIdMeta);
    }
    if (data.containsKey('position_on_wall_mm')) {
      context.handle(
        _positionOnWallMmMeta,
        positionOnWallMm.isAcceptableOrUnknown(
          data['position_on_wall_mm']!,
          _positionOnWallMmMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_positionOnWallMmMeta);
    }
    if (data.containsKey('width_mm')) {
      context.handle(
        _widthMmMeta,
        widthMm.isAcceptableOrUnknown(data['width_mm']!, _widthMmMeta),
      );
    }
    if (data.containsKey('height_mm')) {
      context.handle(
        _heightMmMeta,
        heightMm.isAcceptableOrUnknown(data['height_mm']!, _heightMmMeta),
      );
    }
    if (data.containsKey('sill_height_mm')) {
      context.handle(
        _sillHeightMmMeta,
        sillHeightMm.isAcceptableOrUnknown(
          data['sill_height_mm']!,
          _sillHeightMmMeta,
        ),
      );
    }
    if (data.containsKey('u_value')) {
      context.handle(
        _uValueMeta,
        uValue.isAcceptableOrUnknown(data['u_value']!, _uValueMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Door map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Door(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      wallSegmentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}wall_segment_id'],
      )!,
      positionOnWallMm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}position_on_wall_mm'],
      )!,
      widthMm: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}width_mm'],
      )!,
      heightMm: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}height_mm'],
      )!,
      sillHeightMm: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sill_height_mm'],
      )!,
      uValue: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}u_value'],
      )!,
    );
  }

  @override
  $DoorsTable createAlias(String alias) {
    return $DoorsTable(attachedDatabase, alias);
  }
}

class Door extends DataClass implements Insertable<Door> {
  final String id;
  final String wallSegmentId;
  final double positionOnWallMm;
  final int widthMm;
  final int heightMm;
  final int sillHeightMm;
  final double uValue;
  const Door({
    required this.id,
    required this.wallSegmentId,
    required this.positionOnWallMm,
    required this.widthMm,
    required this.heightMm,
    required this.sillHeightMm,
    required this.uValue,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['wall_segment_id'] = Variable<String>(wallSegmentId);
    map['position_on_wall_mm'] = Variable<double>(positionOnWallMm);
    map['width_mm'] = Variable<int>(widthMm);
    map['height_mm'] = Variable<int>(heightMm);
    map['sill_height_mm'] = Variable<int>(sillHeightMm);
    map['u_value'] = Variable<double>(uValue);
    return map;
  }

  DoorsCompanion toCompanion(bool nullToAbsent) {
    return DoorsCompanion(
      id: Value(id),
      wallSegmentId: Value(wallSegmentId),
      positionOnWallMm: Value(positionOnWallMm),
      widthMm: Value(widthMm),
      heightMm: Value(heightMm),
      sillHeightMm: Value(sillHeightMm),
      uValue: Value(uValue),
    );
  }

  factory Door.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Door(
      id: serializer.fromJson<String>(json['id']),
      wallSegmentId: serializer.fromJson<String>(json['wallSegmentId']),
      positionOnWallMm: serializer.fromJson<double>(json['positionOnWallMm']),
      widthMm: serializer.fromJson<int>(json['widthMm']),
      heightMm: serializer.fromJson<int>(json['heightMm']),
      sillHeightMm: serializer.fromJson<int>(json['sillHeightMm']),
      uValue: serializer.fromJson<double>(json['uValue']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'wallSegmentId': serializer.toJson<String>(wallSegmentId),
      'positionOnWallMm': serializer.toJson<double>(positionOnWallMm),
      'widthMm': serializer.toJson<int>(widthMm),
      'heightMm': serializer.toJson<int>(heightMm),
      'sillHeightMm': serializer.toJson<int>(sillHeightMm),
      'uValue': serializer.toJson<double>(uValue),
    };
  }

  Door copyWith({
    String? id,
    String? wallSegmentId,
    double? positionOnWallMm,
    int? widthMm,
    int? heightMm,
    int? sillHeightMm,
    double? uValue,
  }) => Door(
    id: id ?? this.id,
    wallSegmentId: wallSegmentId ?? this.wallSegmentId,
    positionOnWallMm: positionOnWallMm ?? this.positionOnWallMm,
    widthMm: widthMm ?? this.widthMm,
    heightMm: heightMm ?? this.heightMm,
    sillHeightMm: sillHeightMm ?? this.sillHeightMm,
    uValue: uValue ?? this.uValue,
  );
  Door copyWithCompanion(DoorsCompanion data) {
    return Door(
      id: data.id.present ? data.id.value : this.id,
      wallSegmentId: data.wallSegmentId.present
          ? data.wallSegmentId.value
          : this.wallSegmentId,
      positionOnWallMm: data.positionOnWallMm.present
          ? data.positionOnWallMm.value
          : this.positionOnWallMm,
      widthMm: data.widthMm.present ? data.widthMm.value : this.widthMm,
      heightMm: data.heightMm.present ? data.heightMm.value : this.heightMm,
      sillHeightMm: data.sillHeightMm.present
          ? data.sillHeightMm.value
          : this.sillHeightMm,
      uValue: data.uValue.present ? data.uValue.value : this.uValue,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Door(')
          ..write('id: $id, ')
          ..write('wallSegmentId: $wallSegmentId, ')
          ..write('positionOnWallMm: $positionOnWallMm, ')
          ..write('widthMm: $widthMm, ')
          ..write('heightMm: $heightMm, ')
          ..write('sillHeightMm: $sillHeightMm, ')
          ..write('uValue: $uValue')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    wallSegmentId,
    positionOnWallMm,
    widthMm,
    heightMm,
    sillHeightMm,
    uValue,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Door &&
          other.id == this.id &&
          other.wallSegmentId == this.wallSegmentId &&
          other.positionOnWallMm == this.positionOnWallMm &&
          other.widthMm == this.widthMm &&
          other.heightMm == this.heightMm &&
          other.sillHeightMm == this.sillHeightMm &&
          other.uValue == this.uValue);
}

class DoorsCompanion extends UpdateCompanion<Door> {
  final Value<String> id;
  final Value<String> wallSegmentId;
  final Value<double> positionOnWallMm;
  final Value<int> widthMm;
  final Value<int> heightMm;
  final Value<int> sillHeightMm;
  final Value<double> uValue;
  final Value<int> rowid;
  const DoorsCompanion({
    this.id = const Value.absent(),
    this.wallSegmentId = const Value.absent(),
    this.positionOnWallMm = const Value.absent(),
    this.widthMm = const Value.absent(),
    this.heightMm = const Value.absent(),
    this.sillHeightMm = const Value.absent(),
    this.uValue = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DoorsCompanion.insert({
    required String id,
    required String wallSegmentId,
    required double positionOnWallMm,
    this.widthMm = const Value.absent(),
    this.heightMm = const Value.absent(),
    this.sillHeightMm = const Value.absent(),
    this.uValue = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       wallSegmentId = Value(wallSegmentId),
       positionOnWallMm = Value(positionOnWallMm);
  static Insertable<Door> custom({
    Expression<String>? id,
    Expression<String>? wallSegmentId,
    Expression<double>? positionOnWallMm,
    Expression<int>? widthMm,
    Expression<int>? heightMm,
    Expression<int>? sillHeightMm,
    Expression<double>? uValue,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (wallSegmentId != null) 'wall_segment_id': wallSegmentId,
      if (positionOnWallMm != null) 'position_on_wall_mm': positionOnWallMm,
      if (widthMm != null) 'width_mm': widthMm,
      if (heightMm != null) 'height_mm': heightMm,
      if (sillHeightMm != null) 'sill_height_mm': sillHeightMm,
      if (uValue != null) 'u_value': uValue,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DoorsCompanion copyWith({
    Value<String>? id,
    Value<String>? wallSegmentId,
    Value<double>? positionOnWallMm,
    Value<int>? widthMm,
    Value<int>? heightMm,
    Value<int>? sillHeightMm,
    Value<double>? uValue,
    Value<int>? rowid,
  }) {
    return DoorsCompanion(
      id: id ?? this.id,
      wallSegmentId: wallSegmentId ?? this.wallSegmentId,
      positionOnWallMm: positionOnWallMm ?? this.positionOnWallMm,
      widthMm: widthMm ?? this.widthMm,
      heightMm: heightMm ?? this.heightMm,
      sillHeightMm: sillHeightMm ?? this.sillHeightMm,
      uValue: uValue ?? this.uValue,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (wallSegmentId.present) {
      map['wall_segment_id'] = Variable<String>(wallSegmentId.value);
    }
    if (positionOnWallMm.present) {
      map['position_on_wall_mm'] = Variable<double>(positionOnWallMm.value);
    }
    if (widthMm.present) {
      map['width_mm'] = Variable<int>(widthMm.value);
    }
    if (heightMm.present) {
      map['height_mm'] = Variable<int>(heightMm.value);
    }
    if (sillHeightMm.present) {
      map['sill_height_mm'] = Variable<int>(sillHeightMm.value);
    }
    if (uValue.present) {
      map['u_value'] = Variable<double>(uValue.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DoorsCompanion(')
          ..write('id: $id, ')
          ..write('wallSegmentId: $wallSegmentId, ')
          ..write('positionOnWallMm: $positionOnWallMm, ')
          ..write('widthMm: $widthMm, ')
          ..write('heightMm: $heightMm, ')
          ..write('sillHeightMm: $sillHeightMm, ')
          ..write('uValue: $uValue, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MaterialEntriesTable extends MaterialEntries
    with TableInfo<$MaterialEntriesTable, MaterialEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MaterialEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 200,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subcategoryMeta = const VerificationMeta(
    'subcategory',
  );
  @override
  late final GeneratedColumn<String> subcategory = GeneratedColumn<String>(
    'subcategory',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _lambdaDefaultMeta = const VerificationMeta(
    'lambdaDefault',
  );
  @override
  late final GeneratedColumn<double> lambdaDefault = GeneratedColumn<double>(
    'lambda_default',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _densityDefaultMeta = const VerificationMeta(
    'densityDefault',
  );
  @override
  late final GeneratedColumn<double> densityDefault = GeneratedColumn<double>(
    'density_default',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _specificHeatDefaultMeta =
      const VerificationMeta('specificHeatDefault');
  @override
  late final GeneratedColumn<double> specificHeatDefault =
      GeneratedColumn<double>(
        'specific_heat_default',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _isBuiltInMeta = const VerificationMeta(
    'isBuiltIn',
  );
  @override
  late final GeneratedColumn<bool> isBuiltIn = GeneratedColumn<bool>(
    'is_built_in',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_built_in" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    category,
    subcategory,
    lambdaDefault,
    densityDefault,
    specificHeatDefault,
    isBuiltIn,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'material_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<MaterialEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('subcategory')) {
      context.handle(
        _subcategoryMeta,
        subcategory.isAcceptableOrUnknown(
          data['subcategory']!,
          _subcategoryMeta,
        ),
      );
    }
    if (data.containsKey('lambda_default')) {
      context.handle(
        _lambdaDefaultMeta,
        lambdaDefault.isAcceptableOrUnknown(
          data['lambda_default']!,
          _lambdaDefaultMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lambdaDefaultMeta);
    }
    if (data.containsKey('density_default')) {
      context.handle(
        _densityDefaultMeta,
        densityDefault.isAcceptableOrUnknown(
          data['density_default']!,
          _densityDefaultMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_densityDefaultMeta);
    }
    if (data.containsKey('specific_heat_default')) {
      context.handle(
        _specificHeatDefaultMeta,
        specificHeatDefault.isAcceptableOrUnknown(
          data['specific_heat_default']!,
          _specificHeatDefaultMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_specificHeatDefaultMeta);
    }
    if (data.containsKey('is_built_in')) {
      context.handle(
        _isBuiltInMeta,
        isBuiltIn.isAcceptableOrUnknown(data['is_built_in']!, _isBuiltInMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MaterialEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MaterialEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      subcategory: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subcategory'],
      )!,
      lambdaDefault: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lambda_default'],
      )!,
      densityDefault: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}density_default'],
      )!,
      specificHeatDefault: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}specific_heat_default'],
      )!,
      isBuiltIn: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_built_in'],
      )!,
    );
  }

  @override
  $MaterialEntriesTable createAlias(String alias) {
    return $MaterialEntriesTable(attachedDatabase, alias);
  }
}

class MaterialEntry extends DataClass implements Insertable<MaterialEntry> {
  final String id;
  final String name;
  final String category;
  final String subcategory;
  final double lambdaDefault;
  final double densityDefault;
  final double specificHeatDefault;
  final bool isBuiltIn;
  const MaterialEntry({
    required this.id,
    required this.name,
    required this.category,
    required this.subcategory,
    required this.lambdaDefault,
    required this.densityDefault,
    required this.specificHeatDefault,
    required this.isBuiltIn,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['category'] = Variable<String>(category);
    map['subcategory'] = Variable<String>(subcategory);
    map['lambda_default'] = Variable<double>(lambdaDefault);
    map['density_default'] = Variable<double>(densityDefault);
    map['specific_heat_default'] = Variable<double>(specificHeatDefault);
    map['is_built_in'] = Variable<bool>(isBuiltIn);
    return map;
  }

  MaterialEntriesCompanion toCompanion(bool nullToAbsent) {
    return MaterialEntriesCompanion(
      id: Value(id),
      name: Value(name),
      category: Value(category),
      subcategory: Value(subcategory),
      lambdaDefault: Value(lambdaDefault),
      densityDefault: Value(densityDefault),
      specificHeatDefault: Value(specificHeatDefault),
      isBuiltIn: Value(isBuiltIn),
    );
  }

  factory MaterialEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MaterialEntry(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      category: serializer.fromJson<String>(json['category']),
      subcategory: serializer.fromJson<String>(json['subcategory']),
      lambdaDefault: serializer.fromJson<double>(json['lambdaDefault']),
      densityDefault: serializer.fromJson<double>(json['densityDefault']),
      specificHeatDefault: serializer.fromJson<double>(
        json['specificHeatDefault'],
      ),
      isBuiltIn: serializer.fromJson<bool>(json['isBuiltIn']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'category': serializer.toJson<String>(category),
      'subcategory': serializer.toJson<String>(subcategory),
      'lambdaDefault': serializer.toJson<double>(lambdaDefault),
      'densityDefault': serializer.toJson<double>(densityDefault),
      'specificHeatDefault': serializer.toJson<double>(specificHeatDefault),
      'isBuiltIn': serializer.toJson<bool>(isBuiltIn),
    };
  }

  MaterialEntry copyWith({
    String? id,
    String? name,
    String? category,
    String? subcategory,
    double? lambdaDefault,
    double? densityDefault,
    double? specificHeatDefault,
    bool? isBuiltIn,
  }) => MaterialEntry(
    id: id ?? this.id,
    name: name ?? this.name,
    category: category ?? this.category,
    subcategory: subcategory ?? this.subcategory,
    lambdaDefault: lambdaDefault ?? this.lambdaDefault,
    densityDefault: densityDefault ?? this.densityDefault,
    specificHeatDefault: specificHeatDefault ?? this.specificHeatDefault,
    isBuiltIn: isBuiltIn ?? this.isBuiltIn,
  );
  MaterialEntry copyWithCompanion(MaterialEntriesCompanion data) {
    return MaterialEntry(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      category: data.category.present ? data.category.value : this.category,
      subcategory: data.subcategory.present
          ? data.subcategory.value
          : this.subcategory,
      lambdaDefault: data.lambdaDefault.present
          ? data.lambdaDefault.value
          : this.lambdaDefault,
      densityDefault: data.densityDefault.present
          ? data.densityDefault.value
          : this.densityDefault,
      specificHeatDefault: data.specificHeatDefault.present
          ? data.specificHeatDefault.value
          : this.specificHeatDefault,
      isBuiltIn: data.isBuiltIn.present ? data.isBuiltIn.value : this.isBuiltIn,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MaterialEntry(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('category: $category, ')
          ..write('subcategory: $subcategory, ')
          ..write('lambdaDefault: $lambdaDefault, ')
          ..write('densityDefault: $densityDefault, ')
          ..write('specificHeatDefault: $specificHeatDefault, ')
          ..write('isBuiltIn: $isBuiltIn')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    category,
    subcategory,
    lambdaDefault,
    densityDefault,
    specificHeatDefault,
    isBuiltIn,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MaterialEntry &&
          other.id == this.id &&
          other.name == this.name &&
          other.category == this.category &&
          other.subcategory == this.subcategory &&
          other.lambdaDefault == this.lambdaDefault &&
          other.densityDefault == this.densityDefault &&
          other.specificHeatDefault == this.specificHeatDefault &&
          other.isBuiltIn == this.isBuiltIn);
}

class MaterialEntriesCompanion extends UpdateCompanion<MaterialEntry> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> category;
  final Value<String> subcategory;
  final Value<double> lambdaDefault;
  final Value<double> densityDefault;
  final Value<double> specificHeatDefault;
  final Value<bool> isBuiltIn;
  final Value<int> rowid;
  const MaterialEntriesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.category = const Value.absent(),
    this.subcategory = const Value.absent(),
    this.lambdaDefault = const Value.absent(),
    this.densityDefault = const Value.absent(),
    this.specificHeatDefault = const Value.absent(),
    this.isBuiltIn = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MaterialEntriesCompanion.insert({
    required String id,
    required String name,
    required String category,
    this.subcategory = const Value.absent(),
    required double lambdaDefault,
    required double densityDefault,
    required double specificHeatDefault,
    this.isBuiltIn = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       category = Value(category),
       lambdaDefault = Value(lambdaDefault),
       densityDefault = Value(densityDefault),
       specificHeatDefault = Value(specificHeatDefault);
  static Insertable<MaterialEntry> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? category,
    Expression<String>? subcategory,
    Expression<double>? lambdaDefault,
    Expression<double>? densityDefault,
    Expression<double>? specificHeatDefault,
    Expression<bool>? isBuiltIn,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (category != null) 'category': category,
      if (subcategory != null) 'subcategory': subcategory,
      if (lambdaDefault != null) 'lambda_default': lambdaDefault,
      if (densityDefault != null) 'density_default': densityDefault,
      if (specificHeatDefault != null)
        'specific_heat_default': specificHeatDefault,
      if (isBuiltIn != null) 'is_built_in': isBuiltIn,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MaterialEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? category,
    Value<String>? subcategory,
    Value<double>? lambdaDefault,
    Value<double>? densityDefault,
    Value<double>? specificHeatDefault,
    Value<bool>? isBuiltIn,
    Value<int>? rowid,
  }) {
    return MaterialEntriesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      subcategory: subcategory ?? this.subcategory,
      lambdaDefault: lambdaDefault ?? this.lambdaDefault,
      densityDefault: densityDefault ?? this.densityDefault,
      specificHeatDefault: specificHeatDefault ?? this.specificHeatDefault,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (subcategory.present) {
      map['subcategory'] = Variable<String>(subcategory.value);
    }
    if (lambdaDefault.present) {
      map['lambda_default'] = Variable<double>(lambdaDefault.value);
    }
    if (densityDefault.present) {
      map['density_default'] = Variable<double>(densityDefault.value);
    }
    if (specificHeatDefault.present) {
      map['specific_heat_default'] = Variable<double>(
        specificHeatDefault.value,
      );
    }
    if (isBuiltIn.present) {
      map['is_built_in'] = Variable<bool>(isBuiltIn.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MaterialEntriesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('category: $category, ')
          ..write('subcategory: $subcategory, ')
          ..write('lambdaDefault: $lambdaDefault, ')
          ..write('densityDefault: $densityDefault, ')
          ..write('specificHeatDefault: $specificHeatDefault, ')
          ..write('isBuiltIn: $isBuiltIn, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MaterialLayersTable extends MaterialLayers
    with TableInfo<$MaterialLayersTable, MaterialLayer> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MaterialLayersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _constructionIdMeta = const VerificationMeta(
    'constructionId',
  );
  @override
  late final GeneratedColumn<String> constructionId = GeneratedColumn<String>(
    'construction_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES wall_constructions (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _materialIdMeta = const VerificationMeta(
    'materialId',
  );
  @override
  late final GeneratedColumn<String> materialId = GeneratedColumn<String>(
    'material_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES material_entries (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _thicknessMmMeta = const VerificationMeta(
    'thicknessMm',
  );
  @override
  late final GeneratedColumn<double> thicknessMm = GeneratedColumn<double>(
    'thickness_mm',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _thermalConductivityMeta =
      const VerificationMeta('thermalConductivity');
  @override
  late final GeneratedColumn<double> thermalConductivity =
      GeneratedColumn<double>(
        'thermal_conductivity',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _densityMeta = const VerificationMeta(
    'density',
  );
  @override
  late final GeneratedColumn<double> density = GeneratedColumn<double>(
    'density',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _specificHeatMeta = const VerificationMeta(
    'specificHeat',
  );
  @override
  late final GeneratedColumn<double> specificHeat = GeneratedColumn<double>(
    'specific_heat',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _studWidthMmMeta = const VerificationMeta(
    'studWidthMm',
  );
  @override
  late final GeneratedColumn<double> studWidthMm = GeneratedColumn<double>(
    'stud_width_mm',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _studClearGapMmMeta = const VerificationMeta(
    'studClearGapMm',
  );
  @override
  late final GeneratedColumn<double> studClearGapMm = GeneratedColumn<double>(
    'stud_clear_gap_mm',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _studLambdaMeta = const VerificationMeta(
    'studLambda',
  );
  @override
  late final GeneratedColumn<double> studLambda = GeneratedColumn<double>(
    'stud_lambda',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    constructionId,
    sortOrder,
    materialId,
    thicknessMm,
    thermalConductivity,
    density,
    specificHeat,
    studWidthMm,
    studClearGapMm,
    studLambda,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'material_layers';
  @override
  VerificationContext validateIntegrity(
    Insertable<MaterialLayer> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('construction_id')) {
      context.handle(
        _constructionIdMeta,
        constructionId.isAcceptableOrUnknown(
          data['construction_id']!,
          _constructionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_constructionIdMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('material_id')) {
      context.handle(
        _materialIdMeta,
        materialId.isAcceptableOrUnknown(data['material_id']!, _materialIdMeta),
      );
    } else if (isInserting) {
      context.missing(_materialIdMeta);
    }
    if (data.containsKey('thickness_mm')) {
      context.handle(
        _thicknessMmMeta,
        thicknessMm.isAcceptableOrUnknown(
          data['thickness_mm']!,
          _thicknessMmMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_thicknessMmMeta);
    }
    if (data.containsKey('thermal_conductivity')) {
      context.handle(
        _thermalConductivityMeta,
        thermalConductivity.isAcceptableOrUnknown(
          data['thermal_conductivity']!,
          _thermalConductivityMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_thermalConductivityMeta);
    }
    if (data.containsKey('density')) {
      context.handle(
        _densityMeta,
        density.isAcceptableOrUnknown(data['density']!, _densityMeta),
      );
    } else if (isInserting) {
      context.missing(_densityMeta);
    }
    if (data.containsKey('specific_heat')) {
      context.handle(
        _specificHeatMeta,
        specificHeat.isAcceptableOrUnknown(
          data['specific_heat']!,
          _specificHeatMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_specificHeatMeta);
    }
    if (data.containsKey('stud_width_mm')) {
      context.handle(
        _studWidthMmMeta,
        studWidthMm.isAcceptableOrUnknown(
          data['stud_width_mm']!,
          _studWidthMmMeta,
        ),
      );
    }
    if (data.containsKey('stud_clear_gap_mm')) {
      context.handle(
        _studClearGapMmMeta,
        studClearGapMm.isAcceptableOrUnknown(
          data['stud_clear_gap_mm']!,
          _studClearGapMmMeta,
        ),
      );
    }
    if (data.containsKey('stud_lambda')) {
      context.handle(
        _studLambdaMeta,
        studLambda.isAcceptableOrUnknown(data['stud_lambda']!, _studLambdaMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MaterialLayer map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MaterialLayer(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      constructionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}construction_id'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      materialId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}material_id'],
      )!,
      thicknessMm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}thickness_mm'],
      )!,
      thermalConductivity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}thermal_conductivity'],
      )!,
      density: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}density'],
      )!,
      specificHeat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}specific_heat'],
      )!,
      studWidthMm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}stud_width_mm'],
      ),
      studClearGapMm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}stud_clear_gap_mm'],
      ),
      studLambda: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}stud_lambda'],
      ),
    );
  }

  @override
  $MaterialLayersTable createAlias(String alias) {
    return $MaterialLayersTable(attachedDatabase, alias);
  }
}

class MaterialLayer extends DataClass implements Insertable<MaterialLayer> {
  final String id;
  final String constructionId;
  final int sortOrder;
  final String materialId;
  final double thicknessMm;
  final double thermalConductivity;
  final double density;
  final double specificHeat;

  /// Stud width in mm. Non-null → inhomogeneous layer. Always set together
  /// with [studClearGapMm] and [studLambda].
  final double? studWidthMm;

  /// Clear gap between studs in mm (edge-to-edge, not centre-to-centre).
  final double? studClearGapMm;

  /// Thermal conductivity of the stud material in W/(m·K).
  final double? studLambda;
  const MaterialLayer({
    required this.id,
    required this.constructionId,
    required this.sortOrder,
    required this.materialId,
    required this.thicknessMm,
    required this.thermalConductivity,
    required this.density,
    required this.specificHeat,
    this.studWidthMm,
    this.studClearGapMm,
    this.studLambda,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['construction_id'] = Variable<String>(constructionId);
    map['sort_order'] = Variable<int>(sortOrder);
    map['material_id'] = Variable<String>(materialId);
    map['thickness_mm'] = Variable<double>(thicknessMm);
    map['thermal_conductivity'] = Variable<double>(thermalConductivity);
    map['density'] = Variable<double>(density);
    map['specific_heat'] = Variable<double>(specificHeat);
    if (!nullToAbsent || studWidthMm != null) {
      map['stud_width_mm'] = Variable<double>(studWidthMm);
    }
    if (!nullToAbsent || studClearGapMm != null) {
      map['stud_clear_gap_mm'] = Variable<double>(studClearGapMm);
    }
    if (!nullToAbsent || studLambda != null) {
      map['stud_lambda'] = Variable<double>(studLambda);
    }
    return map;
  }

  MaterialLayersCompanion toCompanion(bool nullToAbsent) {
    return MaterialLayersCompanion(
      id: Value(id),
      constructionId: Value(constructionId),
      sortOrder: Value(sortOrder),
      materialId: Value(materialId),
      thicknessMm: Value(thicknessMm),
      thermalConductivity: Value(thermalConductivity),
      density: Value(density),
      specificHeat: Value(specificHeat),
      studWidthMm: studWidthMm == null && nullToAbsent
          ? const Value.absent()
          : Value(studWidthMm),
      studClearGapMm: studClearGapMm == null && nullToAbsent
          ? const Value.absent()
          : Value(studClearGapMm),
      studLambda: studLambda == null && nullToAbsent
          ? const Value.absent()
          : Value(studLambda),
    );
  }

  factory MaterialLayer.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MaterialLayer(
      id: serializer.fromJson<String>(json['id']),
      constructionId: serializer.fromJson<String>(json['constructionId']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      materialId: serializer.fromJson<String>(json['materialId']),
      thicknessMm: serializer.fromJson<double>(json['thicknessMm']),
      thermalConductivity: serializer.fromJson<double>(
        json['thermalConductivity'],
      ),
      density: serializer.fromJson<double>(json['density']),
      specificHeat: serializer.fromJson<double>(json['specificHeat']),
      studWidthMm: serializer.fromJson<double?>(json['studWidthMm']),
      studClearGapMm: serializer.fromJson<double?>(json['studClearGapMm']),
      studLambda: serializer.fromJson<double?>(json['studLambda']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'constructionId': serializer.toJson<String>(constructionId),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'materialId': serializer.toJson<String>(materialId),
      'thicknessMm': serializer.toJson<double>(thicknessMm),
      'thermalConductivity': serializer.toJson<double>(thermalConductivity),
      'density': serializer.toJson<double>(density),
      'specificHeat': serializer.toJson<double>(specificHeat),
      'studWidthMm': serializer.toJson<double?>(studWidthMm),
      'studClearGapMm': serializer.toJson<double?>(studClearGapMm),
      'studLambda': serializer.toJson<double?>(studLambda),
    };
  }

  MaterialLayer copyWith({
    String? id,
    String? constructionId,
    int? sortOrder,
    String? materialId,
    double? thicknessMm,
    double? thermalConductivity,
    double? density,
    double? specificHeat,
    Value<double?> studWidthMm = const Value.absent(),
    Value<double?> studClearGapMm = const Value.absent(),
    Value<double?> studLambda = const Value.absent(),
  }) => MaterialLayer(
    id: id ?? this.id,
    constructionId: constructionId ?? this.constructionId,
    sortOrder: sortOrder ?? this.sortOrder,
    materialId: materialId ?? this.materialId,
    thicknessMm: thicknessMm ?? this.thicknessMm,
    thermalConductivity: thermalConductivity ?? this.thermalConductivity,
    density: density ?? this.density,
    specificHeat: specificHeat ?? this.specificHeat,
    studWidthMm: studWidthMm.present ? studWidthMm.value : this.studWidthMm,
    studClearGapMm: studClearGapMm.present
        ? studClearGapMm.value
        : this.studClearGapMm,
    studLambda: studLambda.present ? studLambda.value : this.studLambda,
  );
  MaterialLayer copyWithCompanion(MaterialLayersCompanion data) {
    return MaterialLayer(
      id: data.id.present ? data.id.value : this.id,
      constructionId: data.constructionId.present
          ? data.constructionId.value
          : this.constructionId,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      materialId: data.materialId.present
          ? data.materialId.value
          : this.materialId,
      thicknessMm: data.thicknessMm.present
          ? data.thicknessMm.value
          : this.thicknessMm,
      thermalConductivity: data.thermalConductivity.present
          ? data.thermalConductivity.value
          : this.thermalConductivity,
      density: data.density.present ? data.density.value : this.density,
      specificHeat: data.specificHeat.present
          ? data.specificHeat.value
          : this.specificHeat,
      studWidthMm: data.studWidthMm.present
          ? data.studWidthMm.value
          : this.studWidthMm,
      studClearGapMm: data.studClearGapMm.present
          ? data.studClearGapMm.value
          : this.studClearGapMm,
      studLambda: data.studLambda.present
          ? data.studLambda.value
          : this.studLambda,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MaterialLayer(')
          ..write('id: $id, ')
          ..write('constructionId: $constructionId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('materialId: $materialId, ')
          ..write('thicknessMm: $thicknessMm, ')
          ..write('thermalConductivity: $thermalConductivity, ')
          ..write('density: $density, ')
          ..write('specificHeat: $specificHeat, ')
          ..write('studWidthMm: $studWidthMm, ')
          ..write('studClearGapMm: $studClearGapMm, ')
          ..write('studLambda: $studLambda')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    constructionId,
    sortOrder,
    materialId,
    thicknessMm,
    thermalConductivity,
    density,
    specificHeat,
    studWidthMm,
    studClearGapMm,
    studLambda,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MaterialLayer &&
          other.id == this.id &&
          other.constructionId == this.constructionId &&
          other.sortOrder == this.sortOrder &&
          other.materialId == this.materialId &&
          other.thicknessMm == this.thicknessMm &&
          other.thermalConductivity == this.thermalConductivity &&
          other.density == this.density &&
          other.specificHeat == this.specificHeat &&
          other.studWidthMm == this.studWidthMm &&
          other.studClearGapMm == this.studClearGapMm &&
          other.studLambda == this.studLambda);
}

class MaterialLayersCompanion extends UpdateCompanion<MaterialLayer> {
  final Value<String> id;
  final Value<String> constructionId;
  final Value<int> sortOrder;
  final Value<String> materialId;
  final Value<double> thicknessMm;
  final Value<double> thermalConductivity;
  final Value<double> density;
  final Value<double> specificHeat;
  final Value<double?> studWidthMm;
  final Value<double?> studClearGapMm;
  final Value<double?> studLambda;
  final Value<int> rowid;
  const MaterialLayersCompanion({
    this.id = const Value.absent(),
    this.constructionId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.materialId = const Value.absent(),
    this.thicknessMm = const Value.absent(),
    this.thermalConductivity = const Value.absent(),
    this.density = const Value.absent(),
    this.specificHeat = const Value.absent(),
    this.studWidthMm = const Value.absent(),
    this.studClearGapMm = const Value.absent(),
    this.studLambda = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MaterialLayersCompanion.insert({
    required String id,
    required String constructionId,
    required int sortOrder,
    required String materialId,
    required double thicknessMm,
    required double thermalConductivity,
    required double density,
    required double specificHeat,
    this.studWidthMm = const Value.absent(),
    this.studClearGapMm = const Value.absent(),
    this.studLambda = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       constructionId = Value(constructionId),
       sortOrder = Value(sortOrder),
       materialId = Value(materialId),
       thicknessMm = Value(thicknessMm),
       thermalConductivity = Value(thermalConductivity),
       density = Value(density),
       specificHeat = Value(specificHeat);
  static Insertable<MaterialLayer> custom({
    Expression<String>? id,
    Expression<String>? constructionId,
    Expression<int>? sortOrder,
    Expression<String>? materialId,
    Expression<double>? thicknessMm,
    Expression<double>? thermalConductivity,
    Expression<double>? density,
    Expression<double>? specificHeat,
    Expression<double>? studWidthMm,
    Expression<double>? studClearGapMm,
    Expression<double>? studLambda,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (constructionId != null) 'construction_id': constructionId,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (materialId != null) 'material_id': materialId,
      if (thicknessMm != null) 'thickness_mm': thicknessMm,
      if (thermalConductivity != null)
        'thermal_conductivity': thermalConductivity,
      if (density != null) 'density': density,
      if (specificHeat != null) 'specific_heat': specificHeat,
      if (studWidthMm != null) 'stud_width_mm': studWidthMm,
      if (studClearGapMm != null) 'stud_clear_gap_mm': studClearGapMm,
      if (studLambda != null) 'stud_lambda': studLambda,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MaterialLayersCompanion copyWith({
    Value<String>? id,
    Value<String>? constructionId,
    Value<int>? sortOrder,
    Value<String>? materialId,
    Value<double>? thicknessMm,
    Value<double>? thermalConductivity,
    Value<double>? density,
    Value<double>? specificHeat,
    Value<double?>? studWidthMm,
    Value<double?>? studClearGapMm,
    Value<double?>? studLambda,
    Value<int>? rowid,
  }) {
    return MaterialLayersCompanion(
      id: id ?? this.id,
      constructionId: constructionId ?? this.constructionId,
      sortOrder: sortOrder ?? this.sortOrder,
      materialId: materialId ?? this.materialId,
      thicknessMm: thicknessMm ?? this.thicknessMm,
      thermalConductivity: thermalConductivity ?? this.thermalConductivity,
      density: density ?? this.density,
      specificHeat: specificHeat ?? this.specificHeat,
      studWidthMm: studWidthMm ?? this.studWidthMm,
      studClearGapMm: studClearGapMm ?? this.studClearGapMm,
      studLambda: studLambda ?? this.studLambda,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (constructionId.present) {
      map['construction_id'] = Variable<String>(constructionId.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (materialId.present) {
      map['material_id'] = Variable<String>(materialId.value);
    }
    if (thicknessMm.present) {
      map['thickness_mm'] = Variable<double>(thicknessMm.value);
    }
    if (thermalConductivity.present) {
      map['thermal_conductivity'] = Variable<double>(thermalConductivity.value);
    }
    if (density.present) {
      map['density'] = Variable<double>(density.value);
    }
    if (specificHeat.present) {
      map['specific_heat'] = Variable<double>(specificHeat.value);
    }
    if (studWidthMm.present) {
      map['stud_width_mm'] = Variable<double>(studWidthMm.value);
    }
    if (studClearGapMm.present) {
      map['stud_clear_gap_mm'] = Variable<double>(studClearGapMm.value);
    }
    if (studLambda.present) {
      map['stud_lambda'] = Variable<double>(studLambda.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MaterialLayersCompanion(')
          ..write('id: $id, ')
          ..write('constructionId: $constructionId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('materialId: $materialId, ')
          ..write('thicknessMm: $thicknessMm, ')
          ..write('thermalConductivity: $thermalConductivity, ')
          ..write('density: $density, ')
          ..write('specificHeat: $specificHeat, ')
          ..write('studWidthMm: $studWidthMm, ')
          ..write('studClearGapMm: $studClearGapMm, ')
          ..write('studLambda: $studLambda, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TubeTypesTable extends TubeTypes
    with TableInfo<$TubeTypesTable, TubeType> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TubeTypesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 100,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _materialMeta = const VerificationMeta(
    'material',
  );
  @override
  late final GeneratedColumn<String> material = GeneratedColumn<String>(
    'material',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _outerDiameterMmMeta = const VerificationMeta(
    'outerDiameterMm',
  );
  @override
  late final GeneratedColumn<double> outerDiameterMm = GeneratedColumn<double>(
    'outer_diameter_mm',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(16.0),
  );
  static const VerificationMeta _innerDiameterMmMeta = const VerificationMeta(
    'innerDiameterMm',
  );
  @override
  late final GeneratedColumn<double> innerDiameterMm = GeneratedColumn<double>(
    'inner_diameter_mm',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(13.0),
  );
  static const VerificationMeta _wallThicknessMmMeta = const VerificationMeta(
    'wallThicknessMm',
  );
  @override
  late final GeneratedColumn<double> wallThicknessMm = GeneratedColumn<double>(
    'wall_thickness_mm',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1.5),
  );
  static const VerificationMeta _thermalConductivityMeta =
      const VerificationMeta('thermalConductivity');
  @override
  late final GeneratedColumn<double> thermalConductivity =
      GeneratedColumn<double>(
        'thermal_conductivity',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
        defaultValue: const Constant(0.35),
      );
  static const VerificationMeta _roughnessMeta = const VerificationMeta(
    'roughness',
  );
  @override
  late final GeneratedColumn<double> roughness = GeneratedColumn<double>(
    'roughness',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.007),
  );
  static const VerificationMeta _maxOperatingTempCMeta = const VerificationMeta(
    'maxOperatingTempC',
  );
  @override
  late final GeneratedColumn<double> maxOperatingTempC =
      GeneratedColumn<double>(
        'max_operating_temp_c',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
        defaultValue: const Constant(60.0),
      );
  static const VerificationMeta _maxOperatingPressureMeta =
      const VerificationMeta('maxOperatingPressure');
  @override
  late final GeneratedColumn<double> maxOperatingPressure =
      GeneratedColumn<double>(
        'max_operating_pressure',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
        defaultValue: const Constant(6.0),
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    material,
    outerDiameterMm,
    innerDiameterMm,
    wallThicknessMm,
    thermalConductivity,
    roughness,
    maxOperatingTempC,
    maxOperatingPressure,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tube_types';
  @override
  VerificationContext validateIntegrity(
    Insertable<TubeType> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('material')) {
      context.handle(
        _materialMeta,
        material.isAcceptableOrUnknown(data['material']!, _materialMeta),
      );
    } else if (isInserting) {
      context.missing(_materialMeta);
    }
    if (data.containsKey('outer_diameter_mm')) {
      context.handle(
        _outerDiameterMmMeta,
        outerDiameterMm.isAcceptableOrUnknown(
          data['outer_diameter_mm']!,
          _outerDiameterMmMeta,
        ),
      );
    }
    if (data.containsKey('inner_diameter_mm')) {
      context.handle(
        _innerDiameterMmMeta,
        innerDiameterMm.isAcceptableOrUnknown(
          data['inner_diameter_mm']!,
          _innerDiameterMmMeta,
        ),
      );
    }
    if (data.containsKey('wall_thickness_mm')) {
      context.handle(
        _wallThicknessMmMeta,
        wallThicknessMm.isAcceptableOrUnknown(
          data['wall_thickness_mm']!,
          _wallThicknessMmMeta,
        ),
      );
    }
    if (data.containsKey('thermal_conductivity')) {
      context.handle(
        _thermalConductivityMeta,
        thermalConductivity.isAcceptableOrUnknown(
          data['thermal_conductivity']!,
          _thermalConductivityMeta,
        ),
      );
    }
    if (data.containsKey('roughness')) {
      context.handle(
        _roughnessMeta,
        roughness.isAcceptableOrUnknown(data['roughness']!, _roughnessMeta),
      );
    }
    if (data.containsKey('max_operating_temp_c')) {
      context.handle(
        _maxOperatingTempCMeta,
        maxOperatingTempC.isAcceptableOrUnknown(
          data['max_operating_temp_c']!,
          _maxOperatingTempCMeta,
        ),
      );
    }
    if (data.containsKey('max_operating_pressure')) {
      context.handle(
        _maxOperatingPressureMeta,
        maxOperatingPressure.isAcceptableOrUnknown(
          data['max_operating_pressure']!,
          _maxOperatingPressureMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TubeType map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TubeType(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      material: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}material'],
      )!,
      outerDiameterMm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}outer_diameter_mm'],
      )!,
      innerDiameterMm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}inner_diameter_mm'],
      )!,
      wallThicknessMm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}wall_thickness_mm'],
      )!,
      thermalConductivity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}thermal_conductivity'],
      )!,
      roughness: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}roughness'],
      )!,
      maxOperatingTempC: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}max_operating_temp_c'],
      )!,
      maxOperatingPressure: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}max_operating_pressure'],
      )!,
    );
  }

  @override
  $TubeTypesTable createAlias(String alias) {
    return $TubeTypesTable(attachedDatabase, alias);
  }
}

class TubeType extends DataClass implements Insertable<TubeType> {
  final String id;
  final String name;
  final String material;
  final double outerDiameterMm;
  final double innerDiameterMm;
  final double wallThicknessMm;
  final double thermalConductivity;
  final double roughness;
  final double maxOperatingTempC;
  final double maxOperatingPressure;
  const TubeType({
    required this.id,
    required this.name,
    required this.material,
    required this.outerDiameterMm,
    required this.innerDiameterMm,
    required this.wallThicknessMm,
    required this.thermalConductivity,
    required this.roughness,
    required this.maxOperatingTempC,
    required this.maxOperatingPressure,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['material'] = Variable<String>(material);
    map['outer_diameter_mm'] = Variable<double>(outerDiameterMm);
    map['inner_diameter_mm'] = Variable<double>(innerDiameterMm);
    map['wall_thickness_mm'] = Variable<double>(wallThicknessMm);
    map['thermal_conductivity'] = Variable<double>(thermalConductivity);
    map['roughness'] = Variable<double>(roughness);
    map['max_operating_temp_c'] = Variable<double>(maxOperatingTempC);
    map['max_operating_pressure'] = Variable<double>(maxOperatingPressure);
    return map;
  }

  TubeTypesCompanion toCompanion(bool nullToAbsent) {
    return TubeTypesCompanion(
      id: Value(id),
      name: Value(name),
      material: Value(material),
      outerDiameterMm: Value(outerDiameterMm),
      innerDiameterMm: Value(innerDiameterMm),
      wallThicknessMm: Value(wallThicknessMm),
      thermalConductivity: Value(thermalConductivity),
      roughness: Value(roughness),
      maxOperatingTempC: Value(maxOperatingTempC),
      maxOperatingPressure: Value(maxOperatingPressure),
    );
  }

  factory TubeType.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TubeType(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      material: serializer.fromJson<String>(json['material']),
      outerDiameterMm: serializer.fromJson<double>(json['outerDiameterMm']),
      innerDiameterMm: serializer.fromJson<double>(json['innerDiameterMm']),
      wallThicknessMm: serializer.fromJson<double>(json['wallThicknessMm']),
      thermalConductivity: serializer.fromJson<double>(
        json['thermalConductivity'],
      ),
      roughness: serializer.fromJson<double>(json['roughness']),
      maxOperatingTempC: serializer.fromJson<double>(json['maxOperatingTempC']),
      maxOperatingPressure: serializer.fromJson<double>(
        json['maxOperatingPressure'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'material': serializer.toJson<String>(material),
      'outerDiameterMm': serializer.toJson<double>(outerDiameterMm),
      'innerDiameterMm': serializer.toJson<double>(innerDiameterMm),
      'wallThicknessMm': serializer.toJson<double>(wallThicknessMm),
      'thermalConductivity': serializer.toJson<double>(thermalConductivity),
      'roughness': serializer.toJson<double>(roughness),
      'maxOperatingTempC': serializer.toJson<double>(maxOperatingTempC),
      'maxOperatingPressure': serializer.toJson<double>(maxOperatingPressure),
    };
  }

  TubeType copyWith({
    String? id,
    String? name,
    String? material,
    double? outerDiameterMm,
    double? innerDiameterMm,
    double? wallThicknessMm,
    double? thermalConductivity,
    double? roughness,
    double? maxOperatingTempC,
    double? maxOperatingPressure,
  }) => TubeType(
    id: id ?? this.id,
    name: name ?? this.name,
    material: material ?? this.material,
    outerDiameterMm: outerDiameterMm ?? this.outerDiameterMm,
    innerDiameterMm: innerDiameterMm ?? this.innerDiameterMm,
    wallThicknessMm: wallThicknessMm ?? this.wallThicknessMm,
    thermalConductivity: thermalConductivity ?? this.thermalConductivity,
    roughness: roughness ?? this.roughness,
    maxOperatingTempC: maxOperatingTempC ?? this.maxOperatingTempC,
    maxOperatingPressure: maxOperatingPressure ?? this.maxOperatingPressure,
  );
  TubeType copyWithCompanion(TubeTypesCompanion data) {
    return TubeType(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      material: data.material.present ? data.material.value : this.material,
      outerDiameterMm: data.outerDiameterMm.present
          ? data.outerDiameterMm.value
          : this.outerDiameterMm,
      innerDiameterMm: data.innerDiameterMm.present
          ? data.innerDiameterMm.value
          : this.innerDiameterMm,
      wallThicknessMm: data.wallThicknessMm.present
          ? data.wallThicknessMm.value
          : this.wallThicknessMm,
      thermalConductivity: data.thermalConductivity.present
          ? data.thermalConductivity.value
          : this.thermalConductivity,
      roughness: data.roughness.present ? data.roughness.value : this.roughness,
      maxOperatingTempC: data.maxOperatingTempC.present
          ? data.maxOperatingTempC.value
          : this.maxOperatingTempC,
      maxOperatingPressure: data.maxOperatingPressure.present
          ? data.maxOperatingPressure.value
          : this.maxOperatingPressure,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TubeType(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('material: $material, ')
          ..write('outerDiameterMm: $outerDiameterMm, ')
          ..write('innerDiameterMm: $innerDiameterMm, ')
          ..write('wallThicknessMm: $wallThicknessMm, ')
          ..write('thermalConductivity: $thermalConductivity, ')
          ..write('roughness: $roughness, ')
          ..write('maxOperatingTempC: $maxOperatingTempC, ')
          ..write('maxOperatingPressure: $maxOperatingPressure')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    material,
    outerDiameterMm,
    innerDiameterMm,
    wallThicknessMm,
    thermalConductivity,
    roughness,
    maxOperatingTempC,
    maxOperatingPressure,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TubeType &&
          other.id == this.id &&
          other.name == this.name &&
          other.material == this.material &&
          other.outerDiameterMm == this.outerDiameterMm &&
          other.innerDiameterMm == this.innerDiameterMm &&
          other.wallThicknessMm == this.wallThicknessMm &&
          other.thermalConductivity == this.thermalConductivity &&
          other.roughness == this.roughness &&
          other.maxOperatingTempC == this.maxOperatingTempC &&
          other.maxOperatingPressure == this.maxOperatingPressure);
}

class TubeTypesCompanion extends UpdateCompanion<TubeType> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> material;
  final Value<double> outerDiameterMm;
  final Value<double> innerDiameterMm;
  final Value<double> wallThicknessMm;
  final Value<double> thermalConductivity;
  final Value<double> roughness;
  final Value<double> maxOperatingTempC;
  final Value<double> maxOperatingPressure;
  final Value<int> rowid;
  const TubeTypesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.material = const Value.absent(),
    this.outerDiameterMm = const Value.absent(),
    this.innerDiameterMm = const Value.absent(),
    this.wallThicknessMm = const Value.absent(),
    this.thermalConductivity = const Value.absent(),
    this.roughness = const Value.absent(),
    this.maxOperatingTempC = const Value.absent(),
    this.maxOperatingPressure = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TubeTypesCompanion.insert({
    required String id,
    required String name,
    required String material,
    this.outerDiameterMm = const Value.absent(),
    this.innerDiameterMm = const Value.absent(),
    this.wallThicknessMm = const Value.absent(),
    this.thermalConductivity = const Value.absent(),
    this.roughness = const Value.absent(),
    this.maxOperatingTempC = const Value.absent(),
    this.maxOperatingPressure = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       material = Value(material);
  static Insertable<TubeType> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? material,
    Expression<double>? outerDiameterMm,
    Expression<double>? innerDiameterMm,
    Expression<double>? wallThicknessMm,
    Expression<double>? thermalConductivity,
    Expression<double>? roughness,
    Expression<double>? maxOperatingTempC,
    Expression<double>? maxOperatingPressure,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (material != null) 'material': material,
      if (outerDiameterMm != null) 'outer_diameter_mm': outerDiameterMm,
      if (innerDiameterMm != null) 'inner_diameter_mm': innerDiameterMm,
      if (wallThicknessMm != null) 'wall_thickness_mm': wallThicknessMm,
      if (thermalConductivity != null)
        'thermal_conductivity': thermalConductivity,
      if (roughness != null) 'roughness': roughness,
      if (maxOperatingTempC != null) 'max_operating_temp_c': maxOperatingTempC,
      if (maxOperatingPressure != null)
        'max_operating_pressure': maxOperatingPressure,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TubeTypesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? material,
    Value<double>? outerDiameterMm,
    Value<double>? innerDiameterMm,
    Value<double>? wallThicknessMm,
    Value<double>? thermalConductivity,
    Value<double>? roughness,
    Value<double>? maxOperatingTempC,
    Value<double>? maxOperatingPressure,
    Value<int>? rowid,
  }) {
    return TubeTypesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      material: material ?? this.material,
      outerDiameterMm: outerDiameterMm ?? this.outerDiameterMm,
      innerDiameterMm: innerDiameterMm ?? this.innerDiameterMm,
      wallThicknessMm: wallThicknessMm ?? this.wallThicknessMm,
      thermalConductivity: thermalConductivity ?? this.thermalConductivity,
      roughness: roughness ?? this.roughness,
      maxOperatingTempC: maxOperatingTempC ?? this.maxOperatingTempC,
      maxOperatingPressure: maxOperatingPressure ?? this.maxOperatingPressure,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (material.present) {
      map['material'] = Variable<String>(material.value);
    }
    if (outerDiameterMm.present) {
      map['outer_diameter_mm'] = Variable<double>(outerDiameterMm.value);
    }
    if (innerDiameterMm.present) {
      map['inner_diameter_mm'] = Variable<double>(innerDiameterMm.value);
    }
    if (wallThicknessMm.present) {
      map['wall_thickness_mm'] = Variable<double>(wallThicknessMm.value);
    }
    if (thermalConductivity.present) {
      map['thermal_conductivity'] = Variable<double>(thermalConductivity.value);
    }
    if (roughness.present) {
      map['roughness'] = Variable<double>(roughness.value);
    }
    if (maxOperatingTempC.present) {
      map['max_operating_temp_c'] = Variable<double>(maxOperatingTempC.value);
    }
    if (maxOperatingPressure.present) {
      map['max_operating_pressure'] = Variable<double>(
        maxOperatingPressure.value,
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TubeTypesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('material: $material, ')
          ..write('outerDiameterMm: $outerDiameterMm, ')
          ..write('innerDiameterMm: $innerDiameterMm, ')
          ..write('wallThicknessMm: $wallThicknessMm, ')
          ..write('thermalConductivity: $thermalConductivity, ')
          ..write('roughness: $roughness, ')
          ..write('maxOperatingTempC: $maxOperatingTempC, ')
          ..write('maxOperatingPressure: $maxOperatingPressure, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FlooringMaterialsTable extends FlooringMaterials
    with TableInfo<$FlooringMaterialsTable, FlooringMaterial> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FlooringMaterialsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 200,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _thermalResistanceMeta = const VerificationMeta(
    'thermalResistance',
  );
  @override
  late final GeneratedColumn<double> thermalResistance =
      GeneratedColumn<double>(
        'thermal_resistance',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _surfaceTypeMeta = const VerificationMeta(
    'surfaceType',
  );
  @override
  late final GeneratedColumn<String> surfaceType = GeneratedColumn<String>(
    'surface_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('floor'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    thermalResistance,
    surfaceType,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'flooring_materials';
  @override
  VerificationContext validateIntegrity(
    Insertable<FlooringMaterial> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('thermal_resistance')) {
      context.handle(
        _thermalResistanceMeta,
        thermalResistance.isAcceptableOrUnknown(
          data['thermal_resistance']!,
          _thermalResistanceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_thermalResistanceMeta);
    }
    if (data.containsKey('surface_type')) {
      context.handle(
        _surfaceTypeMeta,
        surfaceType.isAcceptableOrUnknown(
          data['surface_type']!,
          _surfaceTypeMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FlooringMaterial map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FlooringMaterial(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      thermalResistance: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}thermal_resistance'],
      )!,
      surfaceType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}surface_type'],
      )!,
    );
  }

  @override
  $FlooringMaterialsTable createAlias(String alias) {
    return $FlooringMaterialsTable(attachedDatabase, alias);
  }
}

class FlooringMaterial extends DataClass
    implements Insertable<FlooringMaterial> {
  final String id;
  final String name;
  final double thermalResistance;

  /// Serialised [SurfaceType] name; defaults to 'floor' for existing rows.
  final String surfaceType;
  const FlooringMaterial({
    required this.id,
    required this.name,
    required this.thermalResistance,
    required this.surfaceType,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['thermal_resistance'] = Variable<double>(thermalResistance);
    map['surface_type'] = Variable<String>(surfaceType);
    return map;
  }

  FlooringMaterialsCompanion toCompanion(bool nullToAbsent) {
    return FlooringMaterialsCompanion(
      id: Value(id),
      name: Value(name),
      thermalResistance: Value(thermalResistance),
      surfaceType: Value(surfaceType),
    );
  }

  factory FlooringMaterial.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FlooringMaterial(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      thermalResistance: serializer.fromJson<double>(json['thermalResistance']),
      surfaceType: serializer.fromJson<String>(json['surfaceType']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'thermalResistance': serializer.toJson<double>(thermalResistance),
      'surfaceType': serializer.toJson<String>(surfaceType),
    };
  }

  FlooringMaterial copyWith({
    String? id,
    String? name,
    double? thermalResistance,
    String? surfaceType,
  }) => FlooringMaterial(
    id: id ?? this.id,
    name: name ?? this.name,
    thermalResistance: thermalResistance ?? this.thermalResistance,
    surfaceType: surfaceType ?? this.surfaceType,
  );
  FlooringMaterial copyWithCompanion(FlooringMaterialsCompanion data) {
    return FlooringMaterial(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      thermalResistance: data.thermalResistance.present
          ? data.thermalResistance.value
          : this.thermalResistance,
      surfaceType: data.surfaceType.present
          ? data.surfaceType.value
          : this.surfaceType,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FlooringMaterial(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('thermalResistance: $thermalResistance, ')
          ..write('surfaceType: $surfaceType')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, thermalResistance, surfaceType);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FlooringMaterial &&
          other.id == this.id &&
          other.name == this.name &&
          other.thermalResistance == this.thermalResistance &&
          other.surfaceType == this.surfaceType);
}

class FlooringMaterialsCompanion extends UpdateCompanion<FlooringMaterial> {
  final Value<String> id;
  final Value<String> name;
  final Value<double> thermalResistance;
  final Value<String> surfaceType;
  final Value<int> rowid;
  const FlooringMaterialsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.thermalResistance = const Value.absent(),
    this.surfaceType = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FlooringMaterialsCompanion.insert({
    required String id,
    required String name,
    required double thermalResistance,
    this.surfaceType = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       thermalResistance = Value(thermalResistance);
  static Insertable<FlooringMaterial> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<double>? thermalResistance,
    Expression<String>? surfaceType,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (thermalResistance != null) 'thermal_resistance': thermalResistance,
      if (surfaceType != null) 'surface_type': surfaceType,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FlooringMaterialsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<double>? thermalResistance,
    Value<String>? surfaceType,
    Value<int>? rowid,
  }) {
    return FlooringMaterialsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      thermalResistance: thermalResistance ?? this.thermalResistance,
      surfaceType: surfaceType ?? this.surfaceType,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (thermalResistance.present) {
      map['thermal_resistance'] = Variable<double>(thermalResistance.value);
    }
    if (surfaceType.present) {
      map['surface_type'] = Variable<String>(surfaceType.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FlooringMaterialsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('thermalResistance: $thermalResistance, ')
          ..write('surfaceType: $surfaceType, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HeatingZonesTable extends HeatingZones
    with TableInfo<$HeatingZonesTable, HeatingZone> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HeatingZonesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roomIdMeta = const VerificationMeta('roomId');
  @override
  late final GeneratedColumn<String> roomId = GeneratedColumn<String>(
    'room_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES rooms (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _zoneTypeMeta = const VerificationMeta(
    'zoneType',
  );
  @override
  late final GeneratedColumn<String> zoneType = GeneratedColumn<String>(
    'zone_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('floorHeating'),
  );
  static const VerificationMeta _polygonJsonMeta = const VerificationMeta(
    'polygonJson',
  );
  @override
  late final GeneratedColumn<String> polygonJson = GeneratedColumn<String>(
    'polygon_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _tubeSpacingMmMeta = const VerificationMeta(
    'tubeSpacingMm',
  );
  @override
  late final GeneratedColumn<int> tubeSpacingMm = GeneratedColumn<int>(
    'tube_spacing_mm',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(150),
  );
  static const VerificationMeta _tubeTypeIdMeta = const VerificationMeta(
    'tubeTypeId',
  );
  @override
  late final GeneratedColumn<String> tubeTypeId = GeneratedColumn<String>(
    'tube_type_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tube_types (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _flooringMaterialIdMeta =
      const VerificationMeta('flooringMaterialId');
  @override
  late final GeneratedColumn<String> flooringMaterialId =
      GeneratedColumn<String>(
        'flooring_material_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES flooring_materials (id) ON DELETE RESTRICT',
        ),
      );
  static const VerificationMeta _borderDistanceMmMeta = const VerificationMeta(
    'borderDistanceMm',
  );
  @override
  late final GeneratedColumn<int> borderDistanceMm = GeneratedColumn<int>(
    'border_distance_mm',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(100),
  );
  static const VerificationMeta _layoutPatternMeta = const VerificationMeta(
    'layoutPattern',
  );
  @override
  late final GeneratedColumn<String> layoutPattern = GeneratedColumn<String>(
    'layout_pattern',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('meander'),
  );
  static const VerificationMeta _circuitIdMeta = const VerificationMeta(
    'circuitId',
  );
  @override
  late final GeneratedColumn<String> circuitId = GeneratedColumn<String>(
    'circuit_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _wallSegmentIdMeta = const VerificationMeta(
    'wallSegmentId',
  );
  @override
  late final GeneratedColumn<String> wallSegmentId = GeneratedColumn<String>(
    'wall_segment_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES wall_segments (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _heightMmMeta = const VerificationMeta(
    'heightMm',
  );
  @override
  late final GeneratedColumn<int> heightMm = GeneratedColumn<int>(
    'height_mm',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _positionOnWallMmMeta = const VerificationMeta(
    'positionOnWallMm',
  );
  @override
  late final GeneratedColumn<double> positionOnWallMm = GeneratedColumn<double>(
    'position_on_wall_mm',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _widthMmMeta = const VerificationMeta(
    'widthMm',
  );
  @override
  late final GeneratedColumn<int> widthMm = GeneratedColumn<int>(
    'width_mm',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _customFlooringResistanceMeta =
      const VerificationMeta('customFlooringResistance');
  @override
  late final GeneratedColumn<double> customFlooringResistance =
      GeneratedColumn<double>(
        'custom_flooring_resistance',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    roomId,
    zoneType,
    polygonJson,
    tubeSpacingMm,
    tubeTypeId,
    flooringMaterialId,
    borderDistanceMm,
    layoutPattern,
    circuitId,
    wallSegmentId,
    heightMm,
    positionOnWallMm,
    widthMm,
    customFlooringResistance,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'heating_zones';
  @override
  VerificationContext validateIntegrity(
    Insertable<HeatingZone> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('room_id')) {
      context.handle(
        _roomIdMeta,
        roomId.isAcceptableOrUnknown(data['room_id']!, _roomIdMeta),
      );
    } else if (isInserting) {
      context.missing(_roomIdMeta);
    }
    if (data.containsKey('zone_type')) {
      context.handle(
        _zoneTypeMeta,
        zoneType.isAcceptableOrUnknown(data['zone_type']!, _zoneTypeMeta),
      );
    }
    if (data.containsKey('polygon_json')) {
      context.handle(
        _polygonJsonMeta,
        polygonJson.isAcceptableOrUnknown(
          data['polygon_json']!,
          _polygonJsonMeta,
        ),
      );
    }
    if (data.containsKey('tube_spacing_mm')) {
      context.handle(
        _tubeSpacingMmMeta,
        tubeSpacingMm.isAcceptableOrUnknown(
          data['tube_spacing_mm']!,
          _tubeSpacingMmMeta,
        ),
      );
    }
    if (data.containsKey('tube_type_id')) {
      context.handle(
        _tubeTypeIdMeta,
        tubeTypeId.isAcceptableOrUnknown(
          data['tube_type_id']!,
          _tubeTypeIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_tubeTypeIdMeta);
    }
    if (data.containsKey('flooring_material_id')) {
      context.handle(
        _flooringMaterialIdMeta,
        flooringMaterialId.isAcceptableOrUnknown(
          data['flooring_material_id']!,
          _flooringMaterialIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_flooringMaterialIdMeta);
    }
    if (data.containsKey('border_distance_mm')) {
      context.handle(
        _borderDistanceMmMeta,
        borderDistanceMm.isAcceptableOrUnknown(
          data['border_distance_mm']!,
          _borderDistanceMmMeta,
        ),
      );
    }
    if (data.containsKey('layout_pattern')) {
      context.handle(
        _layoutPatternMeta,
        layoutPattern.isAcceptableOrUnknown(
          data['layout_pattern']!,
          _layoutPatternMeta,
        ),
      );
    }
    if (data.containsKey('circuit_id')) {
      context.handle(
        _circuitIdMeta,
        circuitId.isAcceptableOrUnknown(data['circuit_id']!, _circuitIdMeta),
      );
    }
    if (data.containsKey('wall_segment_id')) {
      context.handle(
        _wallSegmentIdMeta,
        wallSegmentId.isAcceptableOrUnknown(
          data['wall_segment_id']!,
          _wallSegmentIdMeta,
        ),
      );
    }
    if (data.containsKey('height_mm')) {
      context.handle(
        _heightMmMeta,
        heightMm.isAcceptableOrUnknown(data['height_mm']!, _heightMmMeta),
      );
    }
    if (data.containsKey('position_on_wall_mm')) {
      context.handle(
        _positionOnWallMmMeta,
        positionOnWallMm.isAcceptableOrUnknown(
          data['position_on_wall_mm']!,
          _positionOnWallMmMeta,
        ),
      );
    }
    if (data.containsKey('width_mm')) {
      context.handle(
        _widthMmMeta,
        widthMm.isAcceptableOrUnknown(data['width_mm']!, _widthMmMeta),
      );
    }
    if (data.containsKey('custom_flooring_resistance')) {
      context.handle(
        _customFlooringResistanceMeta,
        customFlooringResistance.isAcceptableOrUnknown(
          data['custom_flooring_resistance']!,
          _customFlooringResistanceMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HeatingZone map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HeatingZone(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      roomId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}room_id'],
      )!,
      zoneType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}zone_type'],
      )!,
      polygonJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}polygon_json'],
      )!,
      tubeSpacingMm: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tube_spacing_mm'],
      )!,
      tubeTypeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tube_type_id'],
      )!,
      flooringMaterialId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}flooring_material_id'],
      )!,
      borderDistanceMm: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}border_distance_mm'],
      )!,
      layoutPattern: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}layout_pattern'],
      )!,
      circuitId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}circuit_id'],
      ),
      wallSegmentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}wall_segment_id'],
      ),
      heightMm: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}height_mm'],
      ),
      positionOnWallMm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}position_on_wall_mm'],
      ),
      widthMm: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}width_mm'],
      ),
      customFlooringResistance: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}custom_flooring_resistance'],
      ),
    );
  }

  @override
  $HeatingZonesTable createAlias(String alias) {
    return $HeatingZonesTable(attachedDatabase, alias);
  }
}

class HeatingZone extends DataClass implements Insertable<HeatingZone> {
  final String id;
  final String roomId;
  final String zoneType;

  /// JSON array of {x, y} objects for the zone polygon in mm.
  final String polygonJson;
  final int tubeSpacingMm;
  final String tubeTypeId;
  final String flooringMaterialId;
  final int borderDistanceMm;
  final String layoutPattern;
  final String? circuitId;

  /// UUID of the host [WallSegment]; null for floor-heating zones.
  final String? wallSegmentId;

  /// Height of the wall heating zone in mm; null for floor-heating zones.
  final int? heightMm;

  /// Offset from wall start to zone left edge in mm; null for floor zones.
  final double? positionOnWallMm;

  /// Length of the zone along the wall in mm; null means full wall length.
  final int? widthMm;

  /// User-specified surface covering resistance in m²·K/W.
  ///
  /// Only used when [flooringMaterialId] is the custom sentinel.
  /// Null until set by the user.
  final double? customFlooringResistance;
  const HeatingZone({
    required this.id,
    required this.roomId,
    required this.zoneType,
    required this.polygonJson,
    required this.tubeSpacingMm,
    required this.tubeTypeId,
    required this.flooringMaterialId,
    required this.borderDistanceMm,
    required this.layoutPattern,
    this.circuitId,
    this.wallSegmentId,
    this.heightMm,
    this.positionOnWallMm,
    this.widthMm,
    this.customFlooringResistance,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['room_id'] = Variable<String>(roomId);
    map['zone_type'] = Variable<String>(zoneType);
    map['polygon_json'] = Variable<String>(polygonJson);
    map['tube_spacing_mm'] = Variable<int>(tubeSpacingMm);
    map['tube_type_id'] = Variable<String>(tubeTypeId);
    map['flooring_material_id'] = Variable<String>(flooringMaterialId);
    map['border_distance_mm'] = Variable<int>(borderDistanceMm);
    map['layout_pattern'] = Variable<String>(layoutPattern);
    if (!nullToAbsent || circuitId != null) {
      map['circuit_id'] = Variable<String>(circuitId);
    }
    if (!nullToAbsent || wallSegmentId != null) {
      map['wall_segment_id'] = Variable<String>(wallSegmentId);
    }
    if (!nullToAbsent || heightMm != null) {
      map['height_mm'] = Variable<int>(heightMm);
    }
    if (!nullToAbsent || positionOnWallMm != null) {
      map['position_on_wall_mm'] = Variable<double>(positionOnWallMm);
    }
    if (!nullToAbsent || widthMm != null) {
      map['width_mm'] = Variable<int>(widthMm);
    }
    if (!nullToAbsent || customFlooringResistance != null) {
      map['custom_flooring_resistance'] = Variable<double>(
        customFlooringResistance,
      );
    }
    return map;
  }

  HeatingZonesCompanion toCompanion(bool nullToAbsent) {
    return HeatingZonesCompanion(
      id: Value(id),
      roomId: Value(roomId),
      zoneType: Value(zoneType),
      polygonJson: Value(polygonJson),
      tubeSpacingMm: Value(tubeSpacingMm),
      tubeTypeId: Value(tubeTypeId),
      flooringMaterialId: Value(flooringMaterialId),
      borderDistanceMm: Value(borderDistanceMm),
      layoutPattern: Value(layoutPattern),
      circuitId: circuitId == null && nullToAbsent
          ? const Value.absent()
          : Value(circuitId),
      wallSegmentId: wallSegmentId == null && nullToAbsent
          ? const Value.absent()
          : Value(wallSegmentId),
      heightMm: heightMm == null && nullToAbsent
          ? const Value.absent()
          : Value(heightMm),
      positionOnWallMm: positionOnWallMm == null && nullToAbsent
          ? const Value.absent()
          : Value(positionOnWallMm),
      widthMm: widthMm == null && nullToAbsent
          ? const Value.absent()
          : Value(widthMm),
      customFlooringResistance: customFlooringResistance == null && nullToAbsent
          ? const Value.absent()
          : Value(customFlooringResistance),
    );
  }

  factory HeatingZone.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HeatingZone(
      id: serializer.fromJson<String>(json['id']),
      roomId: serializer.fromJson<String>(json['roomId']),
      zoneType: serializer.fromJson<String>(json['zoneType']),
      polygonJson: serializer.fromJson<String>(json['polygonJson']),
      tubeSpacingMm: serializer.fromJson<int>(json['tubeSpacingMm']),
      tubeTypeId: serializer.fromJson<String>(json['tubeTypeId']),
      flooringMaterialId: serializer.fromJson<String>(
        json['flooringMaterialId'],
      ),
      borderDistanceMm: serializer.fromJson<int>(json['borderDistanceMm']),
      layoutPattern: serializer.fromJson<String>(json['layoutPattern']),
      circuitId: serializer.fromJson<String?>(json['circuitId']),
      wallSegmentId: serializer.fromJson<String?>(json['wallSegmentId']),
      heightMm: serializer.fromJson<int?>(json['heightMm']),
      positionOnWallMm: serializer.fromJson<double?>(json['positionOnWallMm']),
      widthMm: serializer.fromJson<int?>(json['widthMm']),
      customFlooringResistance: serializer.fromJson<double?>(
        json['customFlooringResistance'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'roomId': serializer.toJson<String>(roomId),
      'zoneType': serializer.toJson<String>(zoneType),
      'polygonJson': serializer.toJson<String>(polygonJson),
      'tubeSpacingMm': serializer.toJson<int>(tubeSpacingMm),
      'tubeTypeId': serializer.toJson<String>(tubeTypeId),
      'flooringMaterialId': serializer.toJson<String>(flooringMaterialId),
      'borderDistanceMm': serializer.toJson<int>(borderDistanceMm),
      'layoutPattern': serializer.toJson<String>(layoutPattern),
      'circuitId': serializer.toJson<String?>(circuitId),
      'wallSegmentId': serializer.toJson<String?>(wallSegmentId),
      'heightMm': serializer.toJson<int?>(heightMm),
      'positionOnWallMm': serializer.toJson<double?>(positionOnWallMm),
      'widthMm': serializer.toJson<int?>(widthMm),
      'customFlooringResistance': serializer.toJson<double?>(
        customFlooringResistance,
      ),
    };
  }

  HeatingZone copyWith({
    String? id,
    String? roomId,
    String? zoneType,
    String? polygonJson,
    int? tubeSpacingMm,
    String? tubeTypeId,
    String? flooringMaterialId,
    int? borderDistanceMm,
    String? layoutPattern,
    Value<String?> circuitId = const Value.absent(),
    Value<String?> wallSegmentId = const Value.absent(),
    Value<int?> heightMm = const Value.absent(),
    Value<double?> positionOnWallMm = const Value.absent(),
    Value<int?> widthMm = const Value.absent(),
    Value<double?> customFlooringResistance = const Value.absent(),
  }) => HeatingZone(
    id: id ?? this.id,
    roomId: roomId ?? this.roomId,
    zoneType: zoneType ?? this.zoneType,
    polygonJson: polygonJson ?? this.polygonJson,
    tubeSpacingMm: tubeSpacingMm ?? this.tubeSpacingMm,
    tubeTypeId: tubeTypeId ?? this.tubeTypeId,
    flooringMaterialId: flooringMaterialId ?? this.flooringMaterialId,
    borderDistanceMm: borderDistanceMm ?? this.borderDistanceMm,
    layoutPattern: layoutPattern ?? this.layoutPattern,
    circuitId: circuitId.present ? circuitId.value : this.circuitId,
    wallSegmentId: wallSegmentId.present
        ? wallSegmentId.value
        : this.wallSegmentId,
    heightMm: heightMm.present ? heightMm.value : this.heightMm,
    positionOnWallMm: positionOnWallMm.present
        ? positionOnWallMm.value
        : this.positionOnWallMm,
    widthMm: widthMm.present ? widthMm.value : this.widthMm,
    customFlooringResistance: customFlooringResistance.present
        ? customFlooringResistance.value
        : this.customFlooringResistance,
  );
  HeatingZone copyWithCompanion(HeatingZonesCompanion data) {
    return HeatingZone(
      id: data.id.present ? data.id.value : this.id,
      roomId: data.roomId.present ? data.roomId.value : this.roomId,
      zoneType: data.zoneType.present ? data.zoneType.value : this.zoneType,
      polygonJson: data.polygonJson.present
          ? data.polygonJson.value
          : this.polygonJson,
      tubeSpacingMm: data.tubeSpacingMm.present
          ? data.tubeSpacingMm.value
          : this.tubeSpacingMm,
      tubeTypeId: data.tubeTypeId.present
          ? data.tubeTypeId.value
          : this.tubeTypeId,
      flooringMaterialId: data.flooringMaterialId.present
          ? data.flooringMaterialId.value
          : this.flooringMaterialId,
      borderDistanceMm: data.borderDistanceMm.present
          ? data.borderDistanceMm.value
          : this.borderDistanceMm,
      layoutPattern: data.layoutPattern.present
          ? data.layoutPattern.value
          : this.layoutPattern,
      circuitId: data.circuitId.present ? data.circuitId.value : this.circuitId,
      wallSegmentId: data.wallSegmentId.present
          ? data.wallSegmentId.value
          : this.wallSegmentId,
      heightMm: data.heightMm.present ? data.heightMm.value : this.heightMm,
      positionOnWallMm: data.positionOnWallMm.present
          ? data.positionOnWallMm.value
          : this.positionOnWallMm,
      widthMm: data.widthMm.present ? data.widthMm.value : this.widthMm,
      customFlooringResistance: data.customFlooringResistance.present
          ? data.customFlooringResistance.value
          : this.customFlooringResistance,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HeatingZone(')
          ..write('id: $id, ')
          ..write('roomId: $roomId, ')
          ..write('zoneType: $zoneType, ')
          ..write('polygonJson: $polygonJson, ')
          ..write('tubeSpacingMm: $tubeSpacingMm, ')
          ..write('tubeTypeId: $tubeTypeId, ')
          ..write('flooringMaterialId: $flooringMaterialId, ')
          ..write('borderDistanceMm: $borderDistanceMm, ')
          ..write('layoutPattern: $layoutPattern, ')
          ..write('circuitId: $circuitId, ')
          ..write('wallSegmentId: $wallSegmentId, ')
          ..write('heightMm: $heightMm, ')
          ..write('positionOnWallMm: $positionOnWallMm, ')
          ..write('widthMm: $widthMm, ')
          ..write('customFlooringResistance: $customFlooringResistance')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    roomId,
    zoneType,
    polygonJson,
    tubeSpacingMm,
    tubeTypeId,
    flooringMaterialId,
    borderDistanceMm,
    layoutPattern,
    circuitId,
    wallSegmentId,
    heightMm,
    positionOnWallMm,
    widthMm,
    customFlooringResistance,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HeatingZone &&
          other.id == this.id &&
          other.roomId == this.roomId &&
          other.zoneType == this.zoneType &&
          other.polygonJson == this.polygonJson &&
          other.tubeSpacingMm == this.tubeSpacingMm &&
          other.tubeTypeId == this.tubeTypeId &&
          other.flooringMaterialId == this.flooringMaterialId &&
          other.borderDistanceMm == this.borderDistanceMm &&
          other.layoutPattern == this.layoutPattern &&
          other.circuitId == this.circuitId &&
          other.wallSegmentId == this.wallSegmentId &&
          other.heightMm == this.heightMm &&
          other.positionOnWallMm == this.positionOnWallMm &&
          other.widthMm == this.widthMm &&
          other.customFlooringResistance == this.customFlooringResistance);
}

class HeatingZonesCompanion extends UpdateCompanion<HeatingZone> {
  final Value<String> id;
  final Value<String> roomId;
  final Value<String> zoneType;
  final Value<String> polygonJson;
  final Value<int> tubeSpacingMm;
  final Value<String> tubeTypeId;
  final Value<String> flooringMaterialId;
  final Value<int> borderDistanceMm;
  final Value<String> layoutPattern;
  final Value<String?> circuitId;
  final Value<String?> wallSegmentId;
  final Value<int?> heightMm;
  final Value<double?> positionOnWallMm;
  final Value<int?> widthMm;
  final Value<double?> customFlooringResistance;
  final Value<int> rowid;
  const HeatingZonesCompanion({
    this.id = const Value.absent(),
    this.roomId = const Value.absent(),
    this.zoneType = const Value.absent(),
    this.polygonJson = const Value.absent(),
    this.tubeSpacingMm = const Value.absent(),
    this.tubeTypeId = const Value.absent(),
    this.flooringMaterialId = const Value.absent(),
    this.borderDistanceMm = const Value.absent(),
    this.layoutPattern = const Value.absent(),
    this.circuitId = const Value.absent(),
    this.wallSegmentId = const Value.absent(),
    this.heightMm = const Value.absent(),
    this.positionOnWallMm = const Value.absent(),
    this.widthMm = const Value.absent(),
    this.customFlooringResistance = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HeatingZonesCompanion.insert({
    required String id,
    required String roomId,
    this.zoneType = const Value.absent(),
    this.polygonJson = const Value.absent(),
    this.tubeSpacingMm = const Value.absent(),
    required String tubeTypeId,
    required String flooringMaterialId,
    this.borderDistanceMm = const Value.absent(),
    this.layoutPattern = const Value.absent(),
    this.circuitId = const Value.absent(),
    this.wallSegmentId = const Value.absent(),
    this.heightMm = const Value.absent(),
    this.positionOnWallMm = const Value.absent(),
    this.widthMm = const Value.absent(),
    this.customFlooringResistance = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       roomId = Value(roomId),
       tubeTypeId = Value(tubeTypeId),
       flooringMaterialId = Value(flooringMaterialId);
  static Insertable<HeatingZone> custom({
    Expression<String>? id,
    Expression<String>? roomId,
    Expression<String>? zoneType,
    Expression<String>? polygonJson,
    Expression<int>? tubeSpacingMm,
    Expression<String>? tubeTypeId,
    Expression<String>? flooringMaterialId,
    Expression<int>? borderDistanceMm,
    Expression<String>? layoutPattern,
    Expression<String>? circuitId,
    Expression<String>? wallSegmentId,
    Expression<int>? heightMm,
    Expression<double>? positionOnWallMm,
    Expression<int>? widthMm,
    Expression<double>? customFlooringResistance,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (roomId != null) 'room_id': roomId,
      if (zoneType != null) 'zone_type': zoneType,
      if (polygonJson != null) 'polygon_json': polygonJson,
      if (tubeSpacingMm != null) 'tube_spacing_mm': tubeSpacingMm,
      if (tubeTypeId != null) 'tube_type_id': tubeTypeId,
      if (flooringMaterialId != null)
        'flooring_material_id': flooringMaterialId,
      if (borderDistanceMm != null) 'border_distance_mm': borderDistanceMm,
      if (layoutPattern != null) 'layout_pattern': layoutPattern,
      if (circuitId != null) 'circuit_id': circuitId,
      if (wallSegmentId != null) 'wall_segment_id': wallSegmentId,
      if (heightMm != null) 'height_mm': heightMm,
      if (positionOnWallMm != null) 'position_on_wall_mm': positionOnWallMm,
      if (widthMm != null) 'width_mm': widthMm,
      if (customFlooringResistance != null)
        'custom_flooring_resistance': customFlooringResistance,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HeatingZonesCompanion copyWith({
    Value<String>? id,
    Value<String>? roomId,
    Value<String>? zoneType,
    Value<String>? polygonJson,
    Value<int>? tubeSpacingMm,
    Value<String>? tubeTypeId,
    Value<String>? flooringMaterialId,
    Value<int>? borderDistanceMm,
    Value<String>? layoutPattern,
    Value<String?>? circuitId,
    Value<String?>? wallSegmentId,
    Value<int?>? heightMm,
    Value<double?>? positionOnWallMm,
    Value<int?>? widthMm,
    Value<double?>? customFlooringResistance,
    Value<int>? rowid,
  }) {
    return HeatingZonesCompanion(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      zoneType: zoneType ?? this.zoneType,
      polygonJson: polygonJson ?? this.polygonJson,
      tubeSpacingMm: tubeSpacingMm ?? this.tubeSpacingMm,
      tubeTypeId: tubeTypeId ?? this.tubeTypeId,
      flooringMaterialId: flooringMaterialId ?? this.flooringMaterialId,
      borderDistanceMm: borderDistanceMm ?? this.borderDistanceMm,
      layoutPattern: layoutPattern ?? this.layoutPattern,
      circuitId: circuitId ?? this.circuitId,
      wallSegmentId: wallSegmentId ?? this.wallSegmentId,
      heightMm: heightMm ?? this.heightMm,
      positionOnWallMm: positionOnWallMm ?? this.positionOnWallMm,
      widthMm: widthMm ?? this.widthMm,
      customFlooringResistance:
          customFlooringResistance ?? this.customFlooringResistance,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (roomId.present) {
      map['room_id'] = Variable<String>(roomId.value);
    }
    if (zoneType.present) {
      map['zone_type'] = Variable<String>(zoneType.value);
    }
    if (polygonJson.present) {
      map['polygon_json'] = Variable<String>(polygonJson.value);
    }
    if (tubeSpacingMm.present) {
      map['tube_spacing_mm'] = Variable<int>(tubeSpacingMm.value);
    }
    if (tubeTypeId.present) {
      map['tube_type_id'] = Variable<String>(tubeTypeId.value);
    }
    if (flooringMaterialId.present) {
      map['flooring_material_id'] = Variable<String>(flooringMaterialId.value);
    }
    if (borderDistanceMm.present) {
      map['border_distance_mm'] = Variable<int>(borderDistanceMm.value);
    }
    if (layoutPattern.present) {
      map['layout_pattern'] = Variable<String>(layoutPattern.value);
    }
    if (circuitId.present) {
      map['circuit_id'] = Variable<String>(circuitId.value);
    }
    if (wallSegmentId.present) {
      map['wall_segment_id'] = Variable<String>(wallSegmentId.value);
    }
    if (heightMm.present) {
      map['height_mm'] = Variable<int>(heightMm.value);
    }
    if (positionOnWallMm.present) {
      map['position_on_wall_mm'] = Variable<double>(positionOnWallMm.value);
    }
    if (widthMm.present) {
      map['width_mm'] = Variable<int>(widthMm.value);
    }
    if (customFlooringResistance.present) {
      map['custom_flooring_resistance'] = Variable<double>(
        customFlooringResistance.value,
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HeatingZonesCompanion(')
          ..write('id: $id, ')
          ..write('roomId: $roomId, ')
          ..write('zoneType: $zoneType, ')
          ..write('polygonJson: $polygonJson, ')
          ..write('tubeSpacingMm: $tubeSpacingMm, ')
          ..write('tubeTypeId: $tubeTypeId, ')
          ..write('flooringMaterialId: $flooringMaterialId, ')
          ..write('borderDistanceMm: $borderDistanceMm, ')
          ..write('layoutPattern: $layoutPattern, ')
          ..write('circuitId: $circuitId, ')
          ..write('wallSegmentId: $wallSegmentId, ')
          ..write('heightMm: $heightMm, ')
          ..write('positionOnWallMm: $positionOnWallMm, ')
          ..write('widthMm: $widthMm, ')
          ..write('customFlooringResistance: $customFlooringResistance, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DistributorsTable extends Distributors
    with TableInfo<$DistributorsTable, Distributor> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DistributorsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _floorIdMeta = const VerificationMeta(
    'floorId',
  );
  @override
  late final GeneratedColumn<String> floorId = GeneratedColumn<String>(
    'floor_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES floors (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _positionJsonMeta = const VerificationMeta(
    'positionJson',
  );
  @override
  late final GeneratedColumn<String> positionJson = GeneratedColumn<String>(
    'position_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _supplyTempCMeta = const VerificationMeta(
    'supplyTempC',
  );
  @override
  late final GeneratedColumn<double> supplyTempC = GeneratedColumn<double>(
    'supply_temp_c',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(35.0),
  );
  static const VerificationMeta _returnTempCMeta = const VerificationMeta(
    'returnTempC',
  );
  @override
  late final GeneratedColumn<double> returnTempC = GeneratedColumn<double>(
    'return_temp_c',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(28.0),
  );
  static const VerificationMeta _pumpCapacityPaMeta = const VerificationMeta(
    'pumpCapacityPa',
  );
  @override
  late final GeneratedColumn<double> pumpCapacityPa = GeneratedColumn<double>(
    'pump_capacity_pa',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _widthMmMeta = const VerificationMeta(
    'widthMm',
  );
  @override
  late final GeneratedColumn<int> widthMm = GeneratedColumn<int>(
    'width_mm',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(500),
  );
  static const VerificationMeta _rotationDegMeta = const VerificationMeta(
    'rotationDeg',
  );
  @override
  late final GeneratedColumn<int> rotationDeg = GeneratedColumn<int>(
    'rotation_deg',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    floorId,
    positionJson,
    supplyTempC,
    returnTempC,
    pumpCapacityPa,
    widthMm,
    rotationDeg,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'distributors';
  @override
  VerificationContext validateIntegrity(
    Insertable<Distributor> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('floor_id')) {
      context.handle(
        _floorIdMeta,
        floorId.isAcceptableOrUnknown(data['floor_id']!, _floorIdMeta),
      );
    } else if (isInserting) {
      context.missing(_floorIdMeta);
    }
    if (data.containsKey('position_json')) {
      context.handle(
        _positionJsonMeta,
        positionJson.isAcceptableOrUnknown(
          data['position_json']!,
          _positionJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_positionJsonMeta);
    }
    if (data.containsKey('supply_temp_c')) {
      context.handle(
        _supplyTempCMeta,
        supplyTempC.isAcceptableOrUnknown(
          data['supply_temp_c']!,
          _supplyTempCMeta,
        ),
      );
    }
    if (data.containsKey('return_temp_c')) {
      context.handle(
        _returnTempCMeta,
        returnTempC.isAcceptableOrUnknown(
          data['return_temp_c']!,
          _returnTempCMeta,
        ),
      );
    }
    if (data.containsKey('pump_capacity_pa')) {
      context.handle(
        _pumpCapacityPaMeta,
        pumpCapacityPa.isAcceptableOrUnknown(
          data['pump_capacity_pa']!,
          _pumpCapacityPaMeta,
        ),
      );
    }
    if (data.containsKey('width_mm')) {
      context.handle(
        _widthMmMeta,
        widthMm.isAcceptableOrUnknown(data['width_mm']!, _widthMmMeta),
      );
    }
    if (data.containsKey('rotation_deg')) {
      context.handle(
        _rotationDegMeta,
        rotationDeg.isAcceptableOrUnknown(
          data['rotation_deg']!,
          _rotationDegMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Distributor map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Distributor(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      floorId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}floor_id'],
      )!,
      positionJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}position_json'],
      )!,
      supplyTempC: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}supply_temp_c'],
      )!,
      returnTempC: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}return_temp_c'],
      )!,
      pumpCapacityPa: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}pump_capacity_pa'],
      ),
      widthMm: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}width_mm'],
      )!,
      rotationDeg: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rotation_deg'],
      )!,
    );
  }

  @override
  $DistributorsTable createAlias(String alias) {
    return $DistributorsTable(attachedDatabase, alias);
  }
}

class Distributor extends DataClass implements Insertable<Distributor> {
  final String id;
  final String floorId;

  /// JSON {x,y} position on the floor plan in mm.
  final String positionJson;
  final double supplyTempC;
  final double returnTempC;

  /// Optional rated pump capacity entered by the user (Pa).
  final double? pumpCapacityPa;
  final int widthMm;
  final int rotationDeg;
  const Distributor({
    required this.id,
    required this.floorId,
    required this.positionJson,
    required this.supplyTempC,
    required this.returnTempC,
    this.pumpCapacityPa,
    required this.widthMm,
    required this.rotationDeg,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['floor_id'] = Variable<String>(floorId);
    map['position_json'] = Variable<String>(positionJson);
    map['supply_temp_c'] = Variable<double>(supplyTempC);
    map['return_temp_c'] = Variable<double>(returnTempC);
    if (!nullToAbsent || pumpCapacityPa != null) {
      map['pump_capacity_pa'] = Variable<double>(pumpCapacityPa);
    }
    map['width_mm'] = Variable<int>(widthMm);
    map['rotation_deg'] = Variable<int>(rotationDeg);
    return map;
  }

  DistributorsCompanion toCompanion(bool nullToAbsent) {
    return DistributorsCompanion(
      id: Value(id),
      floorId: Value(floorId),
      positionJson: Value(positionJson),
      supplyTempC: Value(supplyTempC),
      returnTempC: Value(returnTempC),
      pumpCapacityPa: pumpCapacityPa == null && nullToAbsent
          ? const Value.absent()
          : Value(pumpCapacityPa),
      widthMm: Value(widthMm),
      rotationDeg: Value(rotationDeg),
    );
  }

  factory Distributor.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Distributor(
      id: serializer.fromJson<String>(json['id']),
      floorId: serializer.fromJson<String>(json['floorId']),
      positionJson: serializer.fromJson<String>(json['positionJson']),
      supplyTempC: serializer.fromJson<double>(json['supplyTempC']),
      returnTempC: serializer.fromJson<double>(json['returnTempC']),
      pumpCapacityPa: serializer.fromJson<double?>(json['pumpCapacityPa']),
      widthMm: serializer.fromJson<int>(json['widthMm']),
      rotationDeg: serializer.fromJson<int>(json['rotationDeg']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'floorId': serializer.toJson<String>(floorId),
      'positionJson': serializer.toJson<String>(positionJson),
      'supplyTempC': serializer.toJson<double>(supplyTempC),
      'returnTempC': serializer.toJson<double>(returnTempC),
      'pumpCapacityPa': serializer.toJson<double?>(pumpCapacityPa),
      'widthMm': serializer.toJson<int>(widthMm),
      'rotationDeg': serializer.toJson<int>(rotationDeg),
    };
  }

  Distributor copyWith({
    String? id,
    String? floorId,
    String? positionJson,
    double? supplyTempC,
    double? returnTempC,
    Value<double?> pumpCapacityPa = const Value.absent(),
    int? widthMm,
    int? rotationDeg,
  }) => Distributor(
    id: id ?? this.id,
    floorId: floorId ?? this.floorId,
    positionJson: positionJson ?? this.positionJson,
    supplyTempC: supplyTempC ?? this.supplyTempC,
    returnTempC: returnTempC ?? this.returnTempC,
    pumpCapacityPa: pumpCapacityPa.present
        ? pumpCapacityPa.value
        : this.pumpCapacityPa,
    widthMm: widthMm ?? this.widthMm,
    rotationDeg: rotationDeg ?? this.rotationDeg,
  );
  Distributor copyWithCompanion(DistributorsCompanion data) {
    return Distributor(
      id: data.id.present ? data.id.value : this.id,
      floorId: data.floorId.present ? data.floorId.value : this.floorId,
      positionJson: data.positionJson.present
          ? data.positionJson.value
          : this.positionJson,
      supplyTempC: data.supplyTempC.present
          ? data.supplyTempC.value
          : this.supplyTempC,
      returnTempC: data.returnTempC.present
          ? data.returnTempC.value
          : this.returnTempC,
      pumpCapacityPa: data.pumpCapacityPa.present
          ? data.pumpCapacityPa.value
          : this.pumpCapacityPa,
      widthMm: data.widthMm.present ? data.widthMm.value : this.widthMm,
      rotationDeg: data.rotationDeg.present
          ? data.rotationDeg.value
          : this.rotationDeg,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Distributor(')
          ..write('id: $id, ')
          ..write('floorId: $floorId, ')
          ..write('positionJson: $positionJson, ')
          ..write('supplyTempC: $supplyTempC, ')
          ..write('returnTempC: $returnTempC, ')
          ..write('pumpCapacityPa: $pumpCapacityPa, ')
          ..write('widthMm: $widthMm, ')
          ..write('rotationDeg: $rotationDeg')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    floorId,
    positionJson,
    supplyTempC,
    returnTempC,
    pumpCapacityPa,
    widthMm,
    rotationDeg,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Distributor &&
          other.id == this.id &&
          other.floorId == this.floorId &&
          other.positionJson == this.positionJson &&
          other.supplyTempC == this.supplyTempC &&
          other.returnTempC == this.returnTempC &&
          other.pumpCapacityPa == this.pumpCapacityPa &&
          other.widthMm == this.widthMm &&
          other.rotationDeg == this.rotationDeg);
}

class DistributorsCompanion extends UpdateCompanion<Distributor> {
  final Value<String> id;
  final Value<String> floorId;
  final Value<String> positionJson;
  final Value<double> supplyTempC;
  final Value<double> returnTempC;
  final Value<double?> pumpCapacityPa;
  final Value<int> widthMm;
  final Value<int> rotationDeg;
  final Value<int> rowid;
  const DistributorsCompanion({
    this.id = const Value.absent(),
    this.floorId = const Value.absent(),
    this.positionJson = const Value.absent(),
    this.supplyTempC = const Value.absent(),
    this.returnTempC = const Value.absent(),
    this.pumpCapacityPa = const Value.absent(),
    this.widthMm = const Value.absent(),
    this.rotationDeg = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DistributorsCompanion.insert({
    required String id,
    required String floorId,
    required String positionJson,
    this.supplyTempC = const Value.absent(),
    this.returnTempC = const Value.absent(),
    this.pumpCapacityPa = const Value.absent(),
    this.widthMm = const Value.absent(),
    this.rotationDeg = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       floorId = Value(floorId),
       positionJson = Value(positionJson);
  static Insertable<Distributor> custom({
    Expression<String>? id,
    Expression<String>? floorId,
    Expression<String>? positionJson,
    Expression<double>? supplyTempC,
    Expression<double>? returnTempC,
    Expression<double>? pumpCapacityPa,
    Expression<int>? widthMm,
    Expression<int>? rotationDeg,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (floorId != null) 'floor_id': floorId,
      if (positionJson != null) 'position_json': positionJson,
      if (supplyTempC != null) 'supply_temp_c': supplyTempC,
      if (returnTempC != null) 'return_temp_c': returnTempC,
      if (pumpCapacityPa != null) 'pump_capacity_pa': pumpCapacityPa,
      if (widthMm != null) 'width_mm': widthMm,
      if (rotationDeg != null) 'rotation_deg': rotationDeg,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DistributorsCompanion copyWith({
    Value<String>? id,
    Value<String>? floorId,
    Value<String>? positionJson,
    Value<double>? supplyTempC,
    Value<double>? returnTempC,
    Value<double?>? pumpCapacityPa,
    Value<int>? widthMm,
    Value<int>? rotationDeg,
    Value<int>? rowid,
  }) {
    return DistributorsCompanion(
      id: id ?? this.id,
      floorId: floorId ?? this.floorId,
      positionJson: positionJson ?? this.positionJson,
      supplyTempC: supplyTempC ?? this.supplyTempC,
      returnTempC: returnTempC ?? this.returnTempC,
      pumpCapacityPa: pumpCapacityPa ?? this.pumpCapacityPa,
      widthMm: widthMm ?? this.widthMm,
      rotationDeg: rotationDeg ?? this.rotationDeg,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (floorId.present) {
      map['floor_id'] = Variable<String>(floorId.value);
    }
    if (positionJson.present) {
      map['position_json'] = Variable<String>(positionJson.value);
    }
    if (supplyTempC.present) {
      map['supply_temp_c'] = Variable<double>(supplyTempC.value);
    }
    if (returnTempC.present) {
      map['return_temp_c'] = Variable<double>(returnTempC.value);
    }
    if (pumpCapacityPa.present) {
      map['pump_capacity_pa'] = Variable<double>(pumpCapacityPa.value);
    }
    if (widthMm.present) {
      map['width_mm'] = Variable<int>(widthMm.value);
    }
    if (rotationDeg.present) {
      map['rotation_deg'] = Variable<int>(rotationDeg.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DistributorsCompanion(')
          ..write('id: $id, ')
          ..write('floorId: $floorId, ')
          ..write('positionJson: $positionJson, ')
          ..write('supplyTempC: $supplyTempC, ')
          ..write('returnTempC: $returnTempC, ')
          ..write('pumpCapacityPa: $pumpCapacityPa, ')
          ..write('widthMm: $widthMm, ')
          ..write('rotationDeg: $rotationDeg, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HeatingCircuitsTable extends HeatingCircuits
    with TableInfo<$HeatingCircuitsTable, HeatingCircuit> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HeatingCircuitsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _distributorIdMeta = const VerificationMeta(
    'distributorId',
  );
  @override
  late final GeneratedColumn<String> distributorId = GeneratedColumn<String>(
    'distributor_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES distributors (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _heatingZoneIdMeta = const VerificationMeta(
    'heatingZoneId',
  );
  @override
  late final GeneratedColumn<String> heatingZoneId = GeneratedColumn<String>(
    'heating_zone_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES heating_zones (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _supplyRoutePathJsonMeta =
      const VerificationMeta('supplyRoutePathJson');
  @override
  late final GeneratedColumn<String> supplyRoutePathJson =
      GeneratedColumn<String>(
        'supply_route_path_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      );
  static const VerificationMeta _returnRoutePathJsonMeta =
      const VerificationMeta('returnRoutePathJson');
  @override
  late final GeneratedColumn<String> returnRoutePathJson =
      GeneratedColumn<String>(
        'return_route_path_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      );
  static const VerificationMeta _tubeLengthMMeta = const VerificationMeta(
    'tubeLengthM',
  );
  @override
  late final GeneratedColumn<double> tubeLengthM = GeneratedColumn<double>(
    'tube_length_m',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _flowRateKgHMeta = const VerificationMeta(
    'flowRateKgH',
  );
  @override
  late final GeneratedColumn<double> flowRateKgH = GeneratedColumn<double>(
    'flow_rate_kg_h',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _pressureLossPaMeta = const VerificationMeta(
    'pressureLossPa',
  );
  @override
  late final GeneratedColumn<double> pressureLossPa = GeneratedColumn<double>(
    'pressure_loss_pa',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _valveSettingMeta = const VerificationMeta(
    'valveSetting',
  );
  @override
  late final GeneratedColumn<double> valveSetting = GeneratedColumn<double>(
    'valve_setting',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    distributorId,
    heatingZoneId,
    supplyRoutePathJson,
    returnRoutePathJson,
    tubeLengthM,
    flowRateKgH,
    pressureLossPa,
    valveSetting,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'heating_circuits';
  @override
  VerificationContext validateIntegrity(
    Insertable<HeatingCircuit> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('distributor_id')) {
      context.handle(
        _distributorIdMeta,
        distributorId.isAcceptableOrUnknown(
          data['distributor_id']!,
          _distributorIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_distributorIdMeta);
    }
    if (data.containsKey('heating_zone_id')) {
      context.handle(
        _heatingZoneIdMeta,
        heatingZoneId.isAcceptableOrUnknown(
          data['heating_zone_id']!,
          _heatingZoneIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_heatingZoneIdMeta);
    }
    if (data.containsKey('supply_route_path_json')) {
      context.handle(
        _supplyRoutePathJsonMeta,
        supplyRoutePathJson.isAcceptableOrUnknown(
          data['supply_route_path_json']!,
          _supplyRoutePathJsonMeta,
        ),
      );
    }
    if (data.containsKey('return_route_path_json')) {
      context.handle(
        _returnRoutePathJsonMeta,
        returnRoutePathJson.isAcceptableOrUnknown(
          data['return_route_path_json']!,
          _returnRoutePathJsonMeta,
        ),
      );
    }
    if (data.containsKey('tube_length_m')) {
      context.handle(
        _tubeLengthMMeta,
        tubeLengthM.isAcceptableOrUnknown(
          data['tube_length_m']!,
          _tubeLengthMMeta,
        ),
      );
    }
    if (data.containsKey('flow_rate_kg_h')) {
      context.handle(
        _flowRateKgHMeta,
        flowRateKgH.isAcceptableOrUnknown(
          data['flow_rate_kg_h']!,
          _flowRateKgHMeta,
        ),
      );
    }
    if (data.containsKey('pressure_loss_pa')) {
      context.handle(
        _pressureLossPaMeta,
        pressureLossPa.isAcceptableOrUnknown(
          data['pressure_loss_pa']!,
          _pressureLossPaMeta,
        ),
      );
    }
    if (data.containsKey('valve_setting')) {
      context.handle(
        _valveSettingMeta,
        valveSetting.isAcceptableOrUnknown(
          data['valve_setting']!,
          _valveSettingMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HeatingCircuit map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HeatingCircuit(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      distributorId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}distributor_id'],
      )!,
      heatingZoneId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}heating_zone_id'],
      )!,
      supplyRoutePathJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}supply_route_path_json'],
      )!,
      returnRoutePathJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}return_route_path_json'],
      )!,
      tubeLengthM: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}tube_length_m'],
      )!,
      flowRateKgH: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}flow_rate_kg_h'],
      )!,
      pressureLossPa: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}pressure_loss_pa'],
      )!,
      valveSetting: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}valve_setting'],
      )!,
    );
  }

  @override
  $HeatingCircuitsTable createAlias(String alias) {
    return $HeatingCircuitsTable(attachedDatabase, alias);
  }
}

class HeatingCircuit extends DataClass implements Insertable<HeatingCircuit> {
  final String id;
  final String distributorId;
  final String heatingZoneId;

  /// JSON array of {x,y} for the supply route polyline.
  final String supplyRoutePathJson;

  /// JSON array of {x,y} for the return route polyline.
  final String returnRoutePathJson;
  final double tubeLengthM;
  final double flowRateKgH;
  final double pressureLossPa;
  final double valveSetting;
  const HeatingCircuit({
    required this.id,
    required this.distributorId,
    required this.heatingZoneId,
    required this.supplyRoutePathJson,
    required this.returnRoutePathJson,
    required this.tubeLengthM,
    required this.flowRateKgH,
    required this.pressureLossPa,
    required this.valveSetting,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['distributor_id'] = Variable<String>(distributorId);
    map['heating_zone_id'] = Variable<String>(heatingZoneId);
    map['supply_route_path_json'] = Variable<String>(supplyRoutePathJson);
    map['return_route_path_json'] = Variable<String>(returnRoutePathJson);
    map['tube_length_m'] = Variable<double>(tubeLengthM);
    map['flow_rate_kg_h'] = Variable<double>(flowRateKgH);
    map['pressure_loss_pa'] = Variable<double>(pressureLossPa);
    map['valve_setting'] = Variable<double>(valveSetting);
    return map;
  }

  HeatingCircuitsCompanion toCompanion(bool nullToAbsent) {
    return HeatingCircuitsCompanion(
      id: Value(id),
      distributorId: Value(distributorId),
      heatingZoneId: Value(heatingZoneId),
      supplyRoutePathJson: Value(supplyRoutePathJson),
      returnRoutePathJson: Value(returnRoutePathJson),
      tubeLengthM: Value(tubeLengthM),
      flowRateKgH: Value(flowRateKgH),
      pressureLossPa: Value(pressureLossPa),
      valveSetting: Value(valveSetting),
    );
  }

  factory HeatingCircuit.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HeatingCircuit(
      id: serializer.fromJson<String>(json['id']),
      distributorId: serializer.fromJson<String>(json['distributorId']),
      heatingZoneId: serializer.fromJson<String>(json['heatingZoneId']),
      supplyRoutePathJson: serializer.fromJson<String>(
        json['supplyRoutePathJson'],
      ),
      returnRoutePathJson: serializer.fromJson<String>(
        json['returnRoutePathJson'],
      ),
      tubeLengthM: serializer.fromJson<double>(json['tubeLengthM']),
      flowRateKgH: serializer.fromJson<double>(json['flowRateKgH']),
      pressureLossPa: serializer.fromJson<double>(json['pressureLossPa']),
      valveSetting: serializer.fromJson<double>(json['valveSetting']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'distributorId': serializer.toJson<String>(distributorId),
      'heatingZoneId': serializer.toJson<String>(heatingZoneId),
      'supplyRoutePathJson': serializer.toJson<String>(supplyRoutePathJson),
      'returnRoutePathJson': serializer.toJson<String>(returnRoutePathJson),
      'tubeLengthM': serializer.toJson<double>(tubeLengthM),
      'flowRateKgH': serializer.toJson<double>(flowRateKgH),
      'pressureLossPa': serializer.toJson<double>(pressureLossPa),
      'valveSetting': serializer.toJson<double>(valveSetting),
    };
  }

  HeatingCircuit copyWith({
    String? id,
    String? distributorId,
    String? heatingZoneId,
    String? supplyRoutePathJson,
    String? returnRoutePathJson,
    double? tubeLengthM,
    double? flowRateKgH,
    double? pressureLossPa,
    double? valveSetting,
  }) => HeatingCircuit(
    id: id ?? this.id,
    distributorId: distributorId ?? this.distributorId,
    heatingZoneId: heatingZoneId ?? this.heatingZoneId,
    supplyRoutePathJson: supplyRoutePathJson ?? this.supplyRoutePathJson,
    returnRoutePathJson: returnRoutePathJson ?? this.returnRoutePathJson,
    tubeLengthM: tubeLengthM ?? this.tubeLengthM,
    flowRateKgH: flowRateKgH ?? this.flowRateKgH,
    pressureLossPa: pressureLossPa ?? this.pressureLossPa,
    valveSetting: valveSetting ?? this.valveSetting,
  );
  HeatingCircuit copyWithCompanion(HeatingCircuitsCompanion data) {
    return HeatingCircuit(
      id: data.id.present ? data.id.value : this.id,
      distributorId: data.distributorId.present
          ? data.distributorId.value
          : this.distributorId,
      heatingZoneId: data.heatingZoneId.present
          ? data.heatingZoneId.value
          : this.heatingZoneId,
      supplyRoutePathJson: data.supplyRoutePathJson.present
          ? data.supplyRoutePathJson.value
          : this.supplyRoutePathJson,
      returnRoutePathJson: data.returnRoutePathJson.present
          ? data.returnRoutePathJson.value
          : this.returnRoutePathJson,
      tubeLengthM: data.tubeLengthM.present
          ? data.tubeLengthM.value
          : this.tubeLengthM,
      flowRateKgH: data.flowRateKgH.present
          ? data.flowRateKgH.value
          : this.flowRateKgH,
      pressureLossPa: data.pressureLossPa.present
          ? data.pressureLossPa.value
          : this.pressureLossPa,
      valveSetting: data.valveSetting.present
          ? data.valveSetting.value
          : this.valveSetting,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HeatingCircuit(')
          ..write('id: $id, ')
          ..write('distributorId: $distributorId, ')
          ..write('heatingZoneId: $heatingZoneId, ')
          ..write('supplyRoutePathJson: $supplyRoutePathJson, ')
          ..write('returnRoutePathJson: $returnRoutePathJson, ')
          ..write('tubeLengthM: $tubeLengthM, ')
          ..write('flowRateKgH: $flowRateKgH, ')
          ..write('pressureLossPa: $pressureLossPa, ')
          ..write('valveSetting: $valveSetting')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    distributorId,
    heatingZoneId,
    supplyRoutePathJson,
    returnRoutePathJson,
    tubeLengthM,
    flowRateKgH,
    pressureLossPa,
    valveSetting,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HeatingCircuit &&
          other.id == this.id &&
          other.distributorId == this.distributorId &&
          other.heatingZoneId == this.heatingZoneId &&
          other.supplyRoutePathJson == this.supplyRoutePathJson &&
          other.returnRoutePathJson == this.returnRoutePathJson &&
          other.tubeLengthM == this.tubeLengthM &&
          other.flowRateKgH == this.flowRateKgH &&
          other.pressureLossPa == this.pressureLossPa &&
          other.valveSetting == this.valveSetting);
}

class HeatingCircuitsCompanion extends UpdateCompanion<HeatingCircuit> {
  final Value<String> id;
  final Value<String> distributorId;
  final Value<String> heatingZoneId;
  final Value<String> supplyRoutePathJson;
  final Value<String> returnRoutePathJson;
  final Value<double> tubeLengthM;
  final Value<double> flowRateKgH;
  final Value<double> pressureLossPa;
  final Value<double> valveSetting;
  final Value<int> rowid;
  const HeatingCircuitsCompanion({
    this.id = const Value.absent(),
    this.distributorId = const Value.absent(),
    this.heatingZoneId = const Value.absent(),
    this.supplyRoutePathJson = const Value.absent(),
    this.returnRoutePathJson = const Value.absent(),
    this.tubeLengthM = const Value.absent(),
    this.flowRateKgH = const Value.absent(),
    this.pressureLossPa = const Value.absent(),
    this.valveSetting = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HeatingCircuitsCompanion.insert({
    required String id,
    required String distributorId,
    required String heatingZoneId,
    this.supplyRoutePathJson = const Value.absent(),
    this.returnRoutePathJson = const Value.absent(),
    this.tubeLengthM = const Value.absent(),
    this.flowRateKgH = const Value.absent(),
    this.pressureLossPa = const Value.absent(),
    this.valveSetting = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       distributorId = Value(distributorId),
       heatingZoneId = Value(heatingZoneId);
  static Insertable<HeatingCircuit> custom({
    Expression<String>? id,
    Expression<String>? distributorId,
    Expression<String>? heatingZoneId,
    Expression<String>? supplyRoutePathJson,
    Expression<String>? returnRoutePathJson,
    Expression<double>? tubeLengthM,
    Expression<double>? flowRateKgH,
    Expression<double>? pressureLossPa,
    Expression<double>? valveSetting,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (distributorId != null) 'distributor_id': distributorId,
      if (heatingZoneId != null) 'heating_zone_id': heatingZoneId,
      if (supplyRoutePathJson != null)
        'supply_route_path_json': supplyRoutePathJson,
      if (returnRoutePathJson != null)
        'return_route_path_json': returnRoutePathJson,
      if (tubeLengthM != null) 'tube_length_m': tubeLengthM,
      if (flowRateKgH != null) 'flow_rate_kg_h': flowRateKgH,
      if (pressureLossPa != null) 'pressure_loss_pa': pressureLossPa,
      if (valveSetting != null) 'valve_setting': valveSetting,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HeatingCircuitsCompanion copyWith({
    Value<String>? id,
    Value<String>? distributorId,
    Value<String>? heatingZoneId,
    Value<String>? supplyRoutePathJson,
    Value<String>? returnRoutePathJson,
    Value<double>? tubeLengthM,
    Value<double>? flowRateKgH,
    Value<double>? pressureLossPa,
    Value<double>? valveSetting,
    Value<int>? rowid,
  }) {
    return HeatingCircuitsCompanion(
      id: id ?? this.id,
      distributorId: distributorId ?? this.distributorId,
      heatingZoneId: heatingZoneId ?? this.heatingZoneId,
      supplyRoutePathJson: supplyRoutePathJson ?? this.supplyRoutePathJson,
      returnRoutePathJson: returnRoutePathJson ?? this.returnRoutePathJson,
      tubeLengthM: tubeLengthM ?? this.tubeLengthM,
      flowRateKgH: flowRateKgH ?? this.flowRateKgH,
      pressureLossPa: pressureLossPa ?? this.pressureLossPa,
      valveSetting: valveSetting ?? this.valveSetting,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (distributorId.present) {
      map['distributor_id'] = Variable<String>(distributorId.value);
    }
    if (heatingZoneId.present) {
      map['heating_zone_id'] = Variable<String>(heatingZoneId.value);
    }
    if (supplyRoutePathJson.present) {
      map['supply_route_path_json'] = Variable<String>(
        supplyRoutePathJson.value,
      );
    }
    if (returnRoutePathJson.present) {
      map['return_route_path_json'] = Variable<String>(
        returnRoutePathJson.value,
      );
    }
    if (tubeLengthM.present) {
      map['tube_length_m'] = Variable<double>(tubeLengthM.value);
    }
    if (flowRateKgH.present) {
      map['flow_rate_kg_h'] = Variable<double>(flowRateKgH.value);
    }
    if (pressureLossPa.present) {
      map['pressure_loss_pa'] = Variable<double>(pressureLossPa.value);
    }
    if (valveSetting.present) {
      map['valve_setting'] = Variable<double>(valveSetting.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HeatingCircuitsCompanion(')
          ..write('id: $id, ')
          ..write('distributorId: $distributorId, ')
          ..write('heatingZoneId: $heatingZoneId, ')
          ..write('supplyRoutePathJson: $supplyRoutePathJson, ')
          ..write('returnRoutePathJson: $returnRoutePathJson, ')
          ..write('tubeLengthM: $tubeLengthM, ')
          ..write('flowRateKgH: $flowRateKgH, ')
          ..write('pressureLossPa: $pressureLossPa, ')
          ..write('valveSetting: $valveSetting, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ProjectsTable projects = $ProjectsTable(this);
  late final $FloorsTable floors = $FloorsTable(this);
  late final $RoomsTable rooms = $RoomsTable(this);
  late final $WallConstructionsTable wallConstructions =
      $WallConstructionsTable(this);
  late final $WallSegmentsTable wallSegments = $WallSegmentsTable(this);
  late final $WindowsTable windows = $WindowsTable(this);
  late final $DoorsTable doors = $DoorsTable(this);
  late final $MaterialEntriesTable materialEntries = $MaterialEntriesTable(
    this,
  );
  late final $MaterialLayersTable materialLayers = $MaterialLayersTable(this);
  late final $TubeTypesTable tubeTypes = $TubeTypesTable(this);
  late final $FlooringMaterialsTable flooringMaterials =
      $FlooringMaterialsTable(this);
  late final $HeatingZonesTable heatingZones = $HeatingZonesTable(this);
  late final $DistributorsTable distributors = $DistributorsTable(this);
  late final $HeatingCircuitsTable heatingCircuits = $HeatingCircuitsTable(
    this,
  );
  late final ProjectDao projectDao = ProjectDao(this as AppDatabase);
  late final BuildingDao buildingDao = BuildingDao(this as AppDatabase);
  late final ConstructionDao constructionDao = ConstructionDao(
    this as AppDatabase,
  );
  late final MaterialDao materialDao = MaterialDao(this as AppDatabase);
  late final HeatingDao heatingDao = HeatingDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    projects,
    floors,
    rooms,
    wallConstructions,
    wallSegments,
    windows,
    doors,
    materialEntries,
    materialLayers,
    tubeTypes,
    flooringMaterials,
    heatingZones,
    distributors,
    heatingCircuits,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'projects',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('floors', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'floors',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('rooms', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'rooms',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('wall_segments', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'wall_constructions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('wall_segments', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'rooms',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('wall_segments', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'wall_segments',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('wall_segments', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'wall_segments',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('windows', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'wall_segments',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('doors', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'wall_constructions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('material_layers', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'rooms',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('heating_zones', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'wall_segments',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('heating_zones', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'floors',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('distributors', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'distributors',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('heating_circuits', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'heating_zones',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('heating_circuits', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$ProjectsTableCreateCompanionBuilder =
    ProjectsCompanion Function({
      required String id,
      required String name,
      required DateTime createdAt,
      required DateTime modifiedAt,
      Value<double> designOutdoorTempC,
      Value<double> defaultIndoorTempC,
      Value<int> floorHeightMm,
      Value<double> unheatedSpaceTempC,
      Value<String?> locationJson,
      Value<int> rowid,
    });
typedef $$ProjectsTableUpdateCompanionBuilder =
    ProjectsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<DateTime> createdAt,
      Value<DateTime> modifiedAt,
      Value<double> designOutdoorTempC,
      Value<double> defaultIndoorTempC,
      Value<int> floorHeightMm,
      Value<double> unheatedSpaceTempC,
      Value<String?> locationJson,
      Value<int> rowid,
    });

final class $$ProjectsTableReferences
    extends BaseReferences<_$AppDatabase, $ProjectsTable, Project> {
  $$ProjectsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$FloorsTable, List<Floor>> _floorsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.floors,
    aliasName: $_aliasNameGenerator(db.projects.id, db.floors.projectId),
  );

  $$FloorsTableProcessedTableManager get floorsRefs {
    final manager = $$FloorsTableTableManager(
      $_db,
      $_db.floors,
    ).filter((f) => f.projectId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_floorsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ProjectsTableFilterComposer
    extends Composer<_$AppDatabase, $ProjectsTable> {
  $$ProjectsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get modifiedAt => $composableBuilder(
    column: $table.modifiedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get designOutdoorTempC => $composableBuilder(
    column: $table.designOutdoorTempC,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get defaultIndoorTempC => $composableBuilder(
    column: $table.defaultIndoorTempC,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get floorHeightMm => $composableBuilder(
    column: $table.floorHeightMm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get unheatedSpaceTempC => $composableBuilder(
    column: $table.unheatedSpaceTempC,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get locationJson => $composableBuilder(
    column: $table.locationJson,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> floorsRefs(
    Expression<bool> Function($$FloorsTableFilterComposer f) f,
  ) {
    final $$FloorsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.floors,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FloorsTableFilterComposer(
            $db: $db,
            $table: $db.floors,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProjectsTableOrderingComposer
    extends Composer<_$AppDatabase, $ProjectsTable> {
  $$ProjectsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get modifiedAt => $composableBuilder(
    column: $table.modifiedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get designOutdoorTempC => $composableBuilder(
    column: $table.designOutdoorTempC,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get defaultIndoorTempC => $composableBuilder(
    column: $table.defaultIndoorTempC,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get floorHeightMm => $composableBuilder(
    column: $table.floorHeightMm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get unheatedSpaceTempC => $composableBuilder(
    column: $table.unheatedSpaceTempC,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get locationJson => $composableBuilder(
    column: $table.locationJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProjectsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProjectsTable> {
  $$ProjectsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get modifiedAt => $composableBuilder(
    column: $table.modifiedAt,
    builder: (column) => column,
  );

  GeneratedColumn<double> get designOutdoorTempC => $composableBuilder(
    column: $table.designOutdoorTempC,
    builder: (column) => column,
  );

  GeneratedColumn<double> get defaultIndoorTempC => $composableBuilder(
    column: $table.defaultIndoorTempC,
    builder: (column) => column,
  );

  GeneratedColumn<int> get floorHeightMm => $composableBuilder(
    column: $table.floorHeightMm,
    builder: (column) => column,
  );

  GeneratedColumn<double> get unheatedSpaceTempC => $composableBuilder(
    column: $table.unheatedSpaceTempC,
    builder: (column) => column,
  );

  GeneratedColumn<String> get locationJson => $composableBuilder(
    column: $table.locationJson,
    builder: (column) => column,
  );

  Expression<T> floorsRefs<T extends Object>(
    Expression<T> Function($$FloorsTableAnnotationComposer a) f,
  ) {
    final $$FloorsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.floors,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FloorsTableAnnotationComposer(
            $db: $db,
            $table: $db.floors,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProjectsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProjectsTable,
          Project,
          $$ProjectsTableFilterComposer,
          $$ProjectsTableOrderingComposer,
          $$ProjectsTableAnnotationComposer,
          $$ProjectsTableCreateCompanionBuilder,
          $$ProjectsTableUpdateCompanionBuilder,
          (Project, $$ProjectsTableReferences),
          Project,
          PrefetchHooks Function({bool floorsRefs})
        > {
  $$ProjectsTableTableManager(_$AppDatabase db, $ProjectsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProjectsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProjectsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProjectsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> modifiedAt = const Value.absent(),
                Value<double> designOutdoorTempC = const Value.absent(),
                Value<double> defaultIndoorTempC = const Value.absent(),
                Value<int> floorHeightMm = const Value.absent(),
                Value<double> unheatedSpaceTempC = const Value.absent(),
                Value<String?> locationJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProjectsCompanion(
                id: id,
                name: name,
                createdAt: createdAt,
                modifiedAt: modifiedAt,
                designOutdoorTempC: designOutdoorTempC,
                defaultIndoorTempC: defaultIndoorTempC,
                floorHeightMm: floorHeightMm,
                unheatedSpaceTempC: unheatedSpaceTempC,
                locationJson: locationJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required DateTime createdAt,
                required DateTime modifiedAt,
                Value<double> designOutdoorTempC = const Value.absent(),
                Value<double> defaultIndoorTempC = const Value.absent(),
                Value<int> floorHeightMm = const Value.absent(),
                Value<double> unheatedSpaceTempC = const Value.absent(),
                Value<String?> locationJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProjectsCompanion.insert(
                id: id,
                name: name,
                createdAt: createdAt,
                modifiedAt: modifiedAt,
                designOutdoorTempC: designOutdoorTempC,
                defaultIndoorTempC: defaultIndoorTempC,
                floorHeightMm: floorHeightMm,
                unheatedSpaceTempC: unheatedSpaceTempC,
                locationJson: locationJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ProjectsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({floorsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (floorsRefs) db.floors],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (floorsRefs)
                    await $_getPrefetchedData<Project, $ProjectsTable, Floor>(
                      currentTable: table,
                      referencedTable: $$ProjectsTableReferences
                          ._floorsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$ProjectsTableReferences(db, table, p0).floorsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.projectId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ProjectsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProjectsTable,
      Project,
      $$ProjectsTableFilterComposer,
      $$ProjectsTableOrderingComposer,
      $$ProjectsTableAnnotationComposer,
      $$ProjectsTableCreateCompanionBuilder,
      $$ProjectsTableUpdateCompanionBuilder,
      (Project, $$ProjectsTableReferences),
      Project,
      PrefetchHooks Function({bool floorsRefs})
    >;
typedef $$FloorsTableCreateCompanionBuilder =
    FloorsCompanion Function({
      required String id,
      required String projectId,
      required String name,
      Value<int> level,
      Value<int> heightMm,
      Value<int> rowid,
    });
typedef $$FloorsTableUpdateCompanionBuilder =
    FloorsCompanion Function({
      Value<String> id,
      Value<String> projectId,
      Value<String> name,
      Value<int> level,
      Value<int> heightMm,
      Value<int> rowid,
    });

final class $$FloorsTableReferences
    extends BaseReferences<_$AppDatabase, $FloorsTable, Floor> {
  $$FloorsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProjectsTable _projectIdTable(_$AppDatabase db) => db.projects
      .createAlias($_aliasNameGenerator(db.floors.projectId, db.projects.id));

  $$ProjectsTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<String>('project_id')!;

    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$RoomsTable, List<Room>> _roomsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.rooms,
    aliasName: $_aliasNameGenerator(db.floors.id, db.rooms.floorId),
  );

  $$RoomsTableProcessedTableManager get roomsRefs {
    final manager = $$RoomsTableTableManager(
      $_db,
      $_db.rooms,
    ).filter((f) => f.floorId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_roomsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$DistributorsTable, List<Distributor>>
  _distributorsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.distributors,
    aliasName: $_aliasNameGenerator(db.floors.id, db.distributors.floorId),
  );

  $$DistributorsTableProcessedTableManager get distributorsRefs {
    final manager = $$DistributorsTableTableManager(
      $_db,
      $_db.distributors,
    ).filter((f) => f.floorId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_distributorsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$FloorsTableFilterComposer
    extends Composer<_$AppDatabase, $FloorsTable> {
  $$FloorsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get heightMm => $composableBuilder(
    column: $table.heightMm,
    builder: (column) => ColumnFilters(column),
  );

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> roomsRefs(
    Expression<bool> Function($$RoomsTableFilterComposer f) f,
  ) {
    final $$RoomsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.rooms,
      getReferencedColumn: (t) => t.floorId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RoomsTableFilterComposer(
            $db: $db,
            $table: $db.rooms,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> distributorsRefs(
    Expression<bool> Function($$DistributorsTableFilterComposer f) f,
  ) {
    final $$DistributorsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.distributors,
      getReferencedColumn: (t) => t.floorId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DistributorsTableFilterComposer(
            $db: $db,
            $table: $db.distributors,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FloorsTableOrderingComposer
    extends Composer<_$AppDatabase, $FloorsTable> {
  $$FloorsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get heightMm => $composableBuilder(
    column: $table.heightMm,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableOrderingComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FloorsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FloorsTable> {
  $$FloorsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get level =>
      $composableBuilder(column: $table.level, builder: (column) => column);

  GeneratedColumn<int> get heightMm =>
      $composableBuilder(column: $table.heightMm, builder: (column) => column);

  $$ProjectsTableAnnotationComposer get projectId {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> roomsRefs<T extends Object>(
    Expression<T> Function($$RoomsTableAnnotationComposer a) f,
  ) {
    final $$RoomsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.rooms,
      getReferencedColumn: (t) => t.floorId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RoomsTableAnnotationComposer(
            $db: $db,
            $table: $db.rooms,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> distributorsRefs<T extends Object>(
    Expression<T> Function($$DistributorsTableAnnotationComposer a) f,
  ) {
    final $$DistributorsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.distributors,
      getReferencedColumn: (t) => t.floorId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DistributorsTableAnnotationComposer(
            $db: $db,
            $table: $db.distributors,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FloorsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FloorsTable,
          Floor,
          $$FloorsTableFilterComposer,
          $$FloorsTableOrderingComposer,
          $$FloorsTableAnnotationComposer,
          $$FloorsTableCreateCompanionBuilder,
          $$FloorsTableUpdateCompanionBuilder,
          (Floor, $$FloorsTableReferences),
          Floor,
          PrefetchHooks Function({
            bool projectId,
            bool roomsRefs,
            bool distributorsRefs,
          })
        > {
  $$FloorsTableTableManager(_$AppDatabase db, $FloorsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FloorsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FloorsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FloorsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> projectId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> level = const Value.absent(),
                Value<int> heightMm = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FloorsCompanion(
                id: id,
                projectId: projectId,
                name: name,
                level: level,
                heightMm: heightMm,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String projectId,
                required String name,
                Value<int> level = const Value.absent(),
                Value<int> heightMm = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FloorsCompanion.insert(
                id: id,
                projectId: projectId,
                name: name,
                level: level,
                heightMm: heightMm,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$FloorsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                projectId = false,
                roomsRefs = false,
                distributorsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (roomsRefs) db.rooms,
                    if (distributorsRefs) db.distributors,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (projectId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.projectId,
                                    referencedTable: $$FloorsTableReferences
                                        ._projectIdTable(db),
                                    referencedColumn: $$FloorsTableReferences
                                        ._projectIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (roomsRefs)
                        await $_getPrefetchedData<Floor, $FloorsTable, Room>(
                          currentTable: table,
                          referencedTable: $$FloorsTableReferences
                              ._roomsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$FloorsTableReferences(db, table, p0).roomsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.floorId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (distributorsRefs)
                        await $_getPrefetchedData<
                          Floor,
                          $FloorsTable,
                          Distributor
                        >(
                          currentTable: table,
                          referencedTable: $$FloorsTableReferences
                              ._distributorsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$FloorsTableReferences(
                                db,
                                table,
                                p0,
                              ).distributorsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.floorId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$FloorsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FloorsTable,
      Floor,
      $$FloorsTableFilterComposer,
      $$FloorsTableOrderingComposer,
      $$FloorsTableAnnotationComposer,
      $$FloorsTableCreateCompanionBuilder,
      $$FloorsTableUpdateCompanionBuilder,
      (Floor, $$FloorsTableReferences),
      Floor,
      PrefetchHooks Function({
        bool projectId,
        bool roomsRefs,
        bool distributorsRefs,
      })
    >;
typedef $$RoomsTableCreateCompanionBuilder =
    RoomsCompanion Function({
      required String id,
      required String floorId,
      required String name,
      Value<double> targetTempC,
      Value<double> airChangeRate,
      Value<String> polygonJson,
      Value<String?> floorConstructionId,
      Value<String?> ceilingConstructionId,
      Value<String> floorBoundary,
      Value<String> ceilingBoundary,
      Value<double?> floorAdjacentTempC,
      Value<double?> ceilingAdjacentTempC,
      Value<int> rowid,
    });
typedef $$RoomsTableUpdateCompanionBuilder =
    RoomsCompanion Function({
      Value<String> id,
      Value<String> floorId,
      Value<String> name,
      Value<double> targetTempC,
      Value<double> airChangeRate,
      Value<String> polygonJson,
      Value<String?> floorConstructionId,
      Value<String?> ceilingConstructionId,
      Value<String> floorBoundary,
      Value<String> ceilingBoundary,
      Value<double?> floorAdjacentTempC,
      Value<double?> ceilingAdjacentTempC,
      Value<int> rowid,
    });

final class $$RoomsTableReferences
    extends BaseReferences<_$AppDatabase, $RoomsTable, Room> {
  $$RoomsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $FloorsTable _floorIdTable(_$AppDatabase db) => db.floors.createAlias(
    $_aliasNameGenerator(db.rooms.floorId, db.floors.id),
  );

  $$FloorsTableProcessedTableManager get floorId {
    final $_column = $_itemColumn<String>('floor_id')!;

    final manager = $$FloorsTableTableManager(
      $_db,
      $_db.floors,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_floorIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$WallSegmentsTable, List<WallSegment>>
  _wallSegmentsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.wallSegments,
    aliasName: $_aliasNameGenerator(db.rooms.id, db.wallSegments.roomId),
  );

  $$WallSegmentsTableProcessedTableManager get wallSegments {
    final manager = $$WallSegmentsTableTableManager(
      $_db,
      $_db.wallSegments,
    ).filter((f) => f.roomId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_wallSegmentsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$WallSegmentsTable, List<WallSegment>>
  _adjacentWallSegmentsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.wallSegments,
    aliasName: $_aliasNameGenerator(
      db.rooms.id,
      db.wallSegments.adjacentRoomId,
    ),
  );

  $$WallSegmentsTableProcessedTableManager get adjacentWallSegments {
    final manager = $$WallSegmentsTableTableManager(
      $_db,
      $_db.wallSegments,
    ).filter((f) => f.adjacentRoomId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _adjacentWallSegmentsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$HeatingZonesTable, List<HeatingZone>>
  _heatingZonesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.heatingZones,
    aliasName: $_aliasNameGenerator(db.rooms.id, db.heatingZones.roomId),
  );

  $$HeatingZonesTableProcessedTableManager get heatingZonesRefs {
    final manager = $$HeatingZonesTableTableManager(
      $_db,
      $_db.heatingZones,
    ).filter((f) => f.roomId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_heatingZonesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$RoomsTableFilterComposer extends Composer<_$AppDatabase, $RoomsTable> {
  $$RoomsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get targetTempC => $composableBuilder(
    column: $table.targetTempC,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get airChangeRate => $composableBuilder(
    column: $table.airChangeRate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get polygonJson => $composableBuilder(
    column: $table.polygonJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get floorConstructionId => $composableBuilder(
    column: $table.floorConstructionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ceilingConstructionId => $composableBuilder(
    column: $table.ceilingConstructionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get floorBoundary => $composableBuilder(
    column: $table.floorBoundary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ceilingBoundary => $composableBuilder(
    column: $table.ceilingBoundary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get floorAdjacentTempC => $composableBuilder(
    column: $table.floorAdjacentTempC,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get ceilingAdjacentTempC => $composableBuilder(
    column: $table.ceilingAdjacentTempC,
    builder: (column) => ColumnFilters(column),
  );

  $$FloorsTableFilterComposer get floorId {
    final $$FloorsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.floorId,
      referencedTable: $db.floors,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FloorsTableFilterComposer(
            $db: $db,
            $table: $db.floors,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> wallSegments(
    Expression<bool> Function($$WallSegmentsTableFilterComposer f) f,
  ) {
    final $$WallSegmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.wallSegments,
      getReferencedColumn: (t) => t.roomId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WallSegmentsTableFilterComposer(
            $db: $db,
            $table: $db.wallSegments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> adjacentWallSegments(
    Expression<bool> Function($$WallSegmentsTableFilterComposer f) f,
  ) {
    final $$WallSegmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.wallSegments,
      getReferencedColumn: (t) => t.adjacentRoomId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WallSegmentsTableFilterComposer(
            $db: $db,
            $table: $db.wallSegments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> heatingZonesRefs(
    Expression<bool> Function($$HeatingZonesTableFilterComposer f) f,
  ) {
    final $$HeatingZonesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.heatingZones,
      getReferencedColumn: (t) => t.roomId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HeatingZonesTableFilterComposer(
            $db: $db,
            $table: $db.heatingZones,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RoomsTableOrderingComposer
    extends Composer<_$AppDatabase, $RoomsTable> {
  $$RoomsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get targetTempC => $composableBuilder(
    column: $table.targetTempC,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get airChangeRate => $composableBuilder(
    column: $table.airChangeRate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get polygonJson => $composableBuilder(
    column: $table.polygonJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get floorConstructionId => $composableBuilder(
    column: $table.floorConstructionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ceilingConstructionId => $composableBuilder(
    column: $table.ceilingConstructionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get floorBoundary => $composableBuilder(
    column: $table.floorBoundary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ceilingBoundary => $composableBuilder(
    column: $table.ceilingBoundary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get floorAdjacentTempC => $composableBuilder(
    column: $table.floorAdjacentTempC,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get ceilingAdjacentTempC => $composableBuilder(
    column: $table.ceilingAdjacentTempC,
    builder: (column) => ColumnOrderings(column),
  );

  $$FloorsTableOrderingComposer get floorId {
    final $$FloorsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.floorId,
      referencedTable: $db.floors,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FloorsTableOrderingComposer(
            $db: $db,
            $table: $db.floors,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RoomsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RoomsTable> {
  $$RoomsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get targetTempC => $composableBuilder(
    column: $table.targetTempC,
    builder: (column) => column,
  );

  GeneratedColumn<double> get airChangeRate => $composableBuilder(
    column: $table.airChangeRate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get polygonJson => $composableBuilder(
    column: $table.polygonJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get floorConstructionId => $composableBuilder(
    column: $table.floorConstructionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ceilingConstructionId => $composableBuilder(
    column: $table.ceilingConstructionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get floorBoundary => $composableBuilder(
    column: $table.floorBoundary,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ceilingBoundary => $composableBuilder(
    column: $table.ceilingBoundary,
    builder: (column) => column,
  );

  GeneratedColumn<double> get floorAdjacentTempC => $composableBuilder(
    column: $table.floorAdjacentTempC,
    builder: (column) => column,
  );

  GeneratedColumn<double> get ceilingAdjacentTempC => $composableBuilder(
    column: $table.ceilingAdjacentTempC,
    builder: (column) => column,
  );

  $$FloorsTableAnnotationComposer get floorId {
    final $$FloorsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.floorId,
      referencedTable: $db.floors,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FloorsTableAnnotationComposer(
            $db: $db,
            $table: $db.floors,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> wallSegments<T extends Object>(
    Expression<T> Function($$WallSegmentsTableAnnotationComposer a) f,
  ) {
    final $$WallSegmentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.wallSegments,
      getReferencedColumn: (t) => t.roomId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WallSegmentsTableAnnotationComposer(
            $db: $db,
            $table: $db.wallSegments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> adjacentWallSegments<T extends Object>(
    Expression<T> Function($$WallSegmentsTableAnnotationComposer a) f,
  ) {
    final $$WallSegmentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.wallSegments,
      getReferencedColumn: (t) => t.adjacentRoomId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WallSegmentsTableAnnotationComposer(
            $db: $db,
            $table: $db.wallSegments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> heatingZonesRefs<T extends Object>(
    Expression<T> Function($$HeatingZonesTableAnnotationComposer a) f,
  ) {
    final $$HeatingZonesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.heatingZones,
      getReferencedColumn: (t) => t.roomId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HeatingZonesTableAnnotationComposer(
            $db: $db,
            $table: $db.heatingZones,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RoomsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RoomsTable,
          Room,
          $$RoomsTableFilterComposer,
          $$RoomsTableOrderingComposer,
          $$RoomsTableAnnotationComposer,
          $$RoomsTableCreateCompanionBuilder,
          $$RoomsTableUpdateCompanionBuilder,
          (Room, $$RoomsTableReferences),
          Room,
          PrefetchHooks Function({
            bool floorId,
            bool wallSegments,
            bool adjacentWallSegments,
            bool heatingZonesRefs,
          })
        > {
  $$RoomsTableTableManager(_$AppDatabase db, $RoomsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RoomsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RoomsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RoomsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> floorId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<double> targetTempC = const Value.absent(),
                Value<double> airChangeRate = const Value.absent(),
                Value<String> polygonJson = const Value.absent(),
                Value<String?> floorConstructionId = const Value.absent(),
                Value<String?> ceilingConstructionId = const Value.absent(),
                Value<String> floorBoundary = const Value.absent(),
                Value<String> ceilingBoundary = const Value.absent(),
                Value<double?> floorAdjacentTempC = const Value.absent(),
                Value<double?> ceilingAdjacentTempC = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RoomsCompanion(
                id: id,
                floorId: floorId,
                name: name,
                targetTempC: targetTempC,
                airChangeRate: airChangeRate,
                polygonJson: polygonJson,
                floorConstructionId: floorConstructionId,
                ceilingConstructionId: ceilingConstructionId,
                floorBoundary: floorBoundary,
                ceilingBoundary: ceilingBoundary,
                floorAdjacentTempC: floorAdjacentTempC,
                ceilingAdjacentTempC: ceilingAdjacentTempC,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String floorId,
                required String name,
                Value<double> targetTempC = const Value.absent(),
                Value<double> airChangeRate = const Value.absent(),
                Value<String> polygonJson = const Value.absent(),
                Value<String?> floorConstructionId = const Value.absent(),
                Value<String?> ceilingConstructionId = const Value.absent(),
                Value<String> floorBoundary = const Value.absent(),
                Value<String> ceilingBoundary = const Value.absent(),
                Value<double?> floorAdjacentTempC = const Value.absent(),
                Value<double?> ceilingAdjacentTempC = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RoomsCompanion.insert(
                id: id,
                floorId: floorId,
                name: name,
                targetTempC: targetTempC,
                airChangeRate: airChangeRate,
                polygonJson: polygonJson,
                floorConstructionId: floorConstructionId,
                ceilingConstructionId: ceilingConstructionId,
                floorBoundary: floorBoundary,
                ceilingBoundary: ceilingBoundary,
                floorAdjacentTempC: floorAdjacentTempC,
                ceilingAdjacentTempC: ceilingAdjacentTempC,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$RoomsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                floorId = false,
                wallSegments = false,
                adjacentWallSegments = false,
                heatingZonesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (wallSegments) db.wallSegments,
                    if (adjacentWallSegments) db.wallSegments,
                    if (heatingZonesRefs) db.heatingZones,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (floorId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.floorId,
                                    referencedTable: $$RoomsTableReferences
                                        ._floorIdTable(db),
                                    referencedColumn: $$RoomsTableReferences
                                        ._floorIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (wallSegments)
                        await $_getPrefetchedData<
                          Room,
                          $RoomsTable,
                          WallSegment
                        >(
                          currentTable: table,
                          referencedTable: $$RoomsTableReferences
                              ._wallSegmentsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RoomsTableReferences(
                                db,
                                table,
                                p0,
                              ).wallSegments,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.roomId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (adjacentWallSegments)
                        await $_getPrefetchedData<
                          Room,
                          $RoomsTable,
                          WallSegment
                        >(
                          currentTable: table,
                          referencedTable: $$RoomsTableReferences
                              ._adjacentWallSegmentsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RoomsTableReferences(
                                db,
                                table,
                                p0,
                              ).adjacentWallSegments,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.adjacentRoomId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (heatingZonesRefs)
                        await $_getPrefetchedData<
                          Room,
                          $RoomsTable,
                          HeatingZone
                        >(
                          currentTable: table,
                          referencedTable: $$RoomsTableReferences
                              ._heatingZonesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RoomsTableReferences(
                                db,
                                table,
                                p0,
                              ).heatingZonesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.roomId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$RoomsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RoomsTable,
      Room,
      $$RoomsTableFilterComposer,
      $$RoomsTableOrderingComposer,
      $$RoomsTableAnnotationComposer,
      $$RoomsTableCreateCompanionBuilder,
      $$RoomsTableUpdateCompanionBuilder,
      (Room, $$RoomsTableReferences),
      Room,
      PrefetchHooks Function({
        bool floorId,
        bool wallSegments,
        bool adjacentWallSegments,
        bool heatingZonesRefs,
      })
    >;
typedef $$WallConstructionsTableCreateCompanionBuilder =
    WallConstructionsCompanion Function({
      required String id,
      required String name,
      Value<double> rsi,
      Value<double> rse,
      Value<int> isPreset,
      Value<int> rowid,
    });
typedef $$WallConstructionsTableUpdateCompanionBuilder =
    WallConstructionsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<double> rsi,
      Value<double> rse,
      Value<int> isPreset,
      Value<int> rowid,
    });

final class $$WallConstructionsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $WallConstructionsTable,
          WallConstruction
        > {
  $$WallConstructionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$WallSegmentsTable, List<WallSegment>>
  _wallSegmentsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.wallSegments,
    aliasName: $_aliasNameGenerator(
      db.wallConstructions.id,
      db.wallSegments.constructionId,
    ),
  );

  $$WallSegmentsTableProcessedTableManager get wallSegmentsRefs {
    final manager = $$WallSegmentsTableTableManager(
      $_db,
      $_db.wallSegments,
    ).filter((f) => f.constructionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_wallSegmentsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$MaterialLayersTable, List<MaterialLayer>>
  _materialLayersRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.materialLayers,
    aliasName: $_aliasNameGenerator(
      db.wallConstructions.id,
      db.materialLayers.constructionId,
    ),
  );

  $$MaterialLayersTableProcessedTableManager get materialLayersRefs {
    final manager = $$MaterialLayersTableTableManager(
      $_db,
      $_db.materialLayers,
    ).filter((f) => f.constructionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_materialLayersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$WallConstructionsTableFilterComposer
    extends Composer<_$AppDatabase, $WallConstructionsTable> {
  $$WallConstructionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get rsi => $composableBuilder(
    column: $table.rsi,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get rse => $composableBuilder(
    column: $table.rse,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get isPreset => $composableBuilder(
    column: $table.isPreset,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> wallSegmentsRefs(
    Expression<bool> Function($$WallSegmentsTableFilterComposer f) f,
  ) {
    final $$WallSegmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.wallSegments,
      getReferencedColumn: (t) => t.constructionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WallSegmentsTableFilterComposer(
            $db: $db,
            $table: $db.wallSegments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> materialLayersRefs(
    Expression<bool> Function($$MaterialLayersTableFilterComposer f) f,
  ) {
    final $$MaterialLayersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.materialLayers,
      getReferencedColumn: (t) => t.constructionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MaterialLayersTableFilterComposer(
            $db: $db,
            $table: $db.materialLayers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WallConstructionsTableOrderingComposer
    extends Composer<_$AppDatabase, $WallConstructionsTable> {
  $$WallConstructionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get rsi => $composableBuilder(
    column: $table.rsi,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get rse => $composableBuilder(
    column: $table.rse,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get isPreset => $composableBuilder(
    column: $table.isPreset,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WallConstructionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WallConstructionsTable> {
  $$WallConstructionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get rsi =>
      $composableBuilder(column: $table.rsi, builder: (column) => column);

  GeneratedColumn<double> get rse =>
      $composableBuilder(column: $table.rse, builder: (column) => column);

  GeneratedColumn<int> get isPreset =>
      $composableBuilder(column: $table.isPreset, builder: (column) => column);

  Expression<T> wallSegmentsRefs<T extends Object>(
    Expression<T> Function($$WallSegmentsTableAnnotationComposer a) f,
  ) {
    final $$WallSegmentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.wallSegments,
      getReferencedColumn: (t) => t.constructionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WallSegmentsTableAnnotationComposer(
            $db: $db,
            $table: $db.wallSegments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> materialLayersRefs<T extends Object>(
    Expression<T> Function($$MaterialLayersTableAnnotationComposer a) f,
  ) {
    final $$MaterialLayersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.materialLayers,
      getReferencedColumn: (t) => t.constructionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MaterialLayersTableAnnotationComposer(
            $db: $db,
            $table: $db.materialLayers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WallConstructionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WallConstructionsTable,
          WallConstruction,
          $$WallConstructionsTableFilterComposer,
          $$WallConstructionsTableOrderingComposer,
          $$WallConstructionsTableAnnotationComposer,
          $$WallConstructionsTableCreateCompanionBuilder,
          $$WallConstructionsTableUpdateCompanionBuilder,
          (WallConstruction, $$WallConstructionsTableReferences),
          WallConstruction,
          PrefetchHooks Function({
            bool wallSegmentsRefs,
            bool materialLayersRefs,
          })
        > {
  $$WallConstructionsTableTableManager(
    _$AppDatabase db,
    $WallConstructionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WallConstructionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WallConstructionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WallConstructionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<double> rsi = const Value.absent(),
                Value<double> rse = const Value.absent(),
                Value<int> isPreset = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WallConstructionsCompanion(
                id: id,
                name: name,
                rsi: rsi,
                rse: rse,
                isPreset: isPreset,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<double> rsi = const Value.absent(),
                Value<double> rse = const Value.absent(),
                Value<int> isPreset = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WallConstructionsCompanion.insert(
                id: id,
                name: name,
                rsi: rsi,
                rse: rse,
                isPreset: isPreset,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$WallConstructionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({wallSegmentsRefs = false, materialLayersRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (wallSegmentsRefs) db.wallSegments,
                    if (materialLayersRefs) db.materialLayers,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (wallSegmentsRefs)
                        await $_getPrefetchedData<
                          WallConstruction,
                          $WallConstructionsTable,
                          WallSegment
                        >(
                          currentTable: table,
                          referencedTable: $$WallConstructionsTableReferences
                              ._wallSegmentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$WallConstructionsTableReferences(
                                db,
                                table,
                                p0,
                              ).wallSegmentsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.constructionId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (materialLayersRefs)
                        await $_getPrefetchedData<
                          WallConstruction,
                          $WallConstructionsTable,
                          MaterialLayer
                        >(
                          currentTable: table,
                          referencedTable: $$WallConstructionsTableReferences
                              ._materialLayersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$WallConstructionsTableReferences(
                                db,
                                table,
                                p0,
                              ).materialLayersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.constructionId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$WallConstructionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WallConstructionsTable,
      WallConstruction,
      $$WallConstructionsTableFilterComposer,
      $$WallConstructionsTableOrderingComposer,
      $$WallConstructionsTableAnnotationComposer,
      $$WallConstructionsTableCreateCompanionBuilder,
      $$WallConstructionsTableUpdateCompanionBuilder,
      (WallConstruction, $$WallConstructionsTableReferences),
      WallConstruction,
      PrefetchHooks Function({bool wallSegmentsRefs, bool materialLayersRefs})
    >;
typedef $$WallSegmentsTableCreateCompanionBuilder =
    WallSegmentsCompanion Function({
      required String id,
      required String roomId,
      required String startPointJson,
      required String endPointJson,
      Value<String> wallType,
      Value<String?> constructionId,
      Value<String?> adjacentRoomId,
      Value<String> orientation,
      Value<String?> mirrorId,
      Value<int> rowid,
    });
typedef $$WallSegmentsTableUpdateCompanionBuilder =
    WallSegmentsCompanion Function({
      Value<String> id,
      Value<String> roomId,
      Value<String> startPointJson,
      Value<String> endPointJson,
      Value<String> wallType,
      Value<String?> constructionId,
      Value<String?> adjacentRoomId,
      Value<String> orientation,
      Value<String?> mirrorId,
      Value<int> rowid,
    });

final class $$WallSegmentsTableReferences
    extends BaseReferences<_$AppDatabase, $WallSegmentsTable, WallSegment> {
  $$WallSegmentsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $RoomsTable _roomIdTable(_$AppDatabase db) => db.rooms.createAlias(
    $_aliasNameGenerator(db.wallSegments.roomId, db.rooms.id),
  );

  $$RoomsTableProcessedTableManager get roomId {
    final $_column = $_itemColumn<String>('room_id')!;

    final manager = $$RoomsTableTableManager(
      $_db,
      $_db.rooms,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_roomIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $WallConstructionsTable _constructionIdTable(_$AppDatabase db) =>
      db.wallConstructions.createAlias(
        $_aliasNameGenerator(
          db.wallSegments.constructionId,
          db.wallConstructions.id,
        ),
      );

  $$WallConstructionsTableProcessedTableManager? get constructionId {
    final $_column = $_itemColumn<String>('construction_id');
    if ($_column == null) return null;
    final manager = $$WallConstructionsTableTableManager(
      $_db,
      $_db.wallConstructions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_constructionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $RoomsTable _adjacentRoomIdTable(_$AppDatabase db) =>
      db.rooms.createAlias(
        $_aliasNameGenerator(db.wallSegments.adjacentRoomId, db.rooms.id),
      );

  $$RoomsTableProcessedTableManager? get adjacentRoomId {
    final $_column = $_itemColumn<String>('adjacent_room_id');
    if ($_column == null) return null;
    final manager = $$RoomsTableTableManager(
      $_db,
      $_db.rooms,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_adjacentRoomIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $WallSegmentsTable _mirrorIdTable(_$AppDatabase db) =>
      db.wallSegments.createAlias(
        $_aliasNameGenerator(db.wallSegments.mirrorId, db.wallSegments.id),
      );

  $$WallSegmentsTableProcessedTableManager? get mirrorId {
    final $_column = $_itemColumn<String>('mirror_id');
    if ($_column == null) return null;
    final manager = $$WallSegmentsTableTableManager(
      $_db,
      $_db.wallSegments,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_mirrorIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$WindowsTable, List<Window>> _windowsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.windows,
    aliasName: $_aliasNameGenerator(
      db.wallSegments.id,
      db.windows.wallSegmentId,
    ),
  );

  $$WindowsTableProcessedTableManager get windowsRefs {
    final manager = $$WindowsTableTableManager(
      $_db,
      $_db.windows,
    ).filter((f) => f.wallSegmentId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_windowsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$DoorsTable, List<Door>> _doorsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.doors,
    aliasName: $_aliasNameGenerator(db.wallSegments.id, db.doors.wallSegmentId),
  );

  $$DoorsTableProcessedTableManager get doorsRefs {
    final manager = $$DoorsTableTableManager(
      $_db,
      $_db.doors,
    ).filter((f) => f.wallSegmentId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_doorsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$HeatingZonesTable, List<HeatingZone>>
  _heatingZonesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.heatingZones,
    aliasName: $_aliasNameGenerator(
      db.wallSegments.id,
      db.heatingZones.wallSegmentId,
    ),
  );

  $$HeatingZonesTableProcessedTableManager get heatingZonesRefs {
    final manager = $$HeatingZonesTableTableManager(
      $_db,
      $_db.heatingZones,
    ).filter((f) => f.wallSegmentId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_heatingZonesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$WallSegmentsTableFilterComposer
    extends Composer<_$AppDatabase, $WallSegmentsTable> {
  $$WallSegmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startPointJson => $composableBuilder(
    column: $table.startPointJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get endPointJson => $composableBuilder(
    column: $table.endPointJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get wallType => $composableBuilder(
    column: $table.wallType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get orientation => $composableBuilder(
    column: $table.orientation,
    builder: (column) => ColumnFilters(column),
  );

  $$RoomsTableFilterComposer get roomId {
    final $$RoomsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.roomId,
      referencedTable: $db.rooms,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RoomsTableFilterComposer(
            $db: $db,
            $table: $db.rooms,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WallConstructionsTableFilterComposer get constructionId {
    final $$WallConstructionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.constructionId,
      referencedTable: $db.wallConstructions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WallConstructionsTableFilterComposer(
            $db: $db,
            $table: $db.wallConstructions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$RoomsTableFilterComposer get adjacentRoomId {
    final $$RoomsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.adjacentRoomId,
      referencedTable: $db.rooms,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RoomsTableFilterComposer(
            $db: $db,
            $table: $db.rooms,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WallSegmentsTableFilterComposer get mirrorId {
    final $$WallSegmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mirrorId,
      referencedTable: $db.wallSegments,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WallSegmentsTableFilterComposer(
            $db: $db,
            $table: $db.wallSegments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> windowsRefs(
    Expression<bool> Function($$WindowsTableFilterComposer f) f,
  ) {
    final $$WindowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.windows,
      getReferencedColumn: (t) => t.wallSegmentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WindowsTableFilterComposer(
            $db: $db,
            $table: $db.windows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> doorsRefs(
    Expression<bool> Function($$DoorsTableFilterComposer f) f,
  ) {
    final $$DoorsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.doors,
      getReferencedColumn: (t) => t.wallSegmentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DoorsTableFilterComposer(
            $db: $db,
            $table: $db.doors,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> heatingZonesRefs(
    Expression<bool> Function($$HeatingZonesTableFilterComposer f) f,
  ) {
    final $$HeatingZonesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.heatingZones,
      getReferencedColumn: (t) => t.wallSegmentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HeatingZonesTableFilterComposer(
            $db: $db,
            $table: $db.heatingZones,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WallSegmentsTableOrderingComposer
    extends Composer<_$AppDatabase, $WallSegmentsTable> {
  $$WallSegmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startPointJson => $composableBuilder(
    column: $table.startPointJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get endPointJson => $composableBuilder(
    column: $table.endPointJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get wallType => $composableBuilder(
    column: $table.wallType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get orientation => $composableBuilder(
    column: $table.orientation,
    builder: (column) => ColumnOrderings(column),
  );

  $$RoomsTableOrderingComposer get roomId {
    final $$RoomsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.roomId,
      referencedTable: $db.rooms,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RoomsTableOrderingComposer(
            $db: $db,
            $table: $db.rooms,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WallConstructionsTableOrderingComposer get constructionId {
    final $$WallConstructionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.constructionId,
      referencedTable: $db.wallConstructions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WallConstructionsTableOrderingComposer(
            $db: $db,
            $table: $db.wallConstructions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$RoomsTableOrderingComposer get adjacentRoomId {
    final $$RoomsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.adjacentRoomId,
      referencedTable: $db.rooms,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RoomsTableOrderingComposer(
            $db: $db,
            $table: $db.rooms,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WallSegmentsTableOrderingComposer get mirrorId {
    final $$WallSegmentsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mirrorId,
      referencedTable: $db.wallSegments,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WallSegmentsTableOrderingComposer(
            $db: $db,
            $table: $db.wallSegments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WallSegmentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WallSegmentsTable> {
  $$WallSegmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get startPointJson => $composableBuilder(
    column: $table.startPointJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get endPointJson => $composableBuilder(
    column: $table.endPointJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get wallType =>
      $composableBuilder(column: $table.wallType, builder: (column) => column);

  GeneratedColumn<String> get orientation => $composableBuilder(
    column: $table.orientation,
    builder: (column) => column,
  );

  $$RoomsTableAnnotationComposer get roomId {
    final $$RoomsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.roomId,
      referencedTable: $db.rooms,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RoomsTableAnnotationComposer(
            $db: $db,
            $table: $db.rooms,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WallConstructionsTableAnnotationComposer get constructionId {
    final $$WallConstructionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.constructionId,
          referencedTable: $db.wallConstructions,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$WallConstructionsTableAnnotationComposer(
                $db: $db,
                $table: $db.wallConstructions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  $$RoomsTableAnnotationComposer get adjacentRoomId {
    final $$RoomsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.adjacentRoomId,
      referencedTable: $db.rooms,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RoomsTableAnnotationComposer(
            $db: $db,
            $table: $db.rooms,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WallSegmentsTableAnnotationComposer get mirrorId {
    final $$WallSegmentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mirrorId,
      referencedTable: $db.wallSegments,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WallSegmentsTableAnnotationComposer(
            $db: $db,
            $table: $db.wallSegments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> windowsRefs<T extends Object>(
    Expression<T> Function($$WindowsTableAnnotationComposer a) f,
  ) {
    final $$WindowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.windows,
      getReferencedColumn: (t) => t.wallSegmentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WindowsTableAnnotationComposer(
            $db: $db,
            $table: $db.windows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> doorsRefs<T extends Object>(
    Expression<T> Function($$DoorsTableAnnotationComposer a) f,
  ) {
    final $$DoorsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.doors,
      getReferencedColumn: (t) => t.wallSegmentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DoorsTableAnnotationComposer(
            $db: $db,
            $table: $db.doors,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> heatingZonesRefs<T extends Object>(
    Expression<T> Function($$HeatingZonesTableAnnotationComposer a) f,
  ) {
    final $$HeatingZonesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.heatingZones,
      getReferencedColumn: (t) => t.wallSegmentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HeatingZonesTableAnnotationComposer(
            $db: $db,
            $table: $db.heatingZones,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WallSegmentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WallSegmentsTable,
          WallSegment,
          $$WallSegmentsTableFilterComposer,
          $$WallSegmentsTableOrderingComposer,
          $$WallSegmentsTableAnnotationComposer,
          $$WallSegmentsTableCreateCompanionBuilder,
          $$WallSegmentsTableUpdateCompanionBuilder,
          (WallSegment, $$WallSegmentsTableReferences),
          WallSegment,
          PrefetchHooks Function({
            bool roomId,
            bool constructionId,
            bool adjacentRoomId,
            bool mirrorId,
            bool windowsRefs,
            bool doorsRefs,
            bool heatingZonesRefs,
          })
        > {
  $$WallSegmentsTableTableManager(_$AppDatabase db, $WallSegmentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WallSegmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WallSegmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WallSegmentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> roomId = const Value.absent(),
                Value<String> startPointJson = const Value.absent(),
                Value<String> endPointJson = const Value.absent(),
                Value<String> wallType = const Value.absent(),
                Value<String?> constructionId = const Value.absent(),
                Value<String?> adjacentRoomId = const Value.absent(),
                Value<String> orientation = const Value.absent(),
                Value<String?> mirrorId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WallSegmentsCompanion(
                id: id,
                roomId: roomId,
                startPointJson: startPointJson,
                endPointJson: endPointJson,
                wallType: wallType,
                constructionId: constructionId,
                adjacentRoomId: adjacentRoomId,
                orientation: orientation,
                mirrorId: mirrorId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String roomId,
                required String startPointJson,
                required String endPointJson,
                Value<String> wallType = const Value.absent(),
                Value<String?> constructionId = const Value.absent(),
                Value<String?> adjacentRoomId = const Value.absent(),
                Value<String> orientation = const Value.absent(),
                Value<String?> mirrorId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WallSegmentsCompanion.insert(
                id: id,
                roomId: roomId,
                startPointJson: startPointJson,
                endPointJson: endPointJson,
                wallType: wallType,
                constructionId: constructionId,
                adjacentRoomId: adjacentRoomId,
                orientation: orientation,
                mirrorId: mirrorId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$WallSegmentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                roomId = false,
                constructionId = false,
                adjacentRoomId = false,
                mirrorId = false,
                windowsRefs = false,
                doorsRefs = false,
                heatingZonesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (windowsRefs) db.windows,
                    if (doorsRefs) db.doors,
                    if (heatingZonesRefs) db.heatingZones,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (roomId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.roomId,
                                    referencedTable:
                                        $$WallSegmentsTableReferences
                                            ._roomIdTable(db),
                                    referencedColumn:
                                        $$WallSegmentsTableReferences
                                            ._roomIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (constructionId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.constructionId,
                                    referencedTable:
                                        $$WallSegmentsTableReferences
                                            ._constructionIdTable(db),
                                    referencedColumn:
                                        $$WallSegmentsTableReferences
                                            ._constructionIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (adjacentRoomId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.adjacentRoomId,
                                    referencedTable:
                                        $$WallSegmentsTableReferences
                                            ._adjacentRoomIdTable(db),
                                    referencedColumn:
                                        $$WallSegmentsTableReferences
                                            ._adjacentRoomIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (mirrorId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.mirrorId,
                                    referencedTable:
                                        $$WallSegmentsTableReferences
                                            ._mirrorIdTable(db),
                                    referencedColumn:
                                        $$WallSegmentsTableReferences
                                            ._mirrorIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (windowsRefs)
                        await $_getPrefetchedData<
                          WallSegment,
                          $WallSegmentsTable,
                          Window
                        >(
                          currentTable: table,
                          referencedTable: $$WallSegmentsTableReferences
                              ._windowsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$WallSegmentsTableReferences(
                                db,
                                table,
                                p0,
                              ).windowsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.wallSegmentId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (doorsRefs)
                        await $_getPrefetchedData<
                          WallSegment,
                          $WallSegmentsTable,
                          Door
                        >(
                          currentTable: table,
                          referencedTable: $$WallSegmentsTableReferences
                              ._doorsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$WallSegmentsTableReferences(
                                db,
                                table,
                                p0,
                              ).doorsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.wallSegmentId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (heatingZonesRefs)
                        await $_getPrefetchedData<
                          WallSegment,
                          $WallSegmentsTable,
                          HeatingZone
                        >(
                          currentTable: table,
                          referencedTable: $$WallSegmentsTableReferences
                              ._heatingZonesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$WallSegmentsTableReferences(
                                db,
                                table,
                                p0,
                              ).heatingZonesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.wallSegmentId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$WallSegmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WallSegmentsTable,
      WallSegment,
      $$WallSegmentsTableFilterComposer,
      $$WallSegmentsTableOrderingComposer,
      $$WallSegmentsTableAnnotationComposer,
      $$WallSegmentsTableCreateCompanionBuilder,
      $$WallSegmentsTableUpdateCompanionBuilder,
      (WallSegment, $$WallSegmentsTableReferences),
      WallSegment,
      PrefetchHooks Function({
        bool roomId,
        bool constructionId,
        bool adjacentRoomId,
        bool mirrorId,
        bool windowsRefs,
        bool doorsRefs,
        bool heatingZonesRefs,
      })
    >;
typedef $$WindowsTableCreateCompanionBuilder =
    WindowsCompanion Function({
      required String id,
      required String wallSegmentId,
      required double positionOnWallMm,
      Value<int> widthMm,
      Value<int> heightMm,
      Value<int> sillHeightMm,
      Value<double> uValue,
      Value<int> rowid,
    });
typedef $$WindowsTableUpdateCompanionBuilder =
    WindowsCompanion Function({
      Value<String> id,
      Value<String> wallSegmentId,
      Value<double> positionOnWallMm,
      Value<int> widthMm,
      Value<int> heightMm,
      Value<int> sillHeightMm,
      Value<double> uValue,
      Value<int> rowid,
    });

final class $$WindowsTableReferences
    extends BaseReferences<_$AppDatabase, $WindowsTable, Window> {
  $$WindowsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $WallSegmentsTable _wallSegmentIdTable(_$AppDatabase db) =>
      db.wallSegments.createAlias(
        $_aliasNameGenerator(db.windows.wallSegmentId, db.wallSegments.id),
      );

  $$WallSegmentsTableProcessedTableManager get wallSegmentId {
    final $_column = $_itemColumn<String>('wall_segment_id')!;

    final manager = $$WallSegmentsTableTableManager(
      $_db,
      $_db.wallSegments,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_wallSegmentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$WindowsTableFilterComposer
    extends Composer<_$AppDatabase, $WindowsTable> {
  $$WindowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get positionOnWallMm => $composableBuilder(
    column: $table.positionOnWallMm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get widthMm => $composableBuilder(
    column: $table.widthMm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get heightMm => $composableBuilder(
    column: $table.heightMm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sillHeightMm => $composableBuilder(
    column: $table.sillHeightMm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get uValue => $composableBuilder(
    column: $table.uValue,
    builder: (column) => ColumnFilters(column),
  );

  $$WallSegmentsTableFilterComposer get wallSegmentId {
    final $$WallSegmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.wallSegmentId,
      referencedTable: $db.wallSegments,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WallSegmentsTableFilterComposer(
            $db: $db,
            $table: $db.wallSegments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WindowsTableOrderingComposer
    extends Composer<_$AppDatabase, $WindowsTable> {
  $$WindowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get positionOnWallMm => $composableBuilder(
    column: $table.positionOnWallMm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get widthMm => $composableBuilder(
    column: $table.widthMm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get heightMm => $composableBuilder(
    column: $table.heightMm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sillHeightMm => $composableBuilder(
    column: $table.sillHeightMm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get uValue => $composableBuilder(
    column: $table.uValue,
    builder: (column) => ColumnOrderings(column),
  );

  $$WallSegmentsTableOrderingComposer get wallSegmentId {
    final $$WallSegmentsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.wallSegmentId,
      referencedTable: $db.wallSegments,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WallSegmentsTableOrderingComposer(
            $db: $db,
            $table: $db.wallSegments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WindowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WindowsTable> {
  $$WindowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get positionOnWallMm => $composableBuilder(
    column: $table.positionOnWallMm,
    builder: (column) => column,
  );

  GeneratedColumn<int> get widthMm =>
      $composableBuilder(column: $table.widthMm, builder: (column) => column);

  GeneratedColumn<int> get heightMm =>
      $composableBuilder(column: $table.heightMm, builder: (column) => column);

  GeneratedColumn<int> get sillHeightMm => $composableBuilder(
    column: $table.sillHeightMm,
    builder: (column) => column,
  );

  GeneratedColumn<double> get uValue =>
      $composableBuilder(column: $table.uValue, builder: (column) => column);

  $$WallSegmentsTableAnnotationComposer get wallSegmentId {
    final $$WallSegmentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.wallSegmentId,
      referencedTable: $db.wallSegments,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WallSegmentsTableAnnotationComposer(
            $db: $db,
            $table: $db.wallSegments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WindowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WindowsTable,
          Window,
          $$WindowsTableFilterComposer,
          $$WindowsTableOrderingComposer,
          $$WindowsTableAnnotationComposer,
          $$WindowsTableCreateCompanionBuilder,
          $$WindowsTableUpdateCompanionBuilder,
          (Window, $$WindowsTableReferences),
          Window,
          PrefetchHooks Function({bool wallSegmentId})
        > {
  $$WindowsTableTableManager(_$AppDatabase db, $WindowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WindowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WindowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WindowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> wallSegmentId = const Value.absent(),
                Value<double> positionOnWallMm = const Value.absent(),
                Value<int> widthMm = const Value.absent(),
                Value<int> heightMm = const Value.absent(),
                Value<int> sillHeightMm = const Value.absent(),
                Value<double> uValue = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WindowsCompanion(
                id: id,
                wallSegmentId: wallSegmentId,
                positionOnWallMm: positionOnWallMm,
                widthMm: widthMm,
                heightMm: heightMm,
                sillHeightMm: sillHeightMm,
                uValue: uValue,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String wallSegmentId,
                required double positionOnWallMm,
                Value<int> widthMm = const Value.absent(),
                Value<int> heightMm = const Value.absent(),
                Value<int> sillHeightMm = const Value.absent(),
                Value<double> uValue = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WindowsCompanion.insert(
                id: id,
                wallSegmentId: wallSegmentId,
                positionOnWallMm: positionOnWallMm,
                widthMm: widthMm,
                heightMm: heightMm,
                sillHeightMm: sillHeightMm,
                uValue: uValue,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$WindowsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({wallSegmentId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (wallSegmentId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.wallSegmentId,
                                referencedTable: $$WindowsTableReferences
                                    ._wallSegmentIdTable(db),
                                referencedColumn: $$WindowsTableReferences
                                    ._wallSegmentIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$WindowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WindowsTable,
      Window,
      $$WindowsTableFilterComposer,
      $$WindowsTableOrderingComposer,
      $$WindowsTableAnnotationComposer,
      $$WindowsTableCreateCompanionBuilder,
      $$WindowsTableUpdateCompanionBuilder,
      (Window, $$WindowsTableReferences),
      Window,
      PrefetchHooks Function({bool wallSegmentId})
    >;
typedef $$DoorsTableCreateCompanionBuilder =
    DoorsCompanion Function({
      required String id,
      required String wallSegmentId,
      required double positionOnWallMm,
      Value<int> widthMm,
      Value<int> heightMm,
      Value<int> sillHeightMm,
      Value<double> uValue,
      Value<int> rowid,
    });
typedef $$DoorsTableUpdateCompanionBuilder =
    DoorsCompanion Function({
      Value<String> id,
      Value<String> wallSegmentId,
      Value<double> positionOnWallMm,
      Value<int> widthMm,
      Value<int> heightMm,
      Value<int> sillHeightMm,
      Value<double> uValue,
      Value<int> rowid,
    });

final class $$DoorsTableReferences
    extends BaseReferences<_$AppDatabase, $DoorsTable, Door> {
  $$DoorsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $WallSegmentsTable _wallSegmentIdTable(_$AppDatabase db) =>
      db.wallSegments.createAlias(
        $_aliasNameGenerator(db.doors.wallSegmentId, db.wallSegments.id),
      );

  $$WallSegmentsTableProcessedTableManager get wallSegmentId {
    final $_column = $_itemColumn<String>('wall_segment_id')!;

    final manager = $$WallSegmentsTableTableManager(
      $_db,
      $_db.wallSegments,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_wallSegmentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DoorsTableFilterComposer extends Composer<_$AppDatabase, $DoorsTable> {
  $$DoorsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get positionOnWallMm => $composableBuilder(
    column: $table.positionOnWallMm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get widthMm => $composableBuilder(
    column: $table.widthMm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get heightMm => $composableBuilder(
    column: $table.heightMm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sillHeightMm => $composableBuilder(
    column: $table.sillHeightMm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get uValue => $composableBuilder(
    column: $table.uValue,
    builder: (column) => ColumnFilters(column),
  );

  $$WallSegmentsTableFilterComposer get wallSegmentId {
    final $$WallSegmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.wallSegmentId,
      referencedTable: $db.wallSegments,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WallSegmentsTableFilterComposer(
            $db: $db,
            $table: $db.wallSegments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DoorsTableOrderingComposer
    extends Composer<_$AppDatabase, $DoorsTable> {
  $$DoorsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get positionOnWallMm => $composableBuilder(
    column: $table.positionOnWallMm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get widthMm => $composableBuilder(
    column: $table.widthMm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get heightMm => $composableBuilder(
    column: $table.heightMm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sillHeightMm => $composableBuilder(
    column: $table.sillHeightMm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get uValue => $composableBuilder(
    column: $table.uValue,
    builder: (column) => ColumnOrderings(column),
  );

  $$WallSegmentsTableOrderingComposer get wallSegmentId {
    final $$WallSegmentsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.wallSegmentId,
      referencedTable: $db.wallSegments,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WallSegmentsTableOrderingComposer(
            $db: $db,
            $table: $db.wallSegments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DoorsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DoorsTable> {
  $$DoorsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get positionOnWallMm => $composableBuilder(
    column: $table.positionOnWallMm,
    builder: (column) => column,
  );

  GeneratedColumn<int> get widthMm =>
      $composableBuilder(column: $table.widthMm, builder: (column) => column);

  GeneratedColumn<int> get heightMm =>
      $composableBuilder(column: $table.heightMm, builder: (column) => column);

  GeneratedColumn<int> get sillHeightMm => $composableBuilder(
    column: $table.sillHeightMm,
    builder: (column) => column,
  );

  GeneratedColumn<double> get uValue =>
      $composableBuilder(column: $table.uValue, builder: (column) => column);

  $$WallSegmentsTableAnnotationComposer get wallSegmentId {
    final $$WallSegmentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.wallSegmentId,
      referencedTable: $db.wallSegments,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WallSegmentsTableAnnotationComposer(
            $db: $db,
            $table: $db.wallSegments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DoorsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DoorsTable,
          Door,
          $$DoorsTableFilterComposer,
          $$DoorsTableOrderingComposer,
          $$DoorsTableAnnotationComposer,
          $$DoorsTableCreateCompanionBuilder,
          $$DoorsTableUpdateCompanionBuilder,
          (Door, $$DoorsTableReferences),
          Door,
          PrefetchHooks Function({bool wallSegmentId})
        > {
  $$DoorsTableTableManager(_$AppDatabase db, $DoorsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DoorsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DoorsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DoorsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> wallSegmentId = const Value.absent(),
                Value<double> positionOnWallMm = const Value.absent(),
                Value<int> widthMm = const Value.absent(),
                Value<int> heightMm = const Value.absent(),
                Value<int> sillHeightMm = const Value.absent(),
                Value<double> uValue = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DoorsCompanion(
                id: id,
                wallSegmentId: wallSegmentId,
                positionOnWallMm: positionOnWallMm,
                widthMm: widthMm,
                heightMm: heightMm,
                sillHeightMm: sillHeightMm,
                uValue: uValue,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String wallSegmentId,
                required double positionOnWallMm,
                Value<int> widthMm = const Value.absent(),
                Value<int> heightMm = const Value.absent(),
                Value<int> sillHeightMm = const Value.absent(),
                Value<double> uValue = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DoorsCompanion.insert(
                id: id,
                wallSegmentId: wallSegmentId,
                positionOnWallMm: positionOnWallMm,
                widthMm: widthMm,
                heightMm: heightMm,
                sillHeightMm: sillHeightMm,
                uValue: uValue,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$DoorsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({wallSegmentId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (wallSegmentId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.wallSegmentId,
                                referencedTable: $$DoorsTableReferences
                                    ._wallSegmentIdTable(db),
                                referencedColumn: $$DoorsTableReferences
                                    ._wallSegmentIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$DoorsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DoorsTable,
      Door,
      $$DoorsTableFilterComposer,
      $$DoorsTableOrderingComposer,
      $$DoorsTableAnnotationComposer,
      $$DoorsTableCreateCompanionBuilder,
      $$DoorsTableUpdateCompanionBuilder,
      (Door, $$DoorsTableReferences),
      Door,
      PrefetchHooks Function({bool wallSegmentId})
    >;
typedef $$MaterialEntriesTableCreateCompanionBuilder =
    MaterialEntriesCompanion Function({
      required String id,
      required String name,
      required String category,
      Value<String> subcategory,
      required double lambdaDefault,
      required double densityDefault,
      required double specificHeatDefault,
      Value<bool> isBuiltIn,
      Value<int> rowid,
    });
typedef $$MaterialEntriesTableUpdateCompanionBuilder =
    MaterialEntriesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> category,
      Value<String> subcategory,
      Value<double> lambdaDefault,
      Value<double> densityDefault,
      Value<double> specificHeatDefault,
      Value<bool> isBuiltIn,
      Value<int> rowid,
    });

final class $$MaterialEntriesTableReferences
    extends
        BaseReferences<_$AppDatabase, $MaterialEntriesTable, MaterialEntry> {
  $$MaterialEntriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$MaterialLayersTable, List<MaterialLayer>>
  _materialLayersRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.materialLayers,
    aliasName: $_aliasNameGenerator(
      db.materialEntries.id,
      db.materialLayers.materialId,
    ),
  );

  $$MaterialLayersTableProcessedTableManager get materialLayersRefs {
    final manager = $$MaterialLayersTableTableManager(
      $_db,
      $_db.materialLayers,
    ).filter((f) => f.materialId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_materialLayersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$MaterialEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $MaterialEntriesTable> {
  $$MaterialEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subcategory => $composableBuilder(
    column: $table.subcategory,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lambdaDefault => $composableBuilder(
    column: $table.lambdaDefault,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get densityDefault => $composableBuilder(
    column: $table.densityDefault,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get specificHeatDefault => $composableBuilder(
    column: $table.specificHeatDefault,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isBuiltIn => $composableBuilder(
    column: $table.isBuiltIn,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> materialLayersRefs(
    Expression<bool> Function($$MaterialLayersTableFilterComposer f) f,
  ) {
    final $$MaterialLayersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.materialLayers,
      getReferencedColumn: (t) => t.materialId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MaterialLayersTableFilterComposer(
            $db: $db,
            $table: $db.materialLayers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MaterialEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $MaterialEntriesTable> {
  $$MaterialEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subcategory => $composableBuilder(
    column: $table.subcategory,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lambdaDefault => $composableBuilder(
    column: $table.lambdaDefault,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get densityDefault => $composableBuilder(
    column: $table.densityDefault,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get specificHeatDefault => $composableBuilder(
    column: $table.specificHeatDefault,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isBuiltIn => $composableBuilder(
    column: $table.isBuiltIn,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MaterialEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MaterialEntriesTable> {
  $$MaterialEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get subcategory => $composableBuilder(
    column: $table.subcategory,
    builder: (column) => column,
  );

  GeneratedColumn<double> get lambdaDefault => $composableBuilder(
    column: $table.lambdaDefault,
    builder: (column) => column,
  );

  GeneratedColumn<double> get densityDefault => $composableBuilder(
    column: $table.densityDefault,
    builder: (column) => column,
  );

  GeneratedColumn<double> get specificHeatDefault => $composableBuilder(
    column: $table.specificHeatDefault,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isBuiltIn =>
      $composableBuilder(column: $table.isBuiltIn, builder: (column) => column);

  Expression<T> materialLayersRefs<T extends Object>(
    Expression<T> Function($$MaterialLayersTableAnnotationComposer a) f,
  ) {
    final $$MaterialLayersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.materialLayers,
      getReferencedColumn: (t) => t.materialId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MaterialLayersTableAnnotationComposer(
            $db: $db,
            $table: $db.materialLayers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MaterialEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MaterialEntriesTable,
          MaterialEntry,
          $$MaterialEntriesTableFilterComposer,
          $$MaterialEntriesTableOrderingComposer,
          $$MaterialEntriesTableAnnotationComposer,
          $$MaterialEntriesTableCreateCompanionBuilder,
          $$MaterialEntriesTableUpdateCompanionBuilder,
          (MaterialEntry, $$MaterialEntriesTableReferences),
          MaterialEntry,
          PrefetchHooks Function({bool materialLayersRefs})
        > {
  $$MaterialEntriesTableTableManager(
    _$AppDatabase db,
    $MaterialEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MaterialEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MaterialEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MaterialEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String> subcategory = const Value.absent(),
                Value<double> lambdaDefault = const Value.absent(),
                Value<double> densityDefault = const Value.absent(),
                Value<double> specificHeatDefault = const Value.absent(),
                Value<bool> isBuiltIn = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MaterialEntriesCompanion(
                id: id,
                name: name,
                category: category,
                subcategory: subcategory,
                lambdaDefault: lambdaDefault,
                densityDefault: densityDefault,
                specificHeatDefault: specificHeatDefault,
                isBuiltIn: isBuiltIn,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String category,
                Value<String> subcategory = const Value.absent(),
                required double lambdaDefault,
                required double densityDefault,
                required double specificHeatDefault,
                Value<bool> isBuiltIn = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MaterialEntriesCompanion.insert(
                id: id,
                name: name,
                category: category,
                subcategory: subcategory,
                lambdaDefault: lambdaDefault,
                densityDefault: densityDefault,
                specificHeatDefault: specificHeatDefault,
                isBuiltIn: isBuiltIn,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MaterialEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({materialLayersRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (materialLayersRefs) db.materialLayers,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (materialLayersRefs)
                    await $_getPrefetchedData<
                      MaterialEntry,
                      $MaterialEntriesTable,
                      MaterialLayer
                    >(
                      currentTable: table,
                      referencedTable: $$MaterialEntriesTableReferences
                          ._materialLayersRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$MaterialEntriesTableReferences(
                            db,
                            table,
                            p0,
                          ).materialLayersRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.materialId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$MaterialEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MaterialEntriesTable,
      MaterialEntry,
      $$MaterialEntriesTableFilterComposer,
      $$MaterialEntriesTableOrderingComposer,
      $$MaterialEntriesTableAnnotationComposer,
      $$MaterialEntriesTableCreateCompanionBuilder,
      $$MaterialEntriesTableUpdateCompanionBuilder,
      (MaterialEntry, $$MaterialEntriesTableReferences),
      MaterialEntry,
      PrefetchHooks Function({bool materialLayersRefs})
    >;
typedef $$MaterialLayersTableCreateCompanionBuilder =
    MaterialLayersCompanion Function({
      required String id,
      required String constructionId,
      required int sortOrder,
      required String materialId,
      required double thicknessMm,
      required double thermalConductivity,
      required double density,
      required double specificHeat,
      Value<double?> studWidthMm,
      Value<double?> studClearGapMm,
      Value<double?> studLambda,
      Value<int> rowid,
    });
typedef $$MaterialLayersTableUpdateCompanionBuilder =
    MaterialLayersCompanion Function({
      Value<String> id,
      Value<String> constructionId,
      Value<int> sortOrder,
      Value<String> materialId,
      Value<double> thicknessMm,
      Value<double> thermalConductivity,
      Value<double> density,
      Value<double> specificHeat,
      Value<double?> studWidthMm,
      Value<double?> studClearGapMm,
      Value<double?> studLambda,
      Value<int> rowid,
    });

final class $$MaterialLayersTableReferences
    extends BaseReferences<_$AppDatabase, $MaterialLayersTable, MaterialLayer> {
  $$MaterialLayersTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $WallConstructionsTable _constructionIdTable(_$AppDatabase db) =>
      db.wallConstructions.createAlias(
        $_aliasNameGenerator(
          db.materialLayers.constructionId,
          db.wallConstructions.id,
        ),
      );

  $$WallConstructionsTableProcessedTableManager get constructionId {
    final $_column = $_itemColumn<String>('construction_id')!;

    final manager = $$WallConstructionsTableTableManager(
      $_db,
      $_db.wallConstructions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_constructionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $MaterialEntriesTable _materialIdTable(_$AppDatabase db) =>
      db.materialEntries.createAlias(
        $_aliasNameGenerator(
          db.materialLayers.materialId,
          db.materialEntries.id,
        ),
      );

  $$MaterialEntriesTableProcessedTableManager get materialId {
    final $_column = $_itemColumn<String>('material_id')!;

    final manager = $$MaterialEntriesTableTableManager(
      $_db,
      $_db.materialEntries,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_materialIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MaterialLayersTableFilterComposer
    extends Composer<_$AppDatabase, $MaterialLayersTable> {
  $$MaterialLayersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get thicknessMm => $composableBuilder(
    column: $table.thicknessMm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get thermalConductivity => $composableBuilder(
    column: $table.thermalConductivity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get density => $composableBuilder(
    column: $table.density,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get specificHeat => $composableBuilder(
    column: $table.specificHeat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get studWidthMm => $composableBuilder(
    column: $table.studWidthMm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get studClearGapMm => $composableBuilder(
    column: $table.studClearGapMm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get studLambda => $composableBuilder(
    column: $table.studLambda,
    builder: (column) => ColumnFilters(column),
  );

  $$WallConstructionsTableFilterComposer get constructionId {
    final $$WallConstructionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.constructionId,
      referencedTable: $db.wallConstructions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WallConstructionsTableFilterComposer(
            $db: $db,
            $table: $db.wallConstructions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$MaterialEntriesTableFilterComposer get materialId {
    final $$MaterialEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.materialId,
      referencedTable: $db.materialEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MaterialEntriesTableFilterComposer(
            $db: $db,
            $table: $db.materialEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MaterialLayersTableOrderingComposer
    extends Composer<_$AppDatabase, $MaterialLayersTable> {
  $$MaterialLayersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get thicknessMm => $composableBuilder(
    column: $table.thicknessMm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get thermalConductivity => $composableBuilder(
    column: $table.thermalConductivity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get density => $composableBuilder(
    column: $table.density,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get specificHeat => $composableBuilder(
    column: $table.specificHeat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get studWidthMm => $composableBuilder(
    column: $table.studWidthMm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get studClearGapMm => $composableBuilder(
    column: $table.studClearGapMm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get studLambda => $composableBuilder(
    column: $table.studLambda,
    builder: (column) => ColumnOrderings(column),
  );

  $$WallConstructionsTableOrderingComposer get constructionId {
    final $$WallConstructionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.constructionId,
      referencedTable: $db.wallConstructions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WallConstructionsTableOrderingComposer(
            $db: $db,
            $table: $db.wallConstructions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$MaterialEntriesTableOrderingComposer get materialId {
    final $$MaterialEntriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.materialId,
      referencedTable: $db.materialEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MaterialEntriesTableOrderingComposer(
            $db: $db,
            $table: $db.materialEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MaterialLayersTableAnnotationComposer
    extends Composer<_$AppDatabase, $MaterialLayersTable> {
  $$MaterialLayersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<double> get thicknessMm => $composableBuilder(
    column: $table.thicknessMm,
    builder: (column) => column,
  );

  GeneratedColumn<double> get thermalConductivity => $composableBuilder(
    column: $table.thermalConductivity,
    builder: (column) => column,
  );

  GeneratedColumn<double> get density =>
      $composableBuilder(column: $table.density, builder: (column) => column);

  GeneratedColumn<double> get specificHeat => $composableBuilder(
    column: $table.specificHeat,
    builder: (column) => column,
  );

  GeneratedColumn<double> get studWidthMm => $composableBuilder(
    column: $table.studWidthMm,
    builder: (column) => column,
  );

  GeneratedColumn<double> get studClearGapMm => $composableBuilder(
    column: $table.studClearGapMm,
    builder: (column) => column,
  );

  GeneratedColumn<double> get studLambda => $composableBuilder(
    column: $table.studLambda,
    builder: (column) => column,
  );

  $$WallConstructionsTableAnnotationComposer get constructionId {
    final $$WallConstructionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.constructionId,
          referencedTable: $db.wallConstructions,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$WallConstructionsTableAnnotationComposer(
                $db: $db,
                $table: $db.wallConstructions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  $$MaterialEntriesTableAnnotationComposer get materialId {
    final $$MaterialEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.materialId,
      referencedTable: $db.materialEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MaterialEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.materialEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MaterialLayersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MaterialLayersTable,
          MaterialLayer,
          $$MaterialLayersTableFilterComposer,
          $$MaterialLayersTableOrderingComposer,
          $$MaterialLayersTableAnnotationComposer,
          $$MaterialLayersTableCreateCompanionBuilder,
          $$MaterialLayersTableUpdateCompanionBuilder,
          (MaterialLayer, $$MaterialLayersTableReferences),
          MaterialLayer,
          PrefetchHooks Function({bool constructionId, bool materialId})
        > {
  $$MaterialLayersTableTableManager(
    _$AppDatabase db,
    $MaterialLayersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MaterialLayersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MaterialLayersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MaterialLayersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> constructionId = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String> materialId = const Value.absent(),
                Value<double> thicknessMm = const Value.absent(),
                Value<double> thermalConductivity = const Value.absent(),
                Value<double> density = const Value.absent(),
                Value<double> specificHeat = const Value.absent(),
                Value<double?> studWidthMm = const Value.absent(),
                Value<double?> studClearGapMm = const Value.absent(),
                Value<double?> studLambda = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MaterialLayersCompanion(
                id: id,
                constructionId: constructionId,
                sortOrder: sortOrder,
                materialId: materialId,
                thicknessMm: thicknessMm,
                thermalConductivity: thermalConductivity,
                density: density,
                specificHeat: specificHeat,
                studWidthMm: studWidthMm,
                studClearGapMm: studClearGapMm,
                studLambda: studLambda,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String constructionId,
                required int sortOrder,
                required String materialId,
                required double thicknessMm,
                required double thermalConductivity,
                required double density,
                required double specificHeat,
                Value<double?> studWidthMm = const Value.absent(),
                Value<double?> studClearGapMm = const Value.absent(),
                Value<double?> studLambda = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MaterialLayersCompanion.insert(
                id: id,
                constructionId: constructionId,
                sortOrder: sortOrder,
                materialId: materialId,
                thicknessMm: thicknessMm,
                thermalConductivity: thermalConductivity,
                density: density,
                specificHeat: specificHeat,
                studWidthMm: studWidthMm,
                studClearGapMm: studClearGapMm,
                studLambda: studLambda,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MaterialLayersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({constructionId = false, materialId = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (constructionId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.constructionId,
                                    referencedTable:
                                        $$MaterialLayersTableReferences
                                            ._constructionIdTable(db),
                                    referencedColumn:
                                        $$MaterialLayersTableReferences
                                            ._constructionIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (materialId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.materialId,
                                    referencedTable:
                                        $$MaterialLayersTableReferences
                                            ._materialIdTable(db),
                                    referencedColumn:
                                        $$MaterialLayersTableReferences
                                            ._materialIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [];
                  },
                );
              },
        ),
      );
}

typedef $$MaterialLayersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MaterialLayersTable,
      MaterialLayer,
      $$MaterialLayersTableFilterComposer,
      $$MaterialLayersTableOrderingComposer,
      $$MaterialLayersTableAnnotationComposer,
      $$MaterialLayersTableCreateCompanionBuilder,
      $$MaterialLayersTableUpdateCompanionBuilder,
      (MaterialLayer, $$MaterialLayersTableReferences),
      MaterialLayer,
      PrefetchHooks Function({bool constructionId, bool materialId})
    >;
typedef $$TubeTypesTableCreateCompanionBuilder =
    TubeTypesCompanion Function({
      required String id,
      required String name,
      required String material,
      Value<double> outerDiameterMm,
      Value<double> innerDiameterMm,
      Value<double> wallThicknessMm,
      Value<double> thermalConductivity,
      Value<double> roughness,
      Value<double> maxOperatingTempC,
      Value<double> maxOperatingPressure,
      Value<int> rowid,
    });
typedef $$TubeTypesTableUpdateCompanionBuilder =
    TubeTypesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> material,
      Value<double> outerDiameterMm,
      Value<double> innerDiameterMm,
      Value<double> wallThicknessMm,
      Value<double> thermalConductivity,
      Value<double> roughness,
      Value<double> maxOperatingTempC,
      Value<double> maxOperatingPressure,
      Value<int> rowid,
    });

final class $$TubeTypesTableReferences
    extends BaseReferences<_$AppDatabase, $TubeTypesTable, TubeType> {
  $$TubeTypesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$HeatingZonesTable, List<HeatingZone>>
  _heatingZonesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.heatingZones,
    aliasName: $_aliasNameGenerator(
      db.tubeTypes.id,
      db.heatingZones.tubeTypeId,
    ),
  );

  $$HeatingZonesTableProcessedTableManager get heatingZonesRefs {
    final manager = $$HeatingZonesTableTableManager(
      $_db,
      $_db.heatingZones,
    ).filter((f) => f.tubeTypeId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_heatingZonesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TubeTypesTableFilterComposer
    extends Composer<_$AppDatabase, $TubeTypesTable> {
  $$TubeTypesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get material => $composableBuilder(
    column: $table.material,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get outerDiameterMm => $composableBuilder(
    column: $table.outerDiameterMm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get innerDiameterMm => $composableBuilder(
    column: $table.innerDiameterMm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get wallThicknessMm => $composableBuilder(
    column: $table.wallThicknessMm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get thermalConductivity => $composableBuilder(
    column: $table.thermalConductivity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get roughness => $composableBuilder(
    column: $table.roughness,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get maxOperatingTempC => $composableBuilder(
    column: $table.maxOperatingTempC,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get maxOperatingPressure => $composableBuilder(
    column: $table.maxOperatingPressure,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> heatingZonesRefs(
    Expression<bool> Function($$HeatingZonesTableFilterComposer f) f,
  ) {
    final $$HeatingZonesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.heatingZones,
      getReferencedColumn: (t) => t.tubeTypeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HeatingZonesTableFilterComposer(
            $db: $db,
            $table: $db.heatingZones,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TubeTypesTableOrderingComposer
    extends Composer<_$AppDatabase, $TubeTypesTable> {
  $$TubeTypesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get material => $composableBuilder(
    column: $table.material,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get outerDiameterMm => $composableBuilder(
    column: $table.outerDiameterMm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get innerDiameterMm => $composableBuilder(
    column: $table.innerDiameterMm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get wallThicknessMm => $composableBuilder(
    column: $table.wallThicknessMm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get thermalConductivity => $composableBuilder(
    column: $table.thermalConductivity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get roughness => $composableBuilder(
    column: $table.roughness,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get maxOperatingTempC => $composableBuilder(
    column: $table.maxOperatingTempC,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get maxOperatingPressure => $composableBuilder(
    column: $table.maxOperatingPressure,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TubeTypesTableAnnotationComposer
    extends Composer<_$AppDatabase, $TubeTypesTable> {
  $$TubeTypesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get material =>
      $composableBuilder(column: $table.material, builder: (column) => column);

  GeneratedColumn<double> get outerDiameterMm => $composableBuilder(
    column: $table.outerDiameterMm,
    builder: (column) => column,
  );

  GeneratedColumn<double> get innerDiameterMm => $composableBuilder(
    column: $table.innerDiameterMm,
    builder: (column) => column,
  );

  GeneratedColumn<double> get wallThicknessMm => $composableBuilder(
    column: $table.wallThicknessMm,
    builder: (column) => column,
  );

  GeneratedColumn<double> get thermalConductivity => $composableBuilder(
    column: $table.thermalConductivity,
    builder: (column) => column,
  );

  GeneratedColumn<double> get roughness =>
      $composableBuilder(column: $table.roughness, builder: (column) => column);

  GeneratedColumn<double> get maxOperatingTempC => $composableBuilder(
    column: $table.maxOperatingTempC,
    builder: (column) => column,
  );

  GeneratedColumn<double> get maxOperatingPressure => $composableBuilder(
    column: $table.maxOperatingPressure,
    builder: (column) => column,
  );

  Expression<T> heatingZonesRefs<T extends Object>(
    Expression<T> Function($$HeatingZonesTableAnnotationComposer a) f,
  ) {
    final $$HeatingZonesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.heatingZones,
      getReferencedColumn: (t) => t.tubeTypeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HeatingZonesTableAnnotationComposer(
            $db: $db,
            $table: $db.heatingZones,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TubeTypesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TubeTypesTable,
          TubeType,
          $$TubeTypesTableFilterComposer,
          $$TubeTypesTableOrderingComposer,
          $$TubeTypesTableAnnotationComposer,
          $$TubeTypesTableCreateCompanionBuilder,
          $$TubeTypesTableUpdateCompanionBuilder,
          (TubeType, $$TubeTypesTableReferences),
          TubeType,
          PrefetchHooks Function({bool heatingZonesRefs})
        > {
  $$TubeTypesTableTableManager(_$AppDatabase db, $TubeTypesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TubeTypesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TubeTypesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TubeTypesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> material = const Value.absent(),
                Value<double> outerDiameterMm = const Value.absent(),
                Value<double> innerDiameterMm = const Value.absent(),
                Value<double> wallThicknessMm = const Value.absent(),
                Value<double> thermalConductivity = const Value.absent(),
                Value<double> roughness = const Value.absent(),
                Value<double> maxOperatingTempC = const Value.absent(),
                Value<double> maxOperatingPressure = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TubeTypesCompanion(
                id: id,
                name: name,
                material: material,
                outerDiameterMm: outerDiameterMm,
                innerDiameterMm: innerDiameterMm,
                wallThicknessMm: wallThicknessMm,
                thermalConductivity: thermalConductivity,
                roughness: roughness,
                maxOperatingTempC: maxOperatingTempC,
                maxOperatingPressure: maxOperatingPressure,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String material,
                Value<double> outerDiameterMm = const Value.absent(),
                Value<double> innerDiameterMm = const Value.absent(),
                Value<double> wallThicknessMm = const Value.absent(),
                Value<double> thermalConductivity = const Value.absent(),
                Value<double> roughness = const Value.absent(),
                Value<double> maxOperatingTempC = const Value.absent(),
                Value<double> maxOperatingPressure = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TubeTypesCompanion.insert(
                id: id,
                name: name,
                material: material,
                outerDiameterMm: outerDiameterMm,
                innerDiameterMm: innerDiameterMm,
                wallThicknessMm: wallThicknessMm,
                thermalConductivity: thermalConductivity,
                roughness: roughness,
                maxOperatingTempC: maxOperatingTempC,
                maxOperatingPressure: maxOperatingPressure,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TubeTypesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({heatingZonesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (heatingZonesRefs) db.heatingZones],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (heatingZonesRefs)
                    await $_getPrefetchedData<
                      TubeType,
                      $TubeTypesTable,
                      HeatingZone
                    >(
                      currentTable: table,
                      referencedTable: $$TubeTypesTableReferences
                          ._heatingZonesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$TubeTypesTableReferences(
                            db,
                            table,
                            p0,
                          ).heatingZonesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.tubeTypeId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$TubeTypesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TubeTypesTable,
      TubeType,
      $$TubeTypesTableFilterComposer,
      $$TubeTypesTableOrderingComposer,
      $$TubeTypesTableAnnotationComposer,
      $$TubeTypesTableCreateCompanionBuilder,
      $$TubeTypesTableUpdateCompanionBuilder,
      (TubeType, $$TubeTypesTableReferences),
      TubeType,
      PrefetchHooks Function({bool heatingZonesRefs})
    >;
typedef $$FlooringMaterialsTableCreateCompanionBuilder =
    FlooringMaterialsCompanion Function({
      required String id,
      required String name,
      required double thermalResistance,
      Value<String> surfaceType,
      Value<int> rowid,
    });
typedef $$FlooringMaterialsTableUpdateCompanionBuilder =
    FlooringMaterialsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<double> thermalResistance,
      Value<String> surfaceType,
      Value<int> rowid,
    });

final class $$FlooringMaterialsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $FlooringMaterialsTable,
          FlooringMaterial
        > {
  $$FlooringMaterialsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$HeatingZonesTable, List<HeatingZone>>
  _heatingZonesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.heatingZones,
    aliasName: $_aliasNameGenerator(
      db.flooringMaterials.id,
      db.heatingZones.flooringMaterialId,
    ),
  );

  $$HeatingZonesTableProcessedTableManager get heatingZonesRefs {
    final manager = $$HeatingZonesTableTableManager($_db, $_db.heatingZones)
        .filter(
          (f) => f.flooringMaterialId.id.sqlEquals($_itemColumn<String>('id')!),
        );

    final cache = $_typedResult.readTableOrNull(_heatingZonesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$FlooringMaterialsTableFilterComposer
    extends Composer<_$AppDatabase, $FlooringMaterialsTable> {
  $$FlooringMaterialsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get thermalResistance => $composableBuilder(
    column: $table.thermalResistance,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get surfaceType => $composableBuilder(
    column: $table.surfaceType,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> heatingZonesRefs(
    Expression<bool> Function($$HeatingZonesTableFilterComposer f) f,
  ) {
    final $$HeatingZonesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.heatingZones,
      getReferencedColumn: (t) => t.flooringMaterialId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HeatingZonesTableFilterComposer(
            $db: $db,
            $table: $db.heatingZones,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FlooringMaterialsTableOrderingComposer
    extends Composer<_$AppDatabase, $FlooringMaterialsTable> {
  $$FlooringMaterialsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get thermalResistance => $composableBuilder(
    column: $table.thermalResistance,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get surfaceType => $composableBuilder(
    column: $table.surfaceType,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FlooringMaterialsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FlooringMaterialsTable> {
  $$FlooringMaterialsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get thermalResistance => $composableBuilder(
    column: $table.thermalResistance,
    builder: (column) => column,
  );

  GeneratedColumn<String> get surfaceType => $composableBuilder(
    column: $table.surfaceType,
    builder: (column) => column,
  );

  Expression<T> heatingZonesRefs<T extends Object>(
    Expression<T> Function($$HeatingZonesTableAnnotationComposer a) f,
  ) {
    final $$HeatingZonesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.heatingZones,
      getReferencedColumn: (t) => t.flooringMaterialId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HeatingZonesTableAnnotationComposer(
            $db: $db,
            $table: $db.heatingZones,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FlooringMaterialsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FlooringMaterialsTable,
          FlooringMaterial,
          $$FlooringMaterialsTableFilterComposer,
          $$FlooringMaterialsTableOrderingComposer,
          $$FlooringMaterialsTableAnnotationComposer,
          $$FlooringMaterialsTableCreateCompanionBuilder,
          $$FlooringMaterialsTableUpdateCompanionBuilder,
          (FlooringMaterial, $$FlooringMaterialsTableReferences),
          FlooringMaterial,
          PrefetchHooks Function({bool heatingZonesRefs})
        > {
  $$FlooringMaterialsTableTableManager(
    _$AppDatabase db,
    $FlooringMaterialsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FlooringMaterialsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FlooringMaterialsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FlooringMaterialsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<double> thermalResistance = const Value.absent(),
                Value<String> surfaceType = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FlooringMaterialsCompanion(
                id: id,
                name: name,
                thermalResistance: thermalResistance,
                surfaceType: surfaceType,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required double thermalResistance,
                Value<String> surfaceType = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FlooringMaterialsCompanion.insert(
                id: id,
                name: name,
                thermalResistance: thermalResistance,
                surfaceType: surfaceType,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$FlooringMaterialsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({heatingZonesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (heatingZonesRefs) db.heatingZones],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (heatingZonesRefs)
                    await $_getPrefetchedData<
                      FlooringMaterial,
                      $FlooringMaterialsTable,
                      HeatingZone
                    >(
                      currentTable: table,
                      referencedTable: $$FlooringMaterialsTableReferences
                          ._heatingZonesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$FlooringMaterialsTableReferences(
                            db,
                            table,
                            p0,
                          ).heatingZonesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.flooringMaterialId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$FlooringMaterialsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FlooringMaterialsTable,
      FlooringMaterial,
      $$FlooringMaterialsTableFilterComposer,
      $$FlooringMaterialsTableOrderingComposer,
      $$FlooringMaterialsTableAnnotationComposer,
      $$FlooringMaterialsTableCreateCompanionBuilder,
      $$FlooringMaterialsTableUpdateCompanionBuilder,
      (FlooringMaterial, $$FlooringMaterialsTableReferences),
      FlooringMaterial,
      PrefetchHooks Function({bool heatingZonesRefs})
    >;
typedef $$HeatingZonesTableCreateCompanionBuilder =
    HeatingZonesCompanion Function({
      required String id,
      required String roomId,
      Value<String> zoneType,
      Value<String> polygonJson,
      Value<int> tubeSpacingMm,
      required String tubeTypeId,
      required String flooringMaterialId,
      Value<int> borderDistanceMm,
      Value<String> layoutPattern,
      Value<String?> circuitId,
      Value<String?> wallSegmentId,
      Value<int?> heightMm,
      Value<double?> positionOnWallMm,
      Value<int?> widthMm,
      Value<double?> customFlooringResistance,
      Value<int> rowid,
    });
typedef $$HeatingZonesTableUpdateCompanionBuilder =
    HeatingZonesCompanion Function({
      Value<String> id,
      Value<String> roomId,
      Value<String> zoneType,
      Value<String> polygonJson,
      Value<int> tubeSpacingMm,
      Value<String> tubeTypeId,
      Value<String> flooringMaterialId,
      Value<int> borderDistanceMm,
      Value<String> layoutPattern,
      Value<String?> circuitId,
      Value<String?> wallSegmentId,
      Value<int?> heightMm,
      Value<double?> positionOnWallMm,
      Value<int?> widthMm,
      Value<double?> customFlooringResistance,
      Value<int> rowid,
    });

final class $$HeatingZonesTableReferences
    extends BaseReferences<_$AppDatabase, $HeatingZonesTable, HeatingZone> {
  $$HeatingZonesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $RoomsTable _roomIdTable(_$AppDatabase db) => db.rooms.createAlias(
    $_aliasNameGenerator(db.heatingZones.roomId, db.rooms.id),
  );

  $$RoomsTableProcessedTableManager get roomId {
    final $_column = $_itemColumn<String>('room_id')!;

    final manager = $$RoomsTableTableManager(
      $_db,
      $_db.rooms,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_roomIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TubeTypesTable _tubeTypeIdTable(_$AppDatabase db) =>
      db.tubeTypes.createAlias(
        $_aliasNameGenerator(db.heatingZones.tubeTypeId, db.tubeTypes.id),
      );

  $$TubeTypesTableProcessedTableManager get tubeTypeId {
    final $_column = $_itemColumn<String>('tube_type_id')!;

    final manager = $$TubeTypesTableTableManager(
      $_db,
      $_db.tubeTypes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tubeTypeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $FlooringMaterialsTable _flooringMaterialIdTable(_$AppDatabase db) =>
      db.flooringMaterials.createAlias(
        $_aliasNameGenerator(
          db.heatingZones.flooringMaterialId,
          db.flooringMaterials.id,
        ),
      );

  $$FlooringMaterialsTableProcessedTableManager get flooringMaterialId {
    final $_column = $_itemColumn<String>('flooring_material_id')!;

    final manager = $$FlooringMaterialsTableTableManager(
      $_db,
      $_db.flooringMaterials,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_flooringMaterialIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $WallSegmentsTable _wallSegmentIdTable(_$AppDatabase db) =>
      db.wallSegments.createAlias(
        $_aliasNameGenerator(db.heatingZones.wallSegmentId, db.wallSegments.id),
      );

  $$WallSegmentsTableProcessedTableManager? get wallSegmentId {
    final $_column = $_itemColumn<String>('wall_segment_id');
    if ($_column == null) return null;
    final manager = $$WallSegmentsTableTableManager(
      $_db,
      $_db.wallSegments,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_wallSegmentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$HeatingCircuitsTable, List<HeatingCircuit>>
  _heatingCircuitsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.heatingCircuits,
    aliasName: $_aliasNameGenerator(
      db.heatingZones.id,
      db.heatingCircuits.heatingZoneId,
    ),
  );

  $$HeatingCircuitsTableProcessedTableManager get heatingCircuitsRefs {
    final manager = $$HeatingCircuitsTableTableManager(
      $_db,
      $_db.heatingCircuits,
    ).filter((f) => f.heatingZoneId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _heatingCircuitsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$HeatingZonesTableFilterComposer
    extends Composer<_$AppDatabase, $HeatingZonesTable> {
  $$HeatingZonesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get zoneType => $composableBuilder(
    column: $table.zoneType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get polygonJson => $composableBuilder(
    column: $table.polygonJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tubeSpacingMm => $composableBuilder(
    column: $table.tubeSpacingMm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get borderDistanceMm => $composableBuilder(
    column: $table.borderDistanceMm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get layoutPattern => $composableBuilder(
    column: $table.layoutPattern,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get circuitId => $composableBuilder(
    column: $table.circuitId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get heightMm => $composableBuilder(
    column: $table.heightMm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get positionOnWallMm => $composableBuilder(
    column: $table.positionOnWallMm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get widthMm => $composableBuilder(
    column: $table.widthMm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get customFlooringResistance => $composableBuilder(
    column: $table.customFlooringResistance,
    builder: (column) => ColumnFilters(column),
  );

  $$RoomsTableFilterComposer get roomId {
    final $$RoomsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.roomId,
      referencedTable: $db.rooms,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RoomsTableFilterComposer(
            $db: $db,
            $table: $db.rooms,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TubeTypesTableFilterComposer get tubeTypeId {
    final $$TubeTypesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tubeTypeId,
      referencedTable: $db.tubeTypes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TubeTypesTableFilterComposer(
            $db: $db,
            $table: $db.tubeTypes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$FlooringMaterialsTableFilterComposer get flooringMaterialId {
    final $$FlooringMaterialsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.flooringMaterialId,
      referencedTable: $db.flooringMaterials,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FlooringMaterialsTableFilterComposer(
            $db: $db,
            $table: $db.flooringMaterials,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WallSegmentsTableFilterComposer get wallSegmentId {
    final $$WallSegmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.wallSegmentId,
      referencedTable: $db.wallSegments,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WallSegmentsTableFilterComposer(
            $db: $db,
            $table: $db.wallSegments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> heatingCircuitsRefs(
    Expression<bool> Function($$HeatingCircuitsTableFilterComposer f) f,
  ) {
    final $$HeatingCircuitsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.heatingCircuits,
      getReferencedColumn: (t) => t.heatingZoneId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HeatingCircuitsTableFilterComposer(
            $db: $db,
            $table: $db.heatingCircuits,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$HeatingZonesTableOrderingComposer
    extends Composer<_$AppDatabase, $HeatingZonesTable> {
  $$HeatingZonesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get zoneType => $composableBuilder(
    column: $table.zoneType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get polygonJson => $composableBuilder(
    column: $table.polygonJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tubeSpacingMm => $composableBuilder(
    column: $table.tubeSpacingMm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get borderDistanceMm => $composableBuilder(
    column: $table.borderDistanceMm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get layoutPattern => $composableBuilder(
    column: $table.layoutPattern,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get circuitId => $composableBuilder(
    column: $table.circuitId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get heightMm => $composableBuilder(
    column: $table.heightMm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get positionOnWallMm => $composableBuilder(
    column: $table.positionOnWallMm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get widthMm => $composableBuilder(
    column: $table.widthMm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get customFlooringResistance => $composableBuilder(
    column: $table.customFlooringResistance,
    builder: (column) => ColumnOrderings(column),
  );

  $$RoomsTableOrderingComposer get roomId {
    final $$RoomsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.roomId,
      referencedTable: $db.rooms,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RoomsTableOrderingComposer(
            $db: $db,
            $table: $db.rooms,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TubeTypesTableOrderingComposer get tubeTypeId {
    final $$TubeTypesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tubeTypeId,
      referencedTable: $db.tubeTypes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TubeTypesTableOrderingComposer(
            $db: $db,
            $table: $db.tubeTypes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$FlooringMaterialsTableOrderingComposer get flooringMaterialId {
    final $$FlooringMaterialsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.flooringMaterialId,
      referencedTable: $db.flooringMaterials,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FlooringMaterialsTableOrderingComposer(
            $db: $db,
            $table: $db.flooringMaterials,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WallSegmentsTableOrderingComposer get wallSegmentId {
    final $$WallSegmentsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.wallSegmentId,
      referencedTable: $db.wallSegments,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WallSegmentsTableOrderingComposer(
            $db: $db,
            $table: $db.wallSegments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$HeatingZonesTableAnnotationComposer
    extends Composer<_$AppDatabase, $HeatingZonesTable> {
  $$HeatingZonesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get zoneType =>
      $composableBuilder(column: $table.zoneType, builder: (column) => column);

  GeneratedColumn<String> get polygonJson => $composableBuilder(
    column: $table.polygonJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get tubeSpacingMm => $composableBuilder(
    column: $table.tubeSpacingMm,
    builder: (column) => column,
  );

  GeneratedColumn<int> get borderDistanceMm => $composableBuilder(
    column: $table.borderDistanceMm,
    builder: (column) => column,
  );

  GeneratedColumn<String> get layoutPattern => $composableBuilder(
    column: $table.layoutPattern,
    builder: (column) => column,
  );

  GeneratedColumn<String> get circuitId =>
      $composableBuilder(column: $table.circuitId, builder: (column) => column);

  GeneratedColumn<int> get heightMm =>
      $composableBuilder(column: $table.heightMm, builder: (column) => column);

  GeneratedColumn<double> get positionOnWallMm => $composableBuilder(
    column: $table.positionOnWallMm,
    builder: (column) => column,
  );

  GeneratedColumn<int> get widthMm =>
      $composableBuilder(column: $table.widthMm, builder: (column) => column);

  GeneratedColumn<double> get customFlooringResistance => $composableBuilder(
    column: $table.customFlooringResistance,
    builder: (column) => column,
  );

  $$RoomsTableAnnotationComposer get roomId {
    final $$RoomsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.roomId,
      referencedTable: $db.rooms,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RoomsTableAnnotationComposer(
            $db: $db,
            $table: $db.rooms,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TubeTypesTableAnnotationComposer get tubeTypeId {
    final $$TubeTypesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tubeTypeId,
      referencedTable: $db.tubeTypes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TubeTypesTableAnnotationComposer(
            $db: $db,
            $table: $db.tubeTypes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$FlooringMaterialsTableAnnotationComposer get flooringMaterialId {
    final $$FlooringMaterialsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.flooringMaterialId,
          referencedTable: $db.flooringMaterials,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$FlooringMaterialsTableAnnotationComposer(
                $db: $db,
                $table: $db.flooringMaterials,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  $$WallSegmentsTableAnnotationComposer get wallSegmentId {
    final $$WallSegmentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.wallSegmentId,
      referencedTable: $db.wallSegments,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WallSegmentsTableAnnotationComposer(
            $db: $db,
            $table: $db.wallSegments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> heatingCircuitsRefs<T extends Object>(
    Expression<T> Function($$HeatingCircuitsTableAnnotationComposer a) f,
  ) {
    final $$HeatingCircuitsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.heatingCircuits,
      getReferencedColumn: (t) => t.heatingZoneId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HeatingCircuitsTableAnnotationComposer(
            $db: $db,
            $table: $db.heatingCircuits,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$HeatingZonesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HeatingZonesTable,
          HeatingZone,
          $$HeatingZonesTableFilterComposer,
          $$HeatingZonesTableOrderingComposer,
          $$HeatingZonesTableAnnotationComposer,
          $$HeatingZonesTableCreateCompanionBuilder,
          $$HeatingZonesTableUpdateCompanionBuilder,
          (HeatingZone, $$HeatingZonesTableReferences),
          HeatingZone,
          PrefetchHooks Function({
            bool roomId,
            bool tubeTypeId,
            bool flooringMaterialId,
            bool wallSegmentId,
            bool heatingCircuitsRefs,
          })
        > {
  $$HeatingZonesTableTableManager(_$AppDatabase db, $HeatingZonesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HeatingZonesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HeatingZonesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HeatingZonesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> roomId = const Value.absent(),
                Value<String> zoneType = const Value.absent(),
                Value<String> polygonJson = const Value.absent(),
                Value<int> tubeSpacingMm = const Value.absent(),
                Value<String> tubeTypeId = const Value.absent(),
                Value<String> flooringMaterialId = const Value.absent(),
                Value<int> borderDistanceMm = const Value.absent(),
                Value<String> layoutPattern = const Value.absent(),
                Value<String?> circuitId = const Value.absent(),
                Value<String?> wallSegmentId = const Value.absent(),
                Value<int?> heightMm = const Value.absent(),
                Value<double?> positionOnWallMm = const Value.absent(),
                Value<int?> widthMm = const Value.absent(),
                Value<double?> customFlooringResistance = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HeatingZonesCompanion(
                id: id,
                roomId: roomId,
                zoneType: zoneType,
                polygonJson: polygonJson,
                tubeSpacingMm: tubeSpacingMm,
                tubeTypeId: tubeTypeId,
                flooringMaterialId: flooringMaterialId,
                borderDistanceMm: borderDistanceMm,
                layoutPattern: layoutPattern,
                circuitId: circuitId,
                wallSegmentId: wallSegmentId,
                heightMm: heightMm,
                positionOnWallMm: positionOnWallMm,
                widthMm: widthMm,
                customFlooringResistance: customFlooringResistance,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String roomId,
                Value<String> zoneType = const Value.absent(),
                Value<String> polygonJson = const Value.absent(),
                Value<int> tubeSpacingMm = const Value.absent(),
                required String tubeTypeId,
                required String flooringMaterialId,
                Value<int> borderDistanceMm = const Value.absent(),
                Value<String> layoutPattern = const Value.absent(),
                Value<String?> circuitId = const Value.absent(),
                Value<String?> wallSegmentId = const Value.absent(),
                Value<int?> heightMm = const Value.absent(),
                Value<double?> positionOnWallMm = const Value.absent(),
                Value<int?> widthMm = const Value.absent(),
                Value<double?> customFlooringResistance = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HeatingZonesCompanion.insert(
                id: id,
                roomId: roomId,
                zoneType: zoneType,
                polygonJson: polygonJson,
                tubeSpacingMm: tubeSpacingMm,
                tubeTypeId: tubeTypeId,
                flooringMaterialId: flooringMaterialId,
                borderDistanceMm: borderDistanceMm,
                layoutPattern: layoutPattern,
                circuitId: circuitId,
                wallSegmentId: wallSegmentId,
                heightMm: heightMm,
                positionOnWallMm: positionOnWallMm,
                widthMm: widthMm,
                customFlooringResistance: customFlooringResistance,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$HeatingZonesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                roomId = false,
                tubeTypeId = false,
                flooringMaterialId = false,
                wallSegmentId = false,
                heatingCircuitsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (heatingCircuitsRefs) db.heatingCircuits,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (roomId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.roomId,
                                    referencedTable:
                                        $$HeatingZonesTableReferences
                                            ._roomIdTable(db),
                                    referencedColumn:
                                        $$HeatingZonesTableReferences
                                            ._roomIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (tubeTypeId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.tubeTypeId,
                                    referencedTable:
                                        $$HeatingZonesTableReferences
                                            ._tubeTypeIdTable(db),
                                    referencedColumn:
                                        $$HeatingZonesTableReferences
                                            ._tubeTypeIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (flooringMaterialId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.flooringMaterialId,
                                    referencedTable:
                                        $$HeatingZonesTableReferences
                                            ._flooringMaterialIdTable(db),
                                    referencedColumn:
                                        $$HeatingZonesTableReferences
                                            ._flooringMaterialIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (wallSegmentId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.wallSegmentId,
                                    referencedTable:
                                        $$HeatingZonesTableReferences
                                            ._wallSegmentIdTable(db),
                                    referencedColumn:
                                        $$HeatingZonesTableReferences
                                            ._wallSegmentIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (heatingCircuitsRefs)
                        await $_getPrefetchedData<
                          HeatingZone,
                          $HeatingZonesTable,
                          HeatingCircuit
                        >(
                          currentTable: table,
                          referencedTable: $$HeatingZonesTableReferences
                              ._heatingCircuitsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$HeatingZonesTableReferences(
                                db,
                                table,
                                p0,
                              ).heatingCircuitsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.heatingZoneId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$HeatingZonesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HeatingZonesTable,
      HeatingZone,
      $$HeatingZonesTableFilterComposer,
      $$HeatingZonesTableOrderingComposer,
      $$HeatingZonesTableAnnotationComposer,
      $$HeatingZonesTableCreateCompanionBuilder,
      $$HeatingZonesTableUpdateCompanionBuilder,
      (HeatingZone, $$HeatingZonesTableReferences),
      HeatingZone,
      PrefetchHooks Function({
        bool roomId,
        bool tubeTypeId,
        bool flooringMaterialId,
        bool wallSegmentId,
        bool heatingCircuitsRefs,
      })
    >;
typedef $$DistributorsTableCreateCompanionBuilder =
    DistributorsCompanion Function({
      required String id,
      required String floorId,
      required String positionJson,
      Value<double> supplyTempC,
      Value<double> returnTempC,
      Value<double?> pumpCapacityPa,
      Value<int> widthMm,
      Value<int> rotationDeg,
      Value<int> rowid,
    });
typedef $$DistributorsTableUpdateCompanionBuilder =
    DistributorsCompanion Function({
      Value<String> id,
      Value<String> floorId,
      Value<String> positionJson,
      Value<double> supplyTempC,
      Value<double> returnTempC,
      Value<double?> pumpCapacityPa,
      Value<int> widthMm,
      Value<int> rotationDeg,
      Value<int> rowid,
    });

final class $$DistributorsTableReferences
    extends BaseReferences<_$AppDatabase, $DistributorsTable, Distributor> {
  $$DistributorsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $FloorsTable _floorIdTable(_$AppDatabase db) => db.floors.createAlias(
    $_aliasNameGenerator(db.distributors.floorId, db.floors.id),
  );

  $$FloorsTableProcessedTableManager get floorId {
    final $_column = $_itemColumn<String>('floor_id')!;

    final manager = $$FloorsTableTableManager(
      $_db,
      $_db.floors,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_floorIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$HeatingCircuitsTable, List<HeatingCircuit>>
  _heatingCircuitsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.heatingCircuits,
    aliasName: $_aliasNameGenerator(
      db.distributors.id,
      db.heatingCircuits.distributorId,
    ),
  );

  $$HeatingCircuitsTableProcessedTableManager get heatingCircuitsRefs {
    final manager = $$HeatingCircuitsTableTableManager(
      $_db,
      $_db.heatingCircuits,
    ).filter((f) => f.distributorId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _heatingCircuitsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$DistributorsTableFilterComposer
    extends Composer<_$AppDatabase, $DistributorsTable> {
  $$DistributorsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get positionJson => $composableBuilder(
    column: $table.positionJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get supplyTempC => $composableBuilder(
    column: $table.supplyTempC,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get returnTempC => $composableBuilder(
    column: $table.returnTempC,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get pumpCapacityPa => $composableBuilder(
    column: $table.pumpCapacityPa,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get widthMm => $composableBuilder(
    column: $table.widthMm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rotationDeg => $composableBuilder(
    column: $table.rotationDeg,
    builder: (column) => ColumnFilters(column),
  );

  $$FloorsTableFilterComposer get floorId {
    final $$FloorsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.floorId,
      referencedTable: $db.floors,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FloorsTableFilterComposer(
            $db: $db,
            $table: $db.floors,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> heatingCircuitsRefs(
    Expression<bool> Function($$HeatingCircuitsTableFilterComposer f) f,
  ) {
    final $$HeatingCircuitsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.heatingCircuits,
      getReferencedColumn: (t) => t.distributorId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HeatingCircuitsTableFilterComposer(
            $db: $db,
            $table: $db.heatingCircuits,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DistributorsTableOrderingComposer
    extends Composer<_$AppDatabase, $DistributorsTable> {
  $$DistributorsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get positionJson => $composableBuilder(
    column: $table.positionJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get supplyTempC => $composableBuilder(
    column: $table.supplyTempC,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get returnTempC => $composableBuilder(
    column: $table.returnTempC,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get pumpCapacityPa => $composableBuilder(
    column: $table.pumpCapacityPa,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get widthMm => $composableBuilder(
    column: $table.widthMm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rotationDeg => $composableBuilder(
    column: $table.rotationDeg,
    builder: (column) => ColumnOrderings(column),
  );

  $$FloorsTableOrderingComposer get floorId {
    final $$FloorsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.floorId,
      referencedTable: $db.floors,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FloorsTableOrderingComposer(
            $db: $db,
            $table: $db.floors,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DistributorsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DistributorsTable> {
  $$DistributorsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get positionJson => $composableBuilder(
    column: $table.positionJson,
    builder: (column) => column,
  );

  GeneratedColumn<double> get supplyTempC => $composableBuilder(
    column: $table.supplyTempC,
    builder: (column) => column,
  );

  GeneratedColumn<double> get returnTempC => $composableBuilder(
    column: $table.returnTempC,
    builder: (column) => column,
  );

  GeneratedColumn<double> get pumpCapacityPa => $composableBuilder(
    column: $table.pumpCapacityPa,
    builder: (column) => column,
  );

  GeneratedColumn<int> get widthMm =>
      $composableBuilder(column: $table.widthMm, builder: (column) => column);

  GeneratedColumn<int> get rotationDeg => $composableBuilder(
    column: $table.rotationDeg,
    builder: (column) => column,
  );

  $$FloorsTableAnnotationComposer get floorId {
    final $$FloorsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.floorId,
      referencedTable: $db.floors,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FloorsTableAnnotationComposer(
            $db: $db,
            $table: $db.floors,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> heatingCircuitsRefs<T extends Object>(
    Expression<T> Function($$HeatingCircuitsTableAnnotationComposer a) f,
  ) {
    final $$HeatingCircuitsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.heatingCircuits,
      getReferencedColumn: (t) => t.distributorId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HeatingCircuitsTableAnnotationComposer(
            $db: $db,
            $table: $db.heatingCircuits,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DistributorsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DistributorsTable,
          Distributor,
          $$DistributorsTableFilterComposer,
          $$DistributorsTableOrderingComposer,
          $$DistributorsTableAnnotationComposer,
          $$DistributorsTableCreateCompanionBuilder,
          $$DistributorsTableUpdateCompanionBuilder,
          (Distributor, $$DistributorsTableReferences),
          Distributor,
          PrefetchHooks Function({bool floorId, bool heatingCircuitsRefs})
        > {
  $$DistributorsTableTableManager(_$AppDatabase db, $DistributorsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DistributorsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DistributorsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DistributorsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> floorId = const Value.absent(),
                Value<String> positionJson = const Value.absent(),
                Value<double> supplyTempC = const Value.absent(),
                Value<double> returnTempC = const Value.absent(),
                Value<double?> pumpCapacityPa = const Value.absent(),
                Value<int> widthMm = const Value.absent(),
                Value<int> rotationDeg = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DistributorsCompanion(
                id: id,
                floorId: floorId,
                positionJson: positionJson,
                supplyTempC: supplyTempC,
                returnTempC: returnTempC,
                pumpCapacityPa: pumpCapacityPa,
                widthMm: widthMm,
                rotationDeg: rotationDeg,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String floorId,
                required String positionJson,
                Value<double> supplyTempC = const Value.absent(),
                Value<double> returnTempC = const Value.absent(),
                Value<double?> pumpCapacityPa = const Value.absent(),
                Value<int> widthMm = const Value.absent(),
                Value<int> rotationDeg = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DistributorsCompanion.insert(
                id: id,
                floorId: floorId,
                positionJson: positionJson,
                supplyTempC: supplyTempC,
                returnTempC: returnTempC,
                pumpCapacityPa: pumpCapacityPa,
                widthMm: widthMm,
                rotationDeg: rotationDeg,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DistributorsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({floorId = false, heatingCircuitsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (heatingCircuitsRefs) db.heatingCircuits,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (floorId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.floorId,
                                    referencedTable:
                                        $$DistributorsTableReferences
                                            ._floorIdTable(db),
                                    referencedColumn:
                                        $$DistributorsTableReferences
                                            ._floorIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (heatingCircuitsRefs)
                        await $_getPrefetchedData<
                          Distributor,
                          $DistributorsTable,
                          HeatingCircuit
                        >(
                          currentTable: table,
                          referencedTable: $$DistributorsTableReferences
                              ._heatingCircuitsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DistributorsTableReferences(
                                db,
                                table,
                                p0,
                              ).heatingCircuitsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.distributorId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$DistributorsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DistributorsTable,
      Distributor,
      $$DistributorsTableFilterComposer,
      $$DistributorsTableOrderingComposer,
      $$DistributorsTableAnnotationComposer,
      $$DistributorsTableCreateCompanionBuilder,
      $$DistributorsTableUpdateCompanionBuilder,
      (Distributor, $$DistributorsTableReferences),
      Distributor,
      PrefetchHooks Function({bool floorId, bool heatingCircuitsRefs})
    >;
typedef $$HeatingCircuitsTableCreateCompanionBuilder =
    HeatingCircuitsCompanion Function({
      required String id,
      required String distributorId,
      required String heatingZoneId,
      Value<String> supplyRoutePathJson,
      Value<String> returnRoutePathJson,
      Value<double> tubeLengthM,
      Value<double> flowRateKgH,
      Value<double> pressureLossPa,
      Value<double> valveSetting,
      Value<int> rowid,
    });
typedef $$HeatingCircuitsTableUpdateCompanionBuilder =
    HeatingCircuitsCompanion Function({
      Value<String> id,
      Value<String> distributorId,
      Value<String> heatingZoneId,
      Value<String> supplyRoutePathJson,
      Value<String> returnRoutePathJson,
      Value<double> tubeLengthM,
      Value<double> flowRateKgH,
      Value<double> pressureLossPa,
      Value<double> valveSetting,
      Value<int> rowid,
    });

final class $$HeatingCircuitsTableReferences
    extends
        BaseReferences<_$AppDatabase, $HeatingCircuitsTable, HeatingCircuit> {
  $$HeatingCircuitsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $DistributorsTable _distributorIdTable(_$AppDatabase db) =>
      db.distributors.createAlias(
        $_aliasNameGenerator(
          db.heatingCircuits.distributorId,
          db.distributors.id,
        ),
      );

  $$DistributorsTableProcessedTableManager get distributorId {
    final $_column = $_itemColumn<String>('distributor_id')!;

    final manager = $$DistributorsTableTableManager(
      $_db,
      $_db.distributors,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_distributorIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $HeatingZonesTable _heatingZoneIdTable(_$AppDatabase db) =>
      db.heatingZones.createAlias(
        $_aliasNameGenerator(
          db.heatingCircuits.heatingZoneId,
          db.heatingZones.id,
        ),
      );

  $$HeatingZonesTableProcessedTableManager get heatingZoneId {
    final $_column = $_itemColumn<String>('heating_zone_id')!;

    final manager = $$HeatingZonesTableTableManager(
      $_db,
      $_db.heatingZones,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_heatingZoneIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$HeatingCircuitsTableFilterComposer
    extends Composer<_$AppDatabase, $HeatingCircuitsTable> {
  $$HeatingCircuitsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get supplyRoutePathJson => $composableBuilder(
    column: $table.supplyRoutePathJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get returnRoutePathJson => $composableBuilder(
    column: $table.returnRoutePathJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get tubeLengthM => $composableBuilder(
    column: $table.tubeLengthM,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get flowRateKgH => $composableBuilder(
    column: $table.flowRateKgH,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get pressureLossPa => $composableBuilder(
    column: $table.pressureLossPa,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get valveSetting => $composableBuilder(
    column: $table.valveSetting,
    builder: (column) => ColumnFilters(column),
  );

  $$DistributorsTableFilterComposer get distributorId {
    final $$DistributorsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.distributorId,
      referencedTable: $db.distributors,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DistributorsTableFilterComposer(
            $db: $db,
            $table: $db.distributors,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$HeatingZonesTableFilterComposer get heatingZoneId {
    final $$HeatingZonesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.heatingZoneId,
      referencedTable: $db.heatingZones,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HeatingZonesTableFilterComposer(
            $db: $db,
            $table: $db.heatingZones,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$HeatingCircuitsTableOrderingComposer
    extends Composer<_$AppDatabase, $HeatingCircuitsTable> {
  $$HeatingCircuitsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get supplyRoutePathJson => $composableBuilder(
    column: $table.supplyRoutePathJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get returnRoutePathJson => $composableBuilder(
    column: $table.returnRoutePathJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get tubeLengthM => $composableBuilder(
    column: $table.tubeLengthM,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get flowRateKgH => $composableBuilder(
    column: $table.flowRateKgH,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get pressureLossPa => $composableBuilder(
    column: $table.pressureLossPa,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get valveSetting => $composableBuilder(
    column: $table.valveSetting,
    builder: (column) => ColumnOrderings(column),
  );

  $$DistributorsTableOrderingComposer get distributorId {
    final $$DistributorsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.distributorId,
      referencedTable: $db.distributors,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DistributorsTableOrderingComposer(
            $db: $db,
            $table: $db.distributors,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$HeatingZonesTableOrderingComposer get heatingZoneId {
    final $$HeatingZonesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.heatingZoneId,
      referencedTable: $db.heatingZones,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HeatingZonesTableOrderingComposer(
            $db: $db,
            $table: $db.heatingZones,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$HeatingCircuitsTableAnnotationComposer
    extends Composer<_$AppDatabase, $HeatingCircuitsTable> {
  $$HeatingCircuitsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get supplyRoutePathJson => $composableBuilder(
    column: $table.supplyRoutePathJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get returnRoutePathJson => $composableBuilder(
    column: $table.returnRoutePathJson,
    builder: (column) => column,
  );

  GeneratedColumn<double> get tubeLengthM => $composableBuilder(
    column: $table.tubeLengthM,
    builder: (column) => column,
  );

  GeneratedColumn<double> get flowRateKgH => $composableBuilder(
    column: $table.flowRateKgH,
    builder: (column) => column,
  );

  GeneratedColumn<double> get pressureLossPa => $composableBuilder(
    column: $table.pressureLossPa,
    builder: (column) => column,
  );

  GeneratedColumn<double> get valveSetting => $composableBuilder(
    column: $table.valveSetting,
    builder: (column) => column,
  );

  $$DistributorsTableAnnotationComposer get distributorId {
    final $$DistributorsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.distributorId,
      referencedTable: $db.distributors,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DistributorsTableAnnotationComposer(
            $db: $db,
            $table: $db.distributors,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$HeatingZonesTableAnnotationComposer get heatingZoneId {
    final $$HeatingZonesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.heatingZoneId,
      referencedTable: $db.heatingZones,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HeatingZonesTableAnnotationComposer(
            $db: $db,
            $table: $db.heatingZones,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$HeatingCircuitsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HeatingCircuitsTable,
          HeatingCircuit,
          $$HeatingCircuitsTableFilterComposer,
          $$HeatingCircuitsTableOrderingComposer,
          $$HeatingCircuitsTableAnnotationComposer,
          $$HeatingCircuitsTableCreateCompanionBuilder,
          $$HeatingCircuitsTableUpdateCompanionBuilder,
          (HeatingCircuit, $$HeatingCircuitsTableReferences),
          HeatingCircuit,
          PrefetchHooks Function({bool distributorId, bool heatingZoneId})
        > {
  $$HeatingCircuitsTableTableManager(
    _$AppDatabase db,
    $HeatingCircuitsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HeatingCircuitsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HeatingCircuitsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HeatingCircuitsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> distributorId = const Value.absent(),
                Value<String> heatingZoneId = const Value.absent(),
                Value<String> supplyRoutePathJson = const Value.absent(),
                Value<String> returnRoutePathJson = const Value.absent(),
                Value<double> tubeLengthM = const Value.absent(),
                Value<double> flowRateKgH = const Value.absent(),
                Value<double> pressureLossPa = const Value.absent(),
                Value<double> valveSetting = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HeatingCircuitsCompanion(
                id: id,
                distributorId: distributorId,
                heatingZoneId: heatingZoneId,
                supplyRoutePathJson: supplyRoutePathJson,
                returnRoutePathJson: returnRoutePathJson,
                tubeLengthM: tubeLengthM,
                flowRateKgH: flowRateKgH,
                pressureLossPa: pressureLossPa,
                valveSetting: valveSetting,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String distributorId,
                required String heatingZoneId,
                Value<String> supplyRoutePathJson = const Value.absent(),
                Value<String> returnRoutePathJson = const Value.absent(),
                Value<double> tubeLengthM = const Value.absent(),
                Value<double> flowRateKgH = const Value.absent(),
                Value<double> pressureLossPa = const Value.absent(),
                Value<double> valveSetting = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HeatingCircuitsCompanion.insert(
                id: id,
                distributorId: distributorId,
                heatingZoneId: heatingZoneId,
                supplyRoutePathJson: supplyRoutePathJson,
                returnRoutePathJson: returnRoutePathJson,
                tubeLengthM: tubeLengthM,
                flowRateKgH: flowRateKgH,
                pressureLossPa: pressureLossPa,
                valveSetting: valveSetting,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$HeatingCircuitsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({distributorId = false, heatingZoneId = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (distributorId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.distributorId,
                                    referencedTable:
                                        $$HeatingCircuitsTableReferences
                                            ._distributorIdTable(db),
                                    referencedColumn:
                                        $$HeatingCircuitsTableReferences
                                            ._distributorIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (heatingZoneId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.heatingZoneId,
                                    referencedTable:
                                        $$HeatingCircuitsTableReferences
                                            ._heatingZoneIdTable(db),
                                    referencedColumn:
                                        $$HeatingCircuitsTableReferences
                                            ._heatingZoneIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [];
                  },
                );
              },
        ),
      );
}

typedef $$HeatingCircuitsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HeatingCircuitsTable,
      HeatingCircuit,
      $$HeatingCircuitsTableFilterComposer,
      $$HeatingCircuitsTableOrderingComposer,
      $$HeatingCircuitsTableAnnotationComposer,
      $$HeatingCircuitsTableCreateCompanionBuilder,
      $$HeatingCircuitsTableUpdateCompanionBuilder,
      (HeatingCircuit, $$HeatingCircuitsTableReferences),
      HeatingCircuit,
      PrefetchHooks Function({bool distributorId, bool heatingZoneId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ProjectsTableTableManager get projects =>
      $$ProjectsTableTableManager(_db, _db.projects);
  $$FloorsTableTableManager get floors =>
      $$FloorsTableTableManager(_db, _db.floors);
  $$RoomsTableTableManager get rooms =>
      $$RoomsTableTableManager(_db, _db.rooms);
  $$WallConstructionsTableTableManager get wallConstructions =>
      $$WallConstructionsTableTableManager(_db, _db.wallConstructions);
  $$WallSegmentsTableTableManager get wallSegments =>
      $$WallSegmentsTableTableManager(_db, _db.wallSegments);
  $$WindowsTableTableManager get windows =>
      $$WindowsTableTableManager(_db, _db.windows);
  $$DoorsTableTableManager get doors =>
      $$DoorsTableTableManager(_db, _db.doors);
  $$MaterialEntriesTableTableManager get materialEntries =>
      $$MaterialEntriesTableTableManager(_db, _db.materialEntries);
  $$MaterialLayersTableTableManager get materialLayers =>
      $$MaterialLayersTableTableManager(_db, _db.materialLayers);
  $$TubeTypesTableTableManager get tubeTypes =>
      $$TubeTypesTableTableManager(_db, _db.tubeTypes);
  $$FlooringMaterialsTableTableManager get flooringMaterials =>
      $$FlooringMaterialsTableTableManager(_db, _db.flooringMaterials);
  $$HeatingZonesTableTableManager get heatingZones =>
      $$HeatingZonesTableTableManager(_db, _db.heatingZones);
  $$DistributorsTableTableManager get distributors =>
      $$DistributorsTableTableManager(_db, _db.distributors);
  $$HeatingCircuitsTableTableManager get heatingCircuits =>
      $$HeatingCircuitsTableTableManager(_db, _db.heatingCircuits);
}
