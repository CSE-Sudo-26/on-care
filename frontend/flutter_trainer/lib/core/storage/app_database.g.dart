// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $AppKeyValuesTable extends AppKeyValues
    with TableInfo<$AppKeyValuesTable, AppKeyValue> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppKeyValuesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_key_values';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppKeyValue> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppKeyValue map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppKeyValue(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $AppKeyValuesTable createAlias(String alias) {
    return $AppKeyValuesTable(attachedDatabase, alias);
  }
}

class AppKeyValue extends DataClass implements Insertable<AppKeyValue> {
  final String key;
  final String value;
  const AppKeyValue({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppKeyValuesCompanion toCompanion(bool nullToAbsent) {
    return AppKeyValuesCompanion(key: Value(key), value: Value(value));
  }

  factory AppKeyValue.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppKeyValue(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  AppKeyValue copyWith({String? key, String? value}) =>
      AppKeyValue(key: key ?? this.key, value: value ?? this.value);
  AppKeyValue copyWithCompanion(AppKeyValuesCompanion data) {
    return AppKeyValue(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppKeyValue(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppKeyValue &&
          other.key == this.key &&
          other.value == this.value);
}

class AppKeyValuesCompanion extends UpdateCompanion<AppKeyValue> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppKeyValuesCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppKeyValuesCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<AppKeyValue> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppKeyValuesCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return AppKeyValuesCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppKeyValuesCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TrainerClientsTable extends TrainerClients
    with TableInfo<$TrainerClientsTable, TrainerClientRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TrainerClientsTable(this.attachedDatabase, [this._alias]);
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
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _avatarMeta = const VerificationMeta('avatar');
  @override
  late final GeneratedColumn<String> avatar = GeneratedColumn<String>(
    'avatar',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _goalMeta = const VerificationMeta('goal');
  @override
  late final GeneratedColumn<String> goal = GeneratedColumn<String>(
    'goal',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastMessageMeta = const VerificationMeta(
    'lastMessage',
  );
  @override
  late final GeneratedColumn<String> lastMessage = GeneratedColumn<String>(
    'last_message',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastTimeMeta = const VerificationMeta(
    'lastTime',
  );
  @override
  late final GeneratedColumn<String> lastTime = GeneratedColumn<String>(
    'last_time',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _activeMeta = const VerificationMeta('active');
  @override
  late final GeneratedColumn<bool> active = GeneratedColumn<bool>(
    'active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _caloriesTodayMeta = const VerificationMeta(
    'caloriesToday',
  );
  @override
  late final GeneratedColumn<int> caloriesToday = GeneratedColumn<int>(
    'calories_today',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sodiumMgMeta = const VerificationMeta(
    'sodiumMg',
  );
  @override
  late final GeneratedColumn<int> sodiumMg = GeneratedColumn<int>(
    'sodium_mg',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sugarGMeta = const VerificationMeta('sugarG');
  @override
  late final GeneratedColumn<int> sugarG = GeneratedColumn<int>(
    'sugar_g',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastRoutineMeta = const VerificationMeta(
    'lastRoutine',
  );
  @override
  late final GeneratedColumn<String> lastRoutine = GeneratedColumn<String>(
    'last_routine',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _weekCompletionJsonMeta =
      const VerificationMeta('weekCompletionJson');
  @override
  late final GeneratedColumn<String> weekCompletionJson =
      GeneratedColumn<String>(
        'week_completion_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _sodiumWeekJsonMeta = const VerificationMeta(
    'sodiumWeekJson',
  );
  @override
  late final GeneratedColumn<String> sodiumWeekJson = GeneratedColumn<String>(
    'sodium_week_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
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
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    avatar,
    goal,
    lastMessage,
    lastTime,
    active,
    caloriesToday,
    sodiumMg,
    sugarG,
    lastRoutine,
    weekCompletionJson,
    sodiumWeekJson,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'trainer_clients';
  @override
  VerificationContext validateIntegrity(
    Insertable<TrainerClientRow> instance, {
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
    if (data.containsKey('avatar')) {
      context.handle(
        _avatarMeta,
        avatar.isAcceptableOrUnknown(data['avatar']!, _avatarMeta),
      );
    } else if (isInserting) {
      context.missing(_avatarMeta);
    }
    if (data.containsKey('goal')) {
      context.handle(
        _goalMeta,
        goal.isAcceptableOrUnknown(data['goal']!, _goalMeta),
      );
    } else if (isInserting) {
      context.missing(_goalMeta);
    }
    if (data.containsKey('last_message')) {
      context.handle(
        _lastMessageMeta,
        lastMessage.isAcceptableOrUnknown(
          data['last_message']!,
          _lastMessageMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastMessageMeta);
    }
    if (data.containsKey('last_time')) {
      context.handle(
        _lastTimeMeta,
        lastTime.isAcceptableOrUnknown(data['last_time']!, _lastTimeMeta),
      );
    } else if (isInserting) {
      context.missing(_lastTimeMeta);
    }
    if (data.containsKey('active')) {
      context.handle(
        _activeMeta,
        active.isAcceptableOrUnknown(data['active']!, _activeMeta),
      );
    }
    if (data.containsKey('calories_today')) {
      context.handle(
        _caloriesTodayMeta,
        caloriesToday.isAcceptableOrUnknown(
          data['calories_today']!,
          _caloriesTodayMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_caloriesTodayMeta);
    }
    if (data.containsKey('sodium_mg')) {
      context.handle(
        _sodiumMgMeta,
        sodiumMg.isAcceptableOrUnknown(data['sodium_mg']!, _sodiumMgMeta),
      );
    } else if (isInserting) {
      context.missing(_sodiumMgMeta);
    }
    if (data.containsKey('sugar_g')) {
      context.handle(
        _sugarGMeta,
        sugarG.isAcceptableOrUnknown(data['sugar_g']!, _sugarGMeta),
      );
    } else if (isInserting) {
      context.missing(_sugarGMeta);
    }
    if (data.containsKey('last_routine')) {
      context.handle(
        _lastRoutineMeta,
        lastRoutine.isAcceptableOrUnknown(
          data['last_routine']!,
          _lastRoutineMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastRoutineMeta);
    }
    if (data.containsKey('week_completion_json')) {
      context.handle(
        _weekCompletionJsonMeta,
        weekCompletionJson.isAcceptableOrUnknown(
          data['week_completion_json']!,
          _weekCompletionJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_weekCompletionJsonMeta);
    }
    if (data.containsKey('sodium_week_json')) {
      context.handle(
        _sodiumWeekJsonMeta,
        sodiumWeekJson.isAcceptableOrUnknown(
          data['sodium_week_json']!,
          _sodiumWeekJsonMeta,
        ),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TrainerClientRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TrainerClientRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      avatar: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}avatar'],
      )!,
      goal: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}goal'],
      )!,
      lastMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_message'],
      )!,
      lastTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_time'],
      )!,
      active: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}active'],
      )!,
      caloriesToday: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}calories_today'],
      )!,
      sodiumMg: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sodium_mg'],
      )!,
      sugarG: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sugar_g'],
      )!,
      lastRoutine: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_routine'],
      )!,
      weekCompletionJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}week_completion_json'],
      )!,
      sodiumWeekJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sodium_week_json'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $TrainerClientsTable createAlias(String alias) {
    return $TrainerClientsTable(attachedDatabase, alias);
  }
}

class TrainerClientRow extends DataClass
    implements Insertable<TrainerClientRow> {
  final String id;
  final String name;
  final String avatar;
  final String goal;
  final String lastMessage;
  final String lastTime;
  final bool active;
  final int caloriesToday;
  final int sodiumMg;
  final int sugarG;
  final String lastRoutine;
  final String weekCompletionJson;
  final String sodiumWeekJson;
  final int sortOrder;
  const TrainerClientRow({
    required this.id,
    required this.name,
    required this.avatar,
    required this.goal,
    required this.lastMessage,
    required this.lastTime,
    required this.active,
    required this.caloriesToday,
    required this.sodiumMg,
    required this.sugarG,
    required this.lastRoutine,
    required this.weekCompletionJson,
    required this.sodiumWeekJson,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['avatar'] = Variable<String>(avatar);
    map['goal'] = Variable<String>(goal);
    map['last_message'] = Variable<String>(lastMessage);
    map['last_time'] = Variable<String>(lastTime);
    map['active'] = Variable<bool>(active);
    map['calories_today'] = Variable<int>(caloriesToday);
    map['sodium_mg'] = Variable<int>(sodiumMg);
    map['sugar_g'] = Variable<int>(sugarG);
    map['last_routine'] = Variable<String>(lastRoutine);
    map['week_completion_json'] = Variable<String>(weekCompletionJson);
    map['sodium_week_json'] = Variable<String>(sodiumWeekJson);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  TrainerClientsCompanion toCompanion(bool nullToAbsent) {
    return TrainerClientsCompanion(
      id: Value(id),
      name: Value(name),
      avatar: Value(avatar),
      goal: Value(goal),
      lastMessage: Value(lastMessage),
      lastTime: Value(lastTime),
      active: Value(active),
      caloriesToday: Value(caloriesToday),
      sodiumMg: Value(sodiumMg),
      sugarG: Value(sugarG),
      lastRoutine: Value(lastRoutine),
      weekCompletionJson: Value(weekCompletionJson),
      sodiumWeekJson: Value(sodiumWeekJson),
      sortOrder: Value(sortOrder),
    );
  }

  factory TrainerClientRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TrainerClientRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      avatar: serializer.fromJson<String>(json['avatar']),
      goal: serializer.fromJson<String>(json['goal']),
      lastMessage: serializer.fromJson<String>(json['lastMessage']),
      lastTime: serializer.fromJson<String>(json['lastTime']),
      active: serializer.fromJson<bool>(json['active']),
      caloriesToday: serializer.fromJson<int>(json['caloriesToday']),
      sodiumMg: serializer.fromJson<int>(json['sodiumMg']),
      sugarG: serializer.fromJson<int>(json['sugarG']),
      lastRoutine: serializer.fromJson<String>(json['lastRoutine']),
      weekCompletionJson: serializer.fromJson<String>(
        json['weekCompletionJson'],
      ),
      sodiumWeekJson: serializer.fromJson<String>(json['sodiumWeekJson']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'avatar': serializer.toJson<String>(avatar),
      'goal': serializer.toJson<String>(goal),
      'lastMessage': serializer.toJson<String>(lastMessage),
      'lastTime': serializer.toJson<String>(lastTime),
      'active': serializer.toJson<bool>(active),
      'caloriesToday': serializer.toJson<int>(caloriesToday),
      'sodiumMg': serializer.toJson<int>(sodiumMg),
      'sugarG': serializer.toJson<int>(sugarG),
      'lastRoutine': serializer.toJson<String>(lastRoutine),
      'weekCompletionJson': serializer.toJson<String>(weekCompletionJson),
      'sodiumWeekJson': serializer.toJson<String>(sodiumWeekJson),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  TrainerClientRow copyWith({
    String? id,
    String? name,
    String? avatar,
    String? goal,
    String? lastMessage,
    String? lastTime,
    bool? active,
    int? caloriesToday,
    int? sodiumMg,
    int? sugarG,
    String? lastRoutine,
    String? weekCompletionJson,
    String? sodiumWeekJson,
    int? sortOrder,
  }) => TrainerClientRow(
    id: id ?? this.id,
    name: name ?? this.name,
    avatar: avatar ?? this.avatar,
    goal: goal ?? this.goal,
    lastMessage: lastMessage ?? this.lastMessage,
    lastTime: lastTime ?? this.lastTime,
    active: active ?? this.active,
    caloriesToday: caloriesToday ?? this.caloriesToday,
    sodiumMg: sodiumMg ?? this.sodiumMg,
    sugarG: sugarG ?? this.sugarG,
    lastRoutine: lastRoutine ?? this.lastRoutine,
    weekCompletionJson: weekCompletionJson ?? this.weekCompletionJson,
    sodiumWeekJson: sodiumWeekJson ?? this.sodiumWeekJson,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  TrainerClientRow copyWithCompanion(TrainerClientsCompanion data) {
    return TrainerClientRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      avatar: data.avatar.present ? data.avatar.value : this.avatar,
      goal: data.goal.present ? data.goal.value : this.goal,
      lastMessage: data.lastMessage.present
          ? data.lastMessage.value
          : this.lastMessage,
      lastTime: data.lastTime.present ? data.lastTime.value : this.lastTime,
      active: data.active.present ? data.active.value : this.active,
      caloriesToday: data.caloriesToday.present
          ? data.caloriesToday.value
          : this.caloriesToday,
      sodiumMg: data.sodiumMg.present ? data.sodiumMg.value : this.sodiumMg,
      sugarG: data.sugarG.present ? data.sugarG.value : this.sugarG,
      lastRoutine: data.lastRoutine.present
          ? data.lastRoutine.value
          : this.lastRoutine,
      weekCompletionJson: data.weekCompletionJson.present
          ? data.weekCompletionJson.value
          : this.weekCompletionJson,
      sodiumWeekJson: data.sodiumWeekJson.present
          ? data.sodiumWeekJson.value
          : this.sodiumWeekJson,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TrainerClientRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('avatar: $avatar, ')
          ..write('goal: $goal, ')
          ..write('lastMessage: $lastMessage, ')
          ..write('lastTime: $lastTime, ')
          ..write('active: $active, ')
          ..write('caloriesToday: $caloriesToday, ')
          ..write('sodiumMg: $sodiumMg, ')
          ..write('sugarG: $sugarG, ')
          ..write('lastRoutine: $lastRoutine, ')
          ..write('weekCompletionJson: $weekCompletionJson, ')
          ..write('sodiumWeekJson: $sodiumWeekJson, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    avatar,
    goal,
    lastMessage,
    lastTime,
    active,
    caloriesToday,
    sodiumMg,
    sugarG,
    lastRoutine,
    weekCompletionJson,
    sodiumWeekJson,
    sortOrder,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TrainerClientRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.avatar == this.avatar &&
          other.goal == this.goal &&
          other.lastMessage == this.lastMessage &&
          other.lastTime == this.lastTime &&
          other.active == this.active &&
          other.caloriesToday == this.caloriesToday &&
          other.sodiumMg == this.sodiumMg &&
          other.sugarG == this.sugarG &&
          other.lastRoutine == this.lastRoutine &&
          other.weekCompletionJson == this.weekCompletionJson &&
          other.sodiumWeekJson == this.sodiumWeekJson &&
          other.sortOrder == this.sortOrder);
}

class TrainerClientsCompanion extends UpdateCompanion<TrainerClientRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> avatar;
  final Value<String> goal;
  final Value<String> lastMessage;
  final Value<String> lastTime;
  final Value<bool> active;
  final Value<int> caloriesToday;
  final Value<int> sodiumMg;
  final Value<int> sugarG;
  final Value<String> lastRoutine;
  final Value<String> weekCompletionJson;
  final Value<String> sodiumWeekJson;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const TrainerClientsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.avatar = const Value.absent(),
    this.goal = const Value.absent(),
    this.lastMessage = const Value.absent(),
    this.lastTime = const Value.absent(),
    this.active = const Value.absent(),
    this.caloriesToday = const Value.absent(),
    this.sodiumMg = const Value.absent(),
    this.sugarG = const Value.absent(),
    this.lastRoutine = const Value.absent(),
    this.weekCompletionJson = const Value.absent(),
    this.sodiumWeekJson = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TrainerClientsCompanion.insert({
    required String id,
    required String name,
    required String avatar,
    required String goal,
    required String lastMessage,
    required String lastTime,
    this.active = const Value.absent(),
    required int caloriesToday,
    required int sodiumMg,
    required int sugarG,
    required String lastRoutine,
    required String weekCompletionJson,
    this.sodiumWeekJson = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       avatar = Value(avatar),
       goal = Value(goal),
       lastMessage = Value(lastMessage),
       lastTime = Value(lastTime),
       caloriesToday = Value(caloriesToday),
       sodiumMg = Value(sodiumMg),
       sugarG = Value(sugarG),
       lastRoutine = Value(lastRoutine),
       weekCompletionJson = Value(weekCompletionJson);
  static Insertable<TrainerClientRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? avatar,
    Expression<String>? goal,
    Expression<String>? lastMessage,
    Expression<String>? lastTime,
    Expression<bool>? active,
    Expression<int>? caloriesToday,
    Expression<int>? sodiumMg,
    Expression<int>? sugarG,
    Expression<String>? lastRoutine,
    Expression<String>? weekCompletionJson,
    Expression<String>? sodiumWeekJson,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (avatar != null) 'avatar': avatar,
      if (goal != null) 'goal': goal,
      if (lastMessage != null) 'last_message': lastMessage,
      if (lastTime != null) 'last_time': lastTime,
      if (active != null) 'active': active,
      if (caloriesToday != null) 'calories_today': caloriesToday,
      if (sodiumMg != null) 'sodium_mg': sodiumMg,
      if (sugarG != null) 'sugar_g': sugarG,
      if (lastRoutine != null) 'last_routine': lastRoutine,
      if (weekCompletionJson != null)
        'week_completion_json': weekCompletionJson,
      if (sodiumWeekJson != null) 'sodium_week_json': sodiumWeekJson,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TrainerClientsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? avatar,
    Value<String>? goal,
    Value<String>? lastMessage,
    Value<String>? lastTime,
    Value<bool>? active,
    Value<int>? caloriesToday,
    Value<int>? sodiumMg,
    Value<int>? sugarG,
    Value<String>? lastRoutine,
    Value<String>? weekCompletionJson,
    Value<String>? sodiumWeekJson,
    Value<int>? sortOrder,
    Value<int>? rowid,
  }) {
    return TrainerClientsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      goal: goal ?? this.goal,
      lastMessage: lastMessage ?? this.lastMessage,
      lastTime: lastTime ?? this.lastTime,
      active: active ?? this.active,
      caloriesToday: caloriesToday ?? this.caloriesToday,
      sodiumMg: sodiumMg ?? this.sodiumMg,
      sugarG: sugarG ?? this.sugarG,
      lastRoutine: lastRoutine ?? this.lastRoutine,
      weekCompletionJson: weekCompletionJson ?? this.weekCompletionJson,
      sodiumWeekJson: sodiumWeekJson ?? this.sodiumWeekJson,
      sortOrder: sortOrder ?? this.sortOrder,
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
    if (avatar.present) {
      map['avatar'] = Variable<String>(avatar.value);
    }
    if (goal.present) {
      map['goal'] = Variable<String>(goal.value);
    }
    if (lastMessage.present) {
      map['last_message'] = Variable<String>(lastMessage.value);
    }
    if (lastTime.present) {
      map['last_time'] = Variable<String>(lastTime.value);
    }
    if (active.present) {
      map['active'] = Variable<bool>(active.value);
    }
    if (caloriesToday.present) {
      map['calories_today'] = Variable<int>(caloriesToday.value);
    }
    if (sodiumMg.present) {
      map['sodium_mg'] = Variable<int>(sodiumMg.value);
    }
    if (sugarG.present) {
      map['sugar_g'] = Variable<int>(sugarG.value);
    }
    if (lastRoutine.present) {
      map['last_routine'] = Variable<String>(lastRoutine.value);
    }
    if (weekCompletionJson.present) {
      map['week_completion_json'] = Variable<String>(weekCompletionJson.value);
    }
    if (sodiumWeekJson.present) {
      map['sodium_week_json'] = Variable<String>(sodiumWeekJson.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TrainerClientsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('avatar: $avatar, ')
          ..write('goal: $goal, ')
          ..write('lastMessage: $lastMessage, ')
          ..write('lastTime: $lastTime, ')
          ..write('active: $active, ')
          ..write('caloriesToday: $caloriesToday, ')
          ..write('sodiumMg: $sodiumMg, ')
          ..write('sugarG: $sugarG, ')
          ..write('lastRoutine: $lastRoutine, ')
          ..write('weekCompletionJson: $weekCompletionJson, ')
          ..write('sodiumWeekJson: $sodiumWeekJson, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ClientDietEntriesTable extends ClientDietEntries
    with TableInfo<$ClientDietEntriesTable, ClientDietEntryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ClientDietEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _clientIdMeta = const VerificationMeta(
    'clientId',
  );
  @override
  late final GeneratedColumn<String> clientId = GeneratedColumn<String>(
    'client_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mealMeta = const VerificationMeta('meal');
  @override
  late final GeneratedColumn<String> meal = GeneratedColumn<String>(
    'meal',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemsMeta = const VerificationMeta('items');
  @override
  late final GeneratedColumn<String> items = GeneratedColumn<String>(
    'items',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _caloriesMeta = const VerificationMeta(
    'calories',
  );
  @override
  late final GeneratedColumn<int> calories = GeneratedColumn<int>(
    'calories',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sodiumMgMeta = const VerificationMeta(
    'sodiumMg',
  );
  @override
  late final GeneratedColumn<int> sodiumMg = GeneratedColumn<int>(
    'sodium_mg',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
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
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    clientId,
    meal,
    items,
    calories,
    sodiumMg,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'client_diet_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<ClientDietEntryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('client_id')) {
      context.handle(
        _clientIdMeta,
        clientId.isAcceptableOrUnknown(data['client_id']!, _clientIdMeta),
      );
    } else if (isInserting) {
      context.missing(_clientIdMeta);
    }
    if (data.containsKey('meal')) {
      context.handle(
        _mealMeta,
        meal.isAcceptableOrUnknown(data['meal']!, _mealMeta),
      );
    } else if (isInserting) {
      context.missing(_mealMeta);
    }
    if (data.containsKey('items')) {
      context.handle(
        _itemsMeta,
        items.isAcceptableOrUnknown(data['items']!, _itemsMeta),
      );
    } else if (isInserting) {
      context.missing(_itemsMeta);
    }
    if (data.containsKey('calories')) {
      context.handle(
        _caloriesMeta,
        calories.isAcceptableOrUnknown(data['calories']!, _caloriesMeta),
      );
    } else if (isInserting) {
      context.missing(_caloriesMeta);
    }
    if (data.containsKey('sodium_mg')) {
      context.handle(
        _sodiumMgMeta,
        sodiumMg.isAcceptableOrUnknown(data['sodium_mg']!, _sodiumMgMeta),
      );
    } else if (isInserting) {
      context.missing(_sodiumMgMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ClientDietEntryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ClientDietEntryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      clientId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_id'],
      )!,
      meal: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meal'],
      )!,
      items: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}items'],
      )!,
      calories: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}calories'],
      )!,
      sodiumMg: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sodium_mg'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $ClientDietEntriesTable createAlias(String alias) {
    return $ClientDietEntriesTable(attachedDatabase, alias);
  }
}

class ClientDietEntryRow extends DataClass
    implements Insertable<ClientDietEntryRow> {
  final String id;
  final String clientId;
  final String meal;
  final String items;
  final int calories;
  final int sodiumMg;
  final int sortOrder;
  const ClientDietEntryRow({
    required this.id,
    required this.clientId,
    required this.meal,
    required this.items,
    required this.calories,
    required this.sodiumMg,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['client_id'] = Variable<String>(clientId);
    map['meal'] = Variable<String>(meal);
    map['items'] = Variable<String>(items);
    map['calories'] = Variable<int>(calories);
    map['sodium_mg'] = Variable<int>(sodiumMg);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  ClientDietEntriesCompanion toCompanion(bool nullToAbsent) {
    return ClientDietEntriesCompanion(
      id: Value(id),
      clientId: Value(clientId),
      meal: Value(meal),
      items: Value(items),
      calories: Value(calories),
      sodiumMg: Value(sodiumMg),
      sortOrder: Value(sortOrder),
    );
  }

  factory ClientDietEntryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ClientDietEntryRow(
      id: serializer.fromJson<String>(json['id']),
      clientId: serializer.fromJson<String>(json['clientId']),
      meal: serializer.fromJson<String>(json['meal']),
      items: serializer.fromJson<String>(json['items']),
      calories: serializer.fromJson<int>(json['calories']),
      sodiumMg: serializer.fromJson<int>(json['sodiumMg']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'clientId': serializer.toJson<String>(clientId),
      'meal': serializer.toJson<String>(meal),
      'items': serializer.toJson<String>(items),
      'calories': serializer.toJson<int>(calories),
      'sodiumMg': serializer.toJson<int>(sodiumMg),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  ClientDietEntryRow copyWith({
    String? id,
    String? clientId,
    String? meal,
    String? items,
    int? calories,
    int? sodiumMg,
    int? sortOrder,
  }) => ClientDietEntryRow(
    id: id ?? this.id,
    clientId: clientId ?? this.clientId,
    meal: meal ?? this.meal,
    items: items ?? this.items,
    calories: calories ?? this.calories,
    sodiumMg: sodiumMg ?? this.sodiumMg,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  ClientDietEntryRow copyWithCompanion(ClientDietEntriesCompanion data) {
    return ClientDietEntryRow(
      id: data.id.present ? data.id.value : this.id,
      clientId: data.clientId.present ? data.clientId.value : this.clientId,
      meal: data.meal.present ? data.meal.value : this.meal,
      items: data.items.present ? data.items.value : this.items,
      calories: data.calories.present ? data.calories.value : this.calories,
      sodiumMg: data.sodiumMg.present ? data.sodiumMg.value : this.sodiumMg,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ClientDietEntryRow(')
          ..write('id: $id, ')
          ..write('clientId: $clientId, ')
          ..write('meal: $meal, ')
          ..write('items: $items, ')
          ..write('calories: $calories, ')
          ..write('sodiumMg: $sodiumMg, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, clientId, meal, items, calories, sodiumMg, sortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ClientDietEntryRow &&
          other.id == this.id &&
          other.clientId == this.clientId &&
          other.meal == this.meal &&
          other.items == this.items &&
          other.calories == this.calories &&
          other.sodiumMg == this.sodiumMg &&
          other.sortOrder == this.sortOrder);
}

class ClientDietEntriesCompanion extends UpdateCompanion<ClientDietEntryRow> {
  final Value<String> id;
  final Value<String> clientId;
  final Value<String> meal;
  final Value<String> items;
  final Value<int> calories;
  final Value<int> sodiumMg;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const ClientDietEntriesCompanion({
    this.id = const Value.absent(),
    this.clientId = const Value.absent(),
    this.meal = const Value.absent(),
    this.items = const Value.absent(),
    this.calories = const Value.absent(),
    this.sodiumMg = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ClientDietEntriesCompanion.insert({
    required String id,
    required String clientId,
    required String meal,
    required String items,
    required int calories,
    required int sodiumMg,
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       clientId = Value(clientId),
       meal = Value(meal),
       items = Value(items),
       calories = Value(calories),
       sodiumMg = Value(sodiumMg);
  static Insertable<ClientDietEntryRow> custom({
    Expression<String>? id,
    Expression<String>? clientId,
    Expression<String>? meal,
    Expression<String>? items,
    Expression<int>? calories,
    Expression<int>? sodiumMg,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (clientId != null) 'client_id': clientId,
      if (meal != null) 'meal': meal,
      if (items != null) 'items': items,
      if (calories != null) 'calories': calories,
      if (sodiumMg != null) 'sodium_mg': sodiumMg,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ClientDietEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? clientId,
    Value<String>? meal,
    Value<String>? items,
    Value<int>? calories,
    Value<int>? sodiumMg,
    Value<int>? sortOrder,
    Value<int>? rowid,
  }) {
    return ClientDietEntriesCompanion(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      meal: meal ?? this.meal,
      items: items ?? this.items,
      calories: calories ?? this.calories,
      sodiumMg: sodiumMg ?? this.sodiumMg,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (clientId.present) {
      map['client_id'] = Variable<String>(clientId.value);
    }
    if (meal.present) {
      map['meal'] = Variable<String>(meal.value);
    }
    if (items.present) {
      map['items'] = Variable<String>(items.value);
    }
    if (calories.present) {
      map['calories'] = Variable<int>(calories.value);
    }
    if (sodiumMg.present) {
      map['sodium_mg'] = Variable<int>(sodiumMg.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ClientDietEntriesCompanion(')
          ..write('id: $id, ')
          ..write('clientId: $clientId, ')
          ..write('meal: $meal, ')
          ..write('items: $items, ')
          ..write('calories: $calories, ')
          ..write('sodiumMg: $sodiumMg, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ClientAiRoutinesTable extends ClientAiRoutines
    with TableInfo<$ClientAiRoutinesTable, ClientAiRoutineRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ClientAiRoutinesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _clientIdMeta = const VerificationMeta(
    'clientId',
  );
  @override
  late final GeneratedColumn<String> clientId = GeneratedColumn<String>(
    'client_id',
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
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _minutesMeta = const VerificationMeta(
    'minutes',
  );
  @override
  late final GeneratedColumn<int> minutes = GeneratedColumn<int>(
    'minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
    'reason',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    clientId,
    name,
    minutes,
    type,
    reason,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'client_ai_routines';
  @override
  VerificationContext validateIntegrity(
    Insertable<ClientAiRoutineRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('client_id')) {
      context.handle(
        _clientIdMeta,
        clientId.isAcceptableOrUnknown(data['client_id']!, _clientIdMeta),
      );
    } else if (isInserting) {
      context.missing(_clientIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('minutes')) {
      context.handle(
        _minutesMeta,
        minutes.isAcceptableOrUnknown(data['minutes']!, _minutesMeta),
      );
    } else if (isInserting) {
      context.missing(_minutesMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('reason')) {
      context.handle(
        _reasonMeta,
        reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta),
      );
    } else if (isInserting) {
      context.missing(_reasonMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ClientAiRoutineRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ClientAiRoutineRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      clientId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      minutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}minutes'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      reason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $ClientAiRoutinesTable createAlias(String alias) {
    return $ClientAiRoutinesTable(attachedDatabase, alias);
  }
}

class ClientAiRoutineRow extends DataClass
    implements Insertable<ClientAiRoutineRow> {
  final String id;
  final String clientId;
  final String name;
  final int minutes;
  final String type;
  final String reason;
  final int sortOrder;
  const ClientAiRoutineRow({
    required this.id,
    required this.clientId,
    required this.name,
    required this.minutes,
    required this.type,
    required this.reason,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['client_id'] = Variable<String>(clientId);
    map['name'] = Variable<String>(name);
    map['minutes'] = Variable<int>(minutes);
    map['type'] = Variable<String>(type);
    map['reason'] = Variable<String>(reason);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  ClientAiRoutinesCompanion toCompanion(bool nullToAbsent) {
    return ClientAiRoutinesCompanion(
      id: Value(id),
      clientId: Value(clientId),
      name: Value(name),
      minutes: Value(minutes),
      type: Value(type),
      reason: Value(reason),
      sortOrder: Value(sortOrder),
    );
  }

  factory ClientAiRoutineRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ClientAiRoutineRow(
      id: serializer.fromJson<String>(json['id']),
      clientId: serializer.fromJson<String>(json['clientId']),
      name: serializer.fromJson<String>(json['name']),
      minutes: serializer.fromJson<int>(json['minutes']),
      type: serializer.fromJson<String>(json['type']),
      reason: serializer.fromJson<String>(json['reason']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'clientId': serializer.toJson<String>(clientId),
      'name': serializer.toJson<String>(name),
      'minutes': serializer.toJson<int>(minutes),
      'type': serializer.toJson<String>(type),
      'reason': serializer.toJson<String>(reason),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  ClientAiRoutineRow copyWith({
    String? id,
    String? clientId,
    String? name,
    int? minutes,
    String? type,
    String? reason,
    int? sortOrder,
  }) => ClientAiRoutineRow(
    id: id ?? this.id,
    clientId: clientId ?? this.clientId,
    name: name ?? this.name,
    minutes: minutes ?? this.minutes,
    type: type ?? this.type,
    reason: reason ?? this.reason,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  ClientAiRoutineRow copyWithCompanion(ClientAiRoutinesCompanion data) {
    return ClientAiRoutineRow(
      id: data.id.present ? data.id.value : this.id,
      clientId: data.clientId.present ? data.clientId.value : this.clientId,
      name: data.name.present ? data.name.value : this.name,
      minutes: data.minutes.present ? data.minutes.value : this.minutes,
      type: data.type.present ? data.type.value : this.type,
      reason: data.reason.present ? data.reason.value : this.reason,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ClientAiRoutineRow(')
          ..write('id: $id, ')
          ..write('clientId: $clientId, ')
          ..write('name: $name, ')
          ..write('minutes: $minutes, ')
          ..write('type: $type, ')
          ..write('reason: $reason, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, clientId, name, minutes, type, reason, sortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ClientAiRoutineRow &&
          other.id == this.id &&
          other.clientId == this.clientId &&
          other.name == this.name &&
          other.minutes == this.minutes &&
          other.type == this.type &&
          other.reason == this.reason &&
          other.sortOrder == this.sortOrder);
}

class ClientAiRoutinesCompanion extends UpdateCompanion<ClientAiRoutineRow> {
  final Value<String> id;
  final Value<String> clientId;
  final Value<String> name;
  final Value<int> minutes;
  final Value<String> type;
  final Value<String> reason;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const ClientAiRoutinesCompanion({
    this.id = const Value.absent(),
    this.clientId = const Value.absent(),
    this.name = const Value.absent(),
    this.minutes = const Value.absent(),
    this.type = const Value.absent(),
    this.reason = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ClientAiRoutinesCompanion.insert({
    required String id,
    required String clientId,
    required String name,
    required int minutes,
    required String type,
    required String reason,
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       clientId = Value(clientId),
       name = Value(name),
       minutes = Value(minutes),
       type = Value(type),
       reason = Value(reason);
  static Insertable<ClientAiRoutineRow> custom({
    Expression<String>? id,
    Expression<String>? clientId,
    Expression<String>? name,
    Expression<int>? minutes,
    Expression<String>? type,
    Expression<String>? reason,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (clientId != null) 'client_id': clientId,
      if (name != null) 'name': name,
      if (minutes != null) 'minutes': minutes,
      if (type != null) 'type': type,
      if (reason != null) 'reason': reason,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ClientAiRoutinesCompanion copyWith({
    Value<String>? id,
    Value<String>? clientId,
    Value<String>? name,
    Value<int>? minutes,
    Value<String>? type,
    Value<String>? reason,
    Value<int>? sortOrder,
    Value<int>? rowid,
  }) {
    return ClientAiRoutinesCompanion(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      name: name ?? this.name,
      minutes: minutes ?? this.minutes,
      type: type ?? this.type,
      reason: reason ?? this.reason,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (clientId.present) {
      map['client_id'] = Variable<String>(clientId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (minutes.present) {
      map['minutes'] = Variable<int>(minutes.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ClientAiRoutinesCompanion(')
          ..write('id: $id, ')
          ..write('clientId: $clientId, ')
          ..write('name: $name, ')
          ..write('minutes: $minutes, ')
          ..write('type: $type, ')
          ..write('reason: $reason, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ClientRoutineHistoryTable extends ClientRoutineHistory
    with TableInfo<$ClientRoutineHistoryTable, ClientRoutineHistoryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ClientRoutineHistoryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _clientIdMeta = const VerificationMeta(
    'clientId',
  );
  @override
  late final GeneratedColumn<String> clientId = GeneratedColumn<String>(
    'client_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateLabelMeta = const VerificationMeta(
    'dateLabel',
  );
  @override
  late final GeneratedColumn<String> dateLabel = GeneratedColumn<String>(
    'date_label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completionRateMeta = const VerificationMeta(
    'completionRate',
  );
  @override
  late final GeneratedColumn<int> completionRate = GeneratedColumn<int>(
    'completion_rate',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _exercisesJsonMeta = const VerificationMeta(
    'exercisesJson',
  );
  @override
  late final GeneratedColumn<String> exercisesJson = GeneratedColumn<String>(
    'exercises_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _clientFeedbackMeta = const VerificationMeta(
    'clientFeedback',
  );
  @override
  late final GeneratedColumn<String> clientFeedback = GeneratedColumn<String>(
    'client_feedback',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _trainerNoteMeta = const VerificationMeta(
    'trainerNote',
  );
  @override
  late final GeneratedColumn<String> trainerNote = GeneratedColumn<String>(
    'trainer_note',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
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
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    clientId,
    dateLabel,
    label,
    completionRate,
    exercisesJson,
    clientFeedback,
    trainerNote,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'client_routine_history';
  @override
  VerificationContext validateIntegrity(
    Insertable<ClientRoutineHistoryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('client_id')) {
      context.handle(
        _clientIdMeta,
        clientId.isAcceptableOrUnknown(data['client_id']!, _clientIdMeta),
      );
    } else if (isInserting) {
      context.missing(_clientIdMeta);
    }
    if (data.containsKey('date_label')) {
      context.handle(
        _dateLabelMeta,
        dateLabel.isAcceptableOrUnknown(data['date_label']!, _dateLabelMeta),
      );
    } else if (isInserting) {
      context.missing(_dateLabelMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('completion_rate')) {
      context.handle(
        _completionRateMeta,
        completionRate.isAcceptableOrUnknown(
          data['completion_rate']!,
          _completionRateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_completionRateMeta);
    }
    if (data.containsKey('exercises_json')) {
      context.handle(
        _exercisesJsonMeta,
        exercisesJson.isAcceptableOrUnknown(
          data['exercises_json']!,
          _exercisesJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_exercisesJsonMeta);
    }
    if (data.containsKey('client_feedback')) {
      context.handle(
        _clientFeedbackMeta,
        clientFeedback.isAcceptableOrUnknown(
          data['client_feedback']!,
          _clientFeedbackMeta,
        ),
      );
    }
    if (data.containsKey('trainer_note')) {
      context.handle(
        _trainerNoteMeta,
        trainerNote.isAcceptableOrUnknown(
          data['trainer_note']!,
          _trainerNoteMeta,
        ),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ClientRoutineHistoryRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ClientRoutineHistoryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      clientId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_id'],
      )!,
      dateLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date_label'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      completionRate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completion_rate'],
      )!,
      exercisesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exercises_json'],
      )!,
      clientFeedback: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_feedback'],
      )!,
      trainerNote: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}trainer_note'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $ClientRoutineHistoryTable createAlias(String alias) {
    return $ClientRoutineHistoryTable(attachedDatabase, alias);
  }
}

class ClientRoutineHistoryRow extends DataClass
    implements Insertable<ClientRoutineHistoryRow> {
  final String id;
  final String clientId;
  final String dateLabel;
  final String label;
  final int completionRate;
  final String exercisesJson;
  final String clientFeedback;
  final String trainerNote;
  final int sortOrder;
  const ClientRoutineHistoryRow({
    required this.id,
    required this.clientId,
    required this.dateLabel,
    required this.label,
    required this.completionRate,
    required this.exercisesJson,
    required this.clientFeedback,
    required this.trainerNote,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['client_id'] = Variable<String>(clientId);
    map['date_label'] = Variable<String>(dateLabel);
    map['label'] = Variable<String>(label);
    map['completion_rate'] = Variable<int>(completionRate);
    map['exercises_json'] = Variable<String>(exercisesJson);
    map['client_feedback'] = Variable<String>(clientFeedback);
    map['trainer_note'] = Variable<String>(trainerNote);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  ClientRoutineHistoryCompanion toCompanion(bool nullToAbsent) {
    return ClientRoutineHistoryCompanion(
      id: Value(id),
      clientId: Value(clientId),
      dateLabel: Value(dateLabel),
      label: Value(label),
      completionRate: Value(completionRate),
      exercisesJson: Value(exercisesJson),
      clientFeedback: Value(clientFeedback),
      trainerNote: Value(trainerNote),
      sortOrder: Value(sortOrder),
    );
  }

  factory ClientRoutineHistoryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ClientRoutineHistoryRow(
      id: serializer.fromJson<String>(json['id']),
      clientId: serializer.fromJson<String>(json['clientId']),
      dateLabel: serializer.fromJson<String>(json['dateLabel']),
      label: serializer.fromJson<String>(json['label']),
      completionRate: serializer.fromJson<int>(json['completionRate']),
      exercisesJson: serializer.fromJson<String>(json['exercisesJson']),
      clientFeedback: serializer.fromJson<String>(json['clientFeedback']),
      trainerNote: serializer.fromJson<String>(json['trainerNote']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'clientId': serializer.toJson<String>(clientId),
      'dateLabel': serializer.toJson<String>(dateLabel),
      'label': serializer.toJson<String>(label),
      'completionRate': serializer.toJson<int>(completionRate),
      'exercisesJson': serializer.toJson<String>(exercisesJson),
      'clientFeedback': serializer.toJson<String>(clientFeedback),
      'trainerNote': serializer.toJson<String>(trainerNote),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  ClientRoutineHistoryRow copyWith({
    String? id,
    String? clientId,
    String? dateLabel,
    String? label,
    int? completionRate,
    String? exercisesJson,
    String? clientFeedback,
    String? trainerNote,
    int? sortOrder,
  }) => ClientRoutineHistoryRow(
    id: id ?? this.id,
    clientId: clientId ?? this.clientId,
    dateLabel: dateLabel ?? this.dateLabel,
    label: label ?? this.label,
    completionRate: completionRate ?? this.completionRate,
    exercisesJson: exercisesJson ?? this.exercisesJson,
    clientFeedback: clientFeedback ?? this.clientFeedback,
    trainerNote: trainerNote ?? this.trainerNote,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  ClientRoutineHistoryRow copyWithCompanion(
    ClientRoutineHistoryCompanion data,
  ) {
    return ClientRoutineHistoryRow(
      id: data.id.present ? data.id.value : this.id,
      clientId: data.clientId.present ? data.clientId.value : this.clientId,
      dateLabel: data.dateLabel.present ? data.dateLabel.value : this.dateLabel,
      label: data.label.present ? data.label.value : this.label,
      completionRate: data.completionRate.present
          ? data.completionRate.value
          : this.completionRate,
      exercisesJson: data.exercisesJson.present
          ? data.exercisesJson.value
          : this.exercisesJson,
      clientFeedback: data.clientFeedback.present
          ? data.clientFeedback.value
          : this.clientFeedback,
      trainerNote: data.trainerNote.present
          ? data.trainerNote.value
          : this.trainerNote,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ClientRoutineHistoryRow(')
          ..write('id: $id, ')
          ..write('clientId: $clientId, ')
          ..write('dateLabel: $dateLabel, ')
          ..write('label: $label, ')
          ..write('completionRate: $completionRate, ')
          ..write('exercisesJson: $exercisesJson, ')
          ..write('clientFeedback: $clientFeedback, ')
          ..write('trainerNote: $trainerNote, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    clientId,
    dateLabel,
    label,
    completionRate,
    exercisesJson,
    clientFeedback,
    trainerNote,
    sortOrder,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ClientRoutineHistoryRow &&
          other.id == this.id &&
          other.clientId == this.clientId &&
          other.dateLabel == this.dateLabel &&
          other.label == this.label &&
          other.completionRate == this.completionRate &&
          other.exercisesJson == this.exercisesJson &&
          other.clientFeedback == this.clientFeedback &&
          other.trainerNote == this.trainerNote &&
          other.sortOrder == this.sortOrder);
}

class ClientRoutineHistoryCompanion
    extends UpdateCompanion<ClientRoutineHistoryRow> {
  final Value<String> id;
  final Value<String> clientId;
  final Value<String> dateLabel;
  final Value<String> label;
  final Value<int> completionRate;
  final Value<String> exercisesJson;
  final Value<String> clientFeedback;
  final Value<String> trainerNote;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const ClientRoutineHistoryCompanion({
    this.id = const Value.absent(),
    this.clientId = const Value.absent(),
    this.dateLabel = const Value.absent(),
    this.label = const Value.absent(),
    this.completionRate = const Value.absent(),
    this.exercisesJson = const Value.absent(),
    this.clientFeedback = const Value.absent(),
    this.trainerNote = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ClientRoutineHistoryCompanion.insert({
    required String id,
    required String clientId,
    required String dateLabel,
    required String label,
    required int completionRate,
    required String exercisesJson,
    this.clientFeedback = const Value.absent(),
    this.trainerNote = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       clientId = Value(clientId),
       dateLabel = Value(dateLabel),
       label = Value(label),
       completionRate = Value(completionRate),
       exercisesJson = Value(exercisesJson);
  static Insertable<ClientRoutineHistoryRow> custom({
    Expression<String>? id,
    Expression<String>? clientId,
    Expression<String>? dateLabel,
    Expression<String>? label,
    Expression<int>? completionRate,
    Expression<String>? exercisesJson,
    Expression<String>? clientFeedback,
    Expression<String>? trainerNote,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (clientId != null) 'client_id': clientId,
      if (dateLabel != null) 'date_label': dateLabel,
      if (label != null) 'label': label,
      if (completionRate != null) 'completion_rate': completionRate,
      if (exercisesJson != null) 'exercises_json': exercisesJson,
      if (clientFeedback != null) 'client_feedback': clientFeedback,
      if (trainerNote != null) 'trainer_note': trainerNote,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ClientRoutineHistoryCompanion copyWith({
    Value<String>? id,
    Value<String>? clientId,
    Value<String>? dateLabel,
    Value<String>? label,
    Value<int>? completionRate,
    Value<String>? exercisesJson,
    Value<String>? clientFeedback,
    Value<String>? trainerNote,
    Value<int>? sortOrder,
    Value<int>? rowid,
  }) {
    return ClientRoutineHistoryCompanion(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      dateLabel: dateLabel ?? this.dateLabel,
      label: label ?? this.label,
      completionRate: completionRate ?? this.completionRate,
      exercisesJson: exercisesJson ?? this.exercisesJson,
      clientFeedback: clientFeedback ?? this.clientFeedback,
      trainerNote: trainerNote ?? this.trainerNote,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (clientId.present) {
      map['client_id'] = Variable<String>(clientId.value);
    }
    if (dateLabel.present) {
      map['date_label'] = Variable<String>(dateLabel.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (completionRate.present) {
      map['completion_rate'] = Variable<int>(completionRate.value);
    }
    if (exercisesJson.present) {
      map['exercises_json'] = Variable<String>(exercisesJson.value);
    }
    if (clientFeedback.present) {
      map['client_feedback'] = Variable<String>(clientFeedback.value);
    }
    if (trainerNote.present) {
      map['trainer_note'] = Variable<String>(trainerNote.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ClientRoutineHistoryCompanion(')
          ..write('id: $id, ')
          ..write('clientId: $clientId, ')
          ..write('dateLabel: $dateLabel, ')
          ..write('label: $label, ')
          ..write('completionRate: $completionRate, ')
          ..write('exercisesJson: $exercisesJson, ')
          ..write('clientFeedback: $clientFeedback, ')
          ..write('trainerNote: $trainerNote, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ClientChatMessagesTable extends ClientChatMessages
    with TableInfo<$ClientChatMessagesTable, ClientChatMessageRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ClientChatMessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _clientIdMeta = const VerificationMeta(
    'clientId',
  );
  @override
  late final GeneratedColumn<String> clientId = GeneratedColumn<String>(
    'client_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _senderMeta = const VerificationMeta('sender');
  @override
  late final GeneratedColumn<String> sender = GeneratedColumn<String>(
    'sender',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timeLabelMeta = const VerificationMeta(
    'timeLabel',
  );
  @override
  late final GeneratedColumn<String> timeLabel = GeneratedColumn<String>(
    'time_label',
    aliasedName,
    false,
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    clientId,
    sender,
    body,
    timeLabel,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'client_chat_messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<ClientChatMessageRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('client_id')) {
      context.handle(
        _clientIdMeta,
        clientId.isAcceptableOrUnknown(data['client_id']!, _clientIdMeta),
      );
    } else if (isInserting) {
      context.missing(_clientIdMeta);
    }
    if (data.containsKey('sender')) {
      context.handle(
        _senderMeta,
        sender.isAcceptableOrUnknown(data['sender']!, _senderMeta),
      );
    } else if (isInserting) {
      context.missing(_senderMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('time_label')) {
      context.handle(
        _timeLabelMeta,
        timeLabel.isAcceptableOrUnknown(data['time_label']!, _timeLabelMeta),
      );
    } else if (isInserting) {
      context.missing(_timeLabelMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ClientChatMessageRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ClientChatMessageRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      clientId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_id'],
      )!,
      sender: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sender'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      timeLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}time_label'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ClientChatMessagesTable createAlias(String alias) {
    return $ClientChatMessagesTable(attachedDatabase, alias);
  }
}

class ClientChatMessageRow extends DataClass
    implements Insertable<ClientChatMessageRow> {
  final String id;
  final String clientId;
  final String sender;
  final String body;
  final String timeLabel;
  final DateTime createdAt;
  const ClientChatMessageRow({
    required this.id,
    required this.clientId,
    required this.sender,
    required this.body,
    required this.timeLabel,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['client_id'] = Variable<String>(clientId);
    map['sender'] = Variable<String>(sender);
    map['body'] = Variable<String>(body);
    map['time_label'] = Variable<String>(timeLabel);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ClientChatMessagesCompanion toCompanion(bool nullToAbsent) {
    return ClientChatMessagesCompanion(
      id: Value(id),
      clientId: Value(clientId),
      sender: Value(sender),
      body: Value(body),
      timeLabel: Value(timeLabel),
      createdAt: Value(createdAt),
    );
  }

  factory ClientChatMessageRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ClientChatMessageRow(
      id: serializer.fromJson<String>(json['id']),
      clientId: serializer.fromJson<String>(json['clientId']),
      sender: serializer.fromJson<String>(json['sender']),
      body: serializer.fromJson<String>(json['body']),
      timeLabel: serializer.fromJson<String>(json['timeLabel']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'clientId': serializer.toJson<String>(clientId),
      'sender': serializer.toJson<String>(sender),
      'body': serializer.toJson<String>(body),
      'timeLabel': serializer.toJson<String>(timeLabel),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ClientChatMessageRow copyWith({
    String? id,
    String? clientId,
    String? sender,
    String? body,
    String? timeLabel,
    DateTime? createdAt,
  }) => ClientChatMessageRow(
    id: id ?? this.id,
    clientId: clientId ?? this.clientId,
    sender: sender ?? this.sender,
    body: body ?? this.body,
    timeLabel: timeLabel ?? this.timeLabel,
    createdAt: createdAt ?? this.createdAt,
  );
  ClientChatMessageRow copyWithCompanion(ClientChatMessagesCompanion data) {
    return ClientChatMessageRow(
      id: data.id.present ? data.id.value : this.id,
      clientId: data.clientId.present ? data.clientId.value : this.clientId,
      sender: data.sender.present ? data.sender.value : this.sender,
      body: data.body.present ? data.body.value : this.body,
      timeLabel: data.timeLabel.present ? data.timeLabel.value : this.timeLabel,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ClientChatMessageRow(')
          ..write('id: $id, ')
          ..write('clientId: $clientId, ')
          ..write('sender: $sender, ')
          ..write('body: $body, ')
          ..write('timeLabel: $timeLabel, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, clientId, sender, body, timeLabel, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ClientChatMessageRow &&
          other.id == this.id &&
          other.clientId == this.clientId &&
          other.sender == this.sender &&
          other.body == this.body &&
          other.timeLabel == this.timeLabel &&
          other.createdAt == this.createdAt);
}

class ClientChatMessagesCompanion
    extends UpdateCompanion<ClientChatMessageRow> {
  final Value<String> id;
  final Value<String> clientId;
  final Value<String> sender;
  final Value<String> body;
  final Value<String> timeLabel;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ClientChatMessagesCompanion({
    this.id = const Value.absent(),
    this.clientId = const Value.absent(),
    this.sender = const Value.absent(),
    this.body = const Value.absent(),
    this.timeLabel = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ClientChatMessagesCompanion.insert({
    required String id,
    required String clientId,
    required String sender,
    required String body,
    required String timeLabel,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       clientId = Value(clientId),
       sender = Value(sender),
       body = Value(body),
       timeLabel = Value(timeLabel),
       createdAt = Value(createdAt);
  static Insertable<ClientChatMessageRow> custom({
    Expression<String>? id,
    Expression<String>? clientId,
    Expression<String>? sender,
    Expression<String>? body,
    Expression<String>? timeLabel,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (clientId != null) 'client_id': clientId,
      if (sender != null) 'sender': sender,
      if (body != null) 'body': body,
      if (timeLabel != null) 'time_label': timeLabel,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ClientChatMessagesCompanion copyWith({
    Value<String>? id,
    Value<String>? clientId,
    Value<String>? sender,
    Value<String>? body,
    Value<String>? timeLabel,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return ClientChatMessagesCompanion(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      sender: sender ?? this.sender,
      body: body ?? this.body,
      timeLabel: timeLabel ?? this.timeLabel,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (clientId.present) {
      map['client_id'] = Variable<String>(clientId.value);
    }
    if (sender.present) {
      map['sender'] = Variable<String>(sender.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (timeLabel.present) {
      map['time_label'] = Variable<String>(timeLabel.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ClientChatMessagesCompanion(')
          ..write('id: $id, ')
          ..write('clientId: $clientId, ')
          ..write('sender: $sender, ')
          ..write('body: $body, ')
          ..write('timeLabel: $timeLabel, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TrainerScheduleEntriesTable extends TrainerScheduleEntries
    with TableInfo<$TrainerScheduleEntriesTable, TrainerScheduleRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TrainerScheduleEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timeMeta = const VerificationMeta('time');
  @override
  late final GeneratedColumn<String> time = GeneratedColumn<String>(
    'time',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _clientNameMeta = const VerificationMeta(
    'clientName',
  );
  @override
  late final GeneratedColumn<String> clientName = GeneratedColumn<String>(
    'client_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _durationMinutesMeta = const VerificationMeta(
    'durationMinutes',
  );
  @override
  late final GeneratedColumn<int> durationMinutes = GeneratedColumn<int>(
    'duration_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _programJsonMeta = const VerificationMeta(
    'programJson',
  );
  @override
  late final GeneratedColumn<String> programJson = GeneratedColumn<String>(
    'program_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
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
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    date,
    time,
    clientName,
    type,
    durationMinutes,
    status,
    note,
    programJson,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'trainer_schedule_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<TrainerScheduleRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('time')) {
      context.handle(
        _timeMeta,
        time.isAcceptableOrUnknown(data['time']!, _timeMeta),
      );
    } else if (isInserting) {
      context.missing(_timeMeta);
    }
    if (data.containsKey('client_name')) {
      context.handle(
        _clientNameMeta,
        clientName.isAcceptableOrUnknown(data['client_name']!, _clientNameMeta),
      );
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    }
    if (data.containsKey('duration_minutes')) {
      context.handle(
        _durationMinutesMeta,
        durationMinutes.isAcceptableOrUnknown(
          data['duration_minutes']!,
          _durationMinutesMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('program_json')) {
      context.handle(
        _programJsonMeta,
        programJson.isAcceptableOrUnknown(
          data['program_json']!,
          _programJsonMeta,
        ),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TrainerScheduleRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TrainerScheduleRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
      time: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}time'],
      )!,
      clientName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_name'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      durationMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_minutes'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      )!,
      programJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}program_json'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $TrainerScheduleEntriesTable createAlias(String alias) {
    return $TrainerScheduleEntriesTable(attachedDatabase, alias);
  }
}

class TrainerScheduleRow extends DataClass
    implements Insertable<TrainerScheduleRow> {
  final String id;
  final String date;
  final String time;
  final String clientName;
  final String type;
  final int durationMinutes;
  final String status;
  final String note;
  final String programJson;
  final int sortOrder;
  const TrainerScheduleRow({
    required this.id,
    required this.date,
    required this.time,
    required this.clientName,
    required this.type,
    required this.durationMinutes,
    required this.status,
    required this.note,
    required this.programJson,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['date'] = Variable<String>(date);
    map['time'] = Variable<String>(time);
    map['client_name'] = Variable<String>(clientName);
    map['type'] = Variable<String>(type);
    map['duration_minutes'] = Variable<int>(durationMinutes);
    map['status'] = Variable<String>(status);
    map['note'] = Variable<String>(note);
    map['program_json'] = Variable<String>(programJson);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  TrainerScheduleEntriesCompanion toCompanion(bool nullToAbsent) {
    return TrainerScheduleEntriesCompanion(
      id: Value(id),
      date: Value(date),
      time: Value(time),
      clientName: Value(clientName),
      type: Value(type),
      durationMinutes: Value(durationMinutes),
      status: Value(status),
      note: Value(note),
      programJson: Value(programJson),
      sortOrder: Value(sortOrder),
    );
  }

  factory TrainerScheduleRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TrainerScheduleRow(
      id: serializer.fromJson<String>(json['id']),
      date: serializer.fromJson<String>(json['date']),
      time: serializer.fromJson<String>(json['time']),
      clientName: serializer.fromJson<String>(json['clientName']),
      type: serializer.fromJson<String>(json['type']),
      durationMinutes: serializer.fromJson<int>(json['durationMinutes']),
      status: serializer.fromJson<String>(json['status']),
      note: serializer.fromJson<String>(json['note']),
      programJson: serializer.fromJson<String>(json['programJson']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'date': serializer.toJson<String>(date),
      'time': serializer.toJson<String>(time),
      'clientName': serializer.toJson<String>(clientName),
      'type': serializer.toJson<String>(type),
      'durationMinutes': serializer.toJson<int>(durationMinutes),
      'status': serializer.toJson<String>(status),
      'note': serializer.toJson<String>(note),
      'programJson': serializer.toJson<String>(programJson),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  TrainerScheduleRow copyWith({
    String? id,
    String? date,
    String? time,
    String? clientName,
    String? type,
    int? durationMinutes,
    String? status,
    String? note,
    String? programJson,
    int? sortOrder,
  }) => TrainerScheduleRow(
    id: id ?? this.id,
    date: date ?? this.date,
    time: time ?? this.time,
    clientName: clientName ?? this.clientName,
    type: type ?? this.type,
    durationMinutes: durationMinutes ?? this.durationMinutes,
    status: status ?? this.status,
    note: note ?? this.note,
    programJson: programJson ?? this.programJson,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  TrainerScheduleRow copyWithCompanion(TrainerScheduleEntriesCompanion data) {
    return TrainerScheduleRow(
      id: data.id.present ? data.id.value : this.id,
      date: data.date.present ? data.date.value : this.date,
      time: data.time.present ? data.time.value : this.time,
      clientName: data.clientName.present
          ? data.clientName.value
          : this.clientName,
      type: data.type.present ? data.type.value : this.type,
      durationMinutes: data.durationMinutes.present
          ? data.durationMinutes.value
          : this.durationMinutes,
      status: data.status.present ? data.status.value : this.status,
      note: data.note.present ? data.note.value : this.note,
      programJson: data.programJson.present
          ? data.programJson.value
          : this.programJson,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TrainerScheduleRow(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('time: $time, ')
          ..write('clientName: $clientName, ')
          ..write('type: $type, ')
          ..write('durationMinutes: $durationMinutes, ')
          ..write('status: $status, ')
          ..write('note: $note, ')
          ..write('programJson: $programJson, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    date,
    time,
    clientName,
    type,
    durationMinutes,
    status,
    note,
    programJson,
    sortOrder,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TrainerScheduleRow &&
          other.id == this.id &&
          other.date == this.date &&
          other.time == this.time &&
          other.clientName == this.clientName &&
          other.type == this.type &&
          other.durationMinutes == this.durationMinutes &&
          other.status == this.status &&
          other.note == this.note &&
          other.programJson == this.programJson &&
          other.sortOrder == this.sortOrder);
}

class TrainerScheduleEntriesCompanion
    extends UpdateCompanion<TrainerScheduleRow> {
  final Value<String> id;
  final Value<String> date;
  final Value<String> time;
  final Value<String> clientName;
  final Value<String> type;
  final Value<int> durationMinutes;
  final Value<String> status;
  final Value<String> note;
  final Value<String> programJson;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const TrainerScheduleEntriesCompanion({
    this.id = const Value.absent(),
    this.date = const Value.absent(),
    this.time = const Value.absent(),
    this.clientName = const Value.absent(),
    this.type = const Value.absent(),
    this.durationMinutes = const Value.absent(),
    this.status = const Value.absent(),
    this.note = const Value.absent(),
    this.programJson = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TrainerScheduleEntriesCompanion.insert({
    required String id,
    required String date,
    required String time,
    this.clientName = const Value.absent(),
    this.type = const Value.absent(),
    this.durationMinutes = const Value.absent(),
    required String status,
    this.note = const Value.absent(),
    this.programJson = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       date = Value(date),
       time = Value(time),
       status = Value(status);
  static Insertable<TrainerScheduleRow> custom({
    Expression<String>? id,
    Expression<String>? date,
    Expression<String>? time,
    Expression<String>? clientName,
    Expression<String>? type,
    Expression<int>? durationMinutes,
    Expression<String>? status,
    Expression<String>? note,
    Expression<String>? programJson,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (date != null) 'date': date,
      if (time != null) 'time': time,
      if (clientName != null) 'client_name': clientName,
      if (type != null) 'type': type,
      if (durationMinutes != null) 'duration_minutes': durationMinutes,
      if (status != null) 'status': status,
      if (note != null) 'note': note,
      if (programJson != null) 'program_json': programJson,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TrainerScheduleEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? date,
    Value<String>? time,
    Value<String>? clientName,
    Value<String>? type,
    Value<int>? durationMinutes,
    Value<String>? status,
    Value<String>? note,
    Value<String>? programJson,
    Value<int>? sortOrder,
    Value<int>? rowid,
  }) {
    return TrainerScheduleEntriesCompanion(
      id: id ?? this.id,
      date: date ?? this.date,
      time: time ?? this.time,
      clientName: clientName ?? this.clientName,
      type: type ?? this.type,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      status: status ?? this.status,
      note: note ?? this.note,
      programJson: programJson ?? this.programJson,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (time.present) {
      map['time'] = Variable<String>(time.value);
    }
    if (clientName.present) {
      map['client_name'] = Variable<String>(clientName.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (durationMinutes.present) {
      map['duration_minutes'] = Variable<int>(durationMinutes.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (programJson.present) {
      map['program_json'] = Variable<String>(programJson.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TrainerScheduleEntriesCompanion(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('time: $time, ')
          ..write('clientName: $clientName, ')
          ..write('type: $type, ')
          ..write('durationMinutes: $durationMinutes, ')
          ..write('status: $status, ')
          ..write('note: $note, ')
          ..write('programJson: $programJson, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $AppKeyValuesTable appKeyValues = $AppKeyValuesTable(this);
  late final $TrainerClientsTable trainerClients = $TrainerClientsTable(this);
  late final $ClientDietEntriesTable clientDietEntries =
      $ClientDietEntriesTable(this);
  late final $ClientAiRoutinesTable clientAiRoutines = $ClientAiRoutinesTable(
    this,
  );
  late final $ClientRoutineHistoryTable clientRoutineHistory =
      $ClientRoutineHistoryTable(this);
  late final $ClientChatMessagesTable clientChatMessages =
      $ClientChatMessagesTable(this);
  late final $TrainerScheduleEntriesTable trainerScheduleEntries =
      $TrainerScheduleEntriesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    appKeyValues,
    trainerClients,
    clientDietEntries,
    clientAiRoutines,
    clientRoutineHistory,
    clientChatMessages,
    trainerScheduleEntries,
  ];
}

typedef $$AppKeyValuesTableCreateCompanionBuilder =
    AppKeyValuesCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$AppKeyValuesTableUpdateCompanionBuilder =
    AppKeyValuesCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$AppKeyValuesTableFilterComposer
    extends Composer<_$AppDatabase, $AppKeyValuesTable> {
  $$AppKeyValuesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppKeyValuesTableOrderingComposer
    extends Composer<_$AppDatabase, $AppKeyValuesTable> {
  $$AppKeyValuesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppKeyValuesTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppKeyValuesTable> {
  $$AppKeyValuesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppKeyValuesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppKeyValuesTable,
          AppKeyValue,
          $$AppKeyValuesTableFilterComposer,
          $$AppKeyValuesTableOrderingComposer,
          $$AppKeyValuesTableAnnotationComposer,
          $$AppKeyValuesTableCreateCompanionBuilder,
          $$AppKeyValuesTableUpdateCompanionBuilder,
          (
            AppKeyValue,
            BaseReferences<_$AppDatabase, $AppKeyValuesTable, AppKeyValue>,
          ),
          AppKeyValue,
          PrefetchHooks Function()
        > {
  $$AppKeyValuesTableTableManager(_$AppDatabase db, $AppKeyValuesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppKeyValuesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppKeyValuesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppKeyValuesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppKeyValuesCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => AppKeyValuesCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppKeyValuesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppKeyValuesTable,
      AppKeyValue,
      $$AppKeyValuesTableFilterComposer,
      $$AppKeyValuesTableOrderingComposer,
      $$AppKeyValuesTableAnnotationComposer,
      $$AppKeyValuesTableCreateCompanionBuilder,
      $$AppKeyValuesTableUpdateCompanionBuilder,
      (
        AppKeyValue,
        BaseReferences<_$AppDatabase, $AppKeyValuesTable, AppKeyValue>,
      ),
      AppKeyValue,
      PrefetchHooks Function()
    >;
typedef $$TrainerClientsTableCreateCompanionBuilder =
    TrainerClientsCompanion Function({
      required String id,
      required String name,
      required String avatar,
      required String goal,
      required String lastMessage,
      required String lastTime,
      Value<bool> active,
      required int caloriesToday,
      required int sodiumMg,
      required int sugarG,
      required String lastRoutine,
      required String weekCompletionJson,
      Value<String> sodiumWeekJson,
      Value<int> sortOrder,
      Value<int> rowid,
    });
typedef $$TrainerClientsTableUpdateCompanionBuilder =
    TrainerClientsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> avatar,
      Value<String> goal,
      Value<String> lastMessage,
      Value<String> lastTime,
      Value<bool> active,
      Value<int> caloriesToday,
      Value<int> sodiumMg,
      Value<int> sugarG,
      Value<String> lastRoutine,
      Value<String> weekCompletionJson,
      Value<String> sodiumWeekJson,
      Value<int> sortOrder,
      Value<int> rowid,
    });

class $$TrainerClientsTableFilterComposer
    extends Composer<_$AppDatabase, $TrainerClientsTable> {
  $$TrainerClientsTableFilterComposer({
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

  ColumnFilters<String> get avatar => $composableBuilder(
    column: $table.avatar,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get goal => $composableBuilder(
    column: $table.goal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastMessage => $composableBuilder(
    column: $table.lastMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastTime => $composableBuilder(
    column: $table.lastTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get caloriesToday => $composableBuilder(
    column: $table.caloriesToday,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sodiumMg => $composableBuilder(
    column: $table.sodiumMg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sugarG => $composableBuilder(
    column: $table.sugarG,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastRoutine => $composableBuilder(
    column: $table.lastRoutine,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get weekCompletionJson => $composableBuilder(
    column: $table.weekCompletionJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sodiumWeekJson => $composableBuilder(
    column: $table.sodiumWeekJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TrainerClientsTableOrderingComposer
    extends Composer<_$AppDatabase, $TrainerClientsTable> {
  $$TrainerClientsTableOrderingComposer({
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

  ColumnOrderings<String> get avatar => $composableBuilder(
    column: $table.avatar,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get goal => $composableBuilder(
    column: $table.goal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastMessage => $composableBuilder(
    column: $table.lastMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastTime => $composableBuilder(
    column: $table.lastTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get caloriesToday => $composableBuilder(
    column: $table.caloriesToday,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sodiumMg => $composableBuilder(
    column: $table.sodiumMg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sugarG => $composableBuilder(
    column: $table.sugarG,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastRoutine => $composableBuilder(
    column: $table.lastRoutine,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get weekCompletionJson => $composableBuilder(
    column: $table.weekCompletionJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sodiumWeekJson => $composableBuilder(
    column: $table.sodiumWeekJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TrainerClientsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TrainerClientsTable> {
  $$TrainerClientsTableAnnotationComposer({
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

  GeneratedColumn<String> get avatar =>
      $composableBuilder(column: $table.avatar, builder: (column) => column);

  GeneratedColumn<String> get goal =>
      $composableBuilder(column: $table.goal, builder: (column) => column);

  GeneratedColumn<String> get lastMessage => $composableBuilder(
    column: $table.lastMessage,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastTime =>
      $composableBuilder(column: $table.lastTime, builder: (column) => column);

  GeneratedColumn<bool> get active =>
      $composableBuilder(column: $table.active, builder: (column) => column);

  GeneratedColumn<int> get caloriesToday => $composableBuilder(
    column: $table.caloriesToday,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sodiumMg =>
      $composableBuilder(column: $table.sodiumMg, builder: (column) => column);

  GeneratedColumn<int> get sugarG =>
      $composableBuilder(column: $table.sugarG, builder: (column) => column);

  GeneratedColumn<String> get lastRoutine => $composableBuilder(
    column: $table.lastRoutine,
    builder: (column) => column,
  );

  GeneratedColumn<String> get weekCompletionJson => $composableBuilder(
    column: $table.weekCompletionJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sodiumWeekJson => $composableBuilder(
    column: $table.sodiumWeekJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);
}

class $$TrainerClientsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TrainerClientsTable,
          TrainerClientRow,
          $$TrainerClientsTableFilterComposer,
          $$TrainerClientsTableOrderingComposer,
          $$TrainerClientsTableAnnotationComposer,
          $$TrainerClientsTableCreateCompanionBuilder,
          $$TrainerClientsTableUpdateCompanionBuilder,
          (
            TrainerClientRow,
            BaseReferences<
              _$AppDatabase,
              $TrainerClientsTable,
              TrainerClientRow
            >,
          ),
          TrainerClientRow,
          PrefetchHooks Function()
        > {
  $$TrainerClientsTableTableManager(
    _$AppDatabase db,
    $TrainerClientsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TrainerClientsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TrainerClientsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TrainerClientsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> avatar = const Value.absent(),
                Value<String> goal = const Value.absent(),
                Value<String> lastMessage = const Value.absent(),
                Value<String> lastTime = const Value.absent(),
                Value<bool> active = const Value.absent(),
                Value<int> caloriesToday = const Value.absent(),
                Value<int> sodiumMg = const Value.absent(),
                Value<int> sugarG = const Value.absent(),
                Value<String> lastRoutine = const Value.absent(),
                Value<String> weekCompletionJson = const Value.absent(),
                Value<String> sodiumWeekJson = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TrainerClientsCompanion(
                id: id,
                name: name,
                avatar: avatar,
                goal: goal,
                lastMessage: lastMessage,
                lastTime: lastTime,
                active: active,
                caloriesToday: caloriesToday,
                sodiumMg: sodiumMg,
                sugarG: sugarG,
                lastRoutine: lastRoutine,
                weekCompletionJson: weekCompletionJson,
                sodiumWeekJson: sodiumWeekJson,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String avatar,
                required String goal,
                required String lastMessage,
                required String lastTime,
                Value<bool> active = const Value.absent(),
                required int caloriesToday,
                required int sodiumMg,
                required int sugarG,
                required String lastRoutine,
                required String weekCompletionJson,
                Value<String> sodiumWeekJson = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TrainerClientsCompanion.insert(
                id: id,
                name: name,
                avatar: avatar,
                goal: goal,
                lastMessage: lastMessage,
                lastTime: lastTime,
                active: active,
                caloriesToday: caloriesToday,
                sodiumMg: sodiumMg,
                sugarG: sugarG,
                lastRoutine: lastRoutine,
                weekCompletionJson: weekCompletionJson,
                sodiumWeekJson: sodiumWeekJson,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TrainerClientsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TrainerClientsTable,
      TrainerClientRow,
      $$TrainerClientsTableFilterComposer,
      $$TrainerClientsTableOrderingComposer,
      $$TrainerClientsTableAnnotationComposer,
      $$TrainerClientsTableCreateCompanionBuilder,
      $$TrainerClientsTableUpdateCompanionBuilder,
      (
        TrainerClientRow,
        BaseReferences<_$AppDatabase, $TrainerClientsTable, TrainerClientRow>,
      ),
      TrainerClientRow,
      PrefetchHooks Function()
    >;
typedef $$ClientDietEntriesTableCreateCompanionBuilder =
    ClientDietEntriesCompanion Function({
      required String id,
      required String clientId,
      required String meal,
      required String items,
      required int calories,
      required int sodiumMg,
      Value<int> sortOrder,
      Value<int> rowid,
    });
typedef $$ClientDietEntriesTableUpdateCompanionBuilder =
    ClientDietEntriesCompanion Function({
      Value<String> id,
      Value<String> clientId,
      Value<String> meal,
      Value<String> items,
      Value<int> calories,
      Value<int> sodiumMg,
      Value<int> sortOrder,
      Value<int> rowid,
    });

class $$ClientDietEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $ClientDietEntriesTable> {
  $$ClientDietEntriesTableFilterComposer({
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

  ColumnFilters<String> get clientId => $composableBuilder(
    column: $table.clientId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get meal => $composableBuilder(
    column: $table.meal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get items => $composableBuilder(
    column: $table.items,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get calories => $composableBuilder(
    column: $table.calories,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sodiumMg => $composableBuilder(
    column: $table.sodiumMg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ClientDietEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $ClientDietEntriesTable> {
  $$ClientDietEntriesTableOrderingComposer({
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

  ColumnOrderings<String> get clientId => $composableBuilder(
    column: $table.clientId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get meal => $composableBuilder(
    column: $table.meal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get items => $composableBuilder(
    column: $table.items,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get calories => $composableBuilder(
    column: $table.calories,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sodiumMg => $composableBuilder(
    column: $table.sodiumMg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ClientDietEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ClientDietEntriesTable> {
  $$ClientDietEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get clientId =>
      $composableBuilder(column: $table.clientId, builder: (column) => column);

  GeneratedColumn<String> get meal =>
      $composableBuilder(column: $table.meal, builder: (column) => column);

  GeneratedColumn<String> get items =>
      $composableBuilder(column: $table.items, builder: (column) => column);

  GeneratedColumn<int> get calories =>
      $composableBuilder(column: $table.calories, builder: (column) => column);

  GeneratedColumn<int> get sodiumMg =>
      $composableBuilder(column: $table.sodiumMg, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);
}

class $$ClientDietEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ClientDietEntriesTable,
          ClientDietEntryRow,
          $$ClientDietEntriesTableFilterComposer,
          $$ClientDietEntriesTableOrderingComposer,
          $$ClientDietEntriesTableAnnotationComposer,
          $$ClientDietEntriesTableCreateCompanionBuilder,
          $$ClientDietEntriesTableUpdateCompanionBuilder,
          (
            ClientDietEntryRow,
            BaseReferences<
              _$AppDatabase,
              $ClientDietEntriesTable,
              ClientDietEntryRow
            >,
          ),
          ClientDietEntryRow,
          PrefetchHooks Function()
        > {
  $$ClientDietEntriesTableTableManager(
    _$AppDatabase db,
    $ClientDietEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ClientDietEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ClientDietEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ClientDietEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> clientId = const Value.absent(),
                Value<String> meal = const Value.absent(),
                Value<String> items = const Value.absent(),
                Value<int> calories = const Value.absent(),
                Value<int> sodiumMg = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ClientDietEntriesCompanion(
                id: id,
                clientId: clientId,
                meal: meal,
                items: items,
                calories: calories,
                sodiumMg: sodiumMg,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String clientId,
                required String meal,
                required String items,
                required int calories,
                required int sodiumMg,
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ClientDietEntriesCompanion.insert(
                id: id,
                clientId: clientId,
                meal: meal,
                items: items,
                calories: calories,
                sodiumMg: sodiumMg,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ClientDietEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ClientDietEntriesTable,
      ClientDietEntryRow,
      $$ClientDietEntriesTableFilterComposer,
      $$ClientDietEntriesTableOrderingComposer,
      $$ClientDietEntriesTableAnnotationComposer,
      $$ClientDietEntriesTableCreateCompanionBuilder,
      $$ClientDietEntriesTableUpdateCompanionBuilder,
      (
        ClientDietEntryRow,
        BaseReferences<
          _$AppDatabase,
          $ClientDietEntriesTable,
          ClientDietEntryRow
        >,
      ),
      ClientDietEntryRow,
      PrefetchHooks Function()
    >;
typedef $$ClientAiRoutinesTableCreateCompanionBuilder =
    ClientAiRoutinesCompanion Function({
      required String id,
      required String clientId,
      required String name,
      required int minutes,
      required String type,
      required String reason,
      Value<int> sortOrder,
      Value<int> rowid,
    });
typedef $$ClientAiRoutinesTableUpdateCompanionBuilder =
    ClientAiRoutinesCompanion Function({
      Value<String> id,
      Value<String> clientId,
      Value<String> name,
      Value<int> minutes,
      Value<String> type,
      Value<String> reason,
      Value<int> sortOrder,
      Value<int> rowid,
    });

class $$ClientAiRoutinesTableFilterComposer
    extends Composer<_$AppDatabase, $ClientAiRoutinesTable> {
  $$ClientAiRoutinesTableFilterComposer({
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

  ColumnFilters<String> get clientId => $composableBuilder(
    column: $table.clientId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get minutes => $composableBuilder(
    column: $table.minutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ClientAiRoutinesTableOrderingComposer
    extends Composer<_$AppDatabase, $ClientAiRoutinesTable> {
  $$ClientAiRoutinesTableOrderingComposer({
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

  ColumnOrderings<String> get clientId => $composableBuilder(
    column: $table.clientId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get minutes => $composableBuilder(
    column: $table.minutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ClientAiRoutinesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ClientAiRoutinesTable> {
  $$ClientAiRoutinesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get clientId =>
      $composableBuilder(column: $table.clientId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get minutes =>
      $composableBuilder(column: $table.minutes, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);
}

class $$ClientAiRoutinesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ClientAiRoutinesTable,
          ClientAiRoutineRow,
          $$ClientAiRoutinesTableFilterComposer,
          $$ClientAiRoutinesTableOrderingComposer,
          $$ClientAiRoutinesTableAnnotationComposer,
          $$ClientAiRoutinesTableCreateCompanionBuilder,
          $$ClientAiRoutinesTableUpdateCompanionBuilder,
          (
            ClientAiRoutineRow,
            BaseReferences<
              _$AppDatabase,
              $ClientAiRoutinesTable,
              ClientAiRoutineRow
            >,
          ),
          ClientAiRoutineRow,
          PrefetchHooks Function()
        > {
  $$ClientAiRoutinesTableTableManager(
    _$AppDatabase db,
    $ClientAiRoutinesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ClientAiRoutinesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ClientAiRoutinesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ClientAiRoutinesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> clientId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> minutes = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> reason = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ClientAiRoutinesCompanion(
                id: id,
                clientId: clientId,
                name: name,
                minutes: minutes,
                type: type,
                reason: reason,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String clientId,
                required String name,
                required int minutes,
                required String type,
                required String reason,
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ClientAiRoutinesCompanion.insert(
                id: id,
                clientId: clientId,
                name: name,
                minutes: minutes,
                type: type,
                reason: reason,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ClientAiRoutinesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ClientAiRoutinesTable,
      ClientAiRoutineRow,
      $$ClientAiRoutinesTableFilterComposer,
      $$ClientAiRoutinesTableOrderingComposer,
      $$ClientAiRoutinesTableAnnotationComposer,
      $$ClientAiRoutinesTableCreateCompanionBuilder,
      $$ClientAiRoutinesTableUpdateCompanionBuilder,
      (
        ClientAiRoutineRow,
        BaseReferences<
          _$AppDatabase,
          $ClientAiRoutinesTable,
          ClientAiRoutineRow
        >,
      ),
      ClientAiRoutineRow,
      PrefetchHooks Function()
    >;
typedef $$ClientRoutineHistoryTableCreateCompanionBuilder =
    ClientRoutineHistoryCompanion Function({
      required String id,
      required String clientId,
      required String dateLabel,
      required String label,
      required int completionRate,
      required String exercisesJson,
      Value<String> clientFeedback,
      Value<String> trainerNote,
      Value<int> sortOrder,
      Value<int> rowid,
    });
typedef $$ClientRoutineHistoryTableUpdateCompanionBuilder =
    ClientRoutineHistoryCompanion Function({
      Value<String> id,
      Value<String> clientId,
      Value<String> dateLabel,
      Value<String> label,
      Value<int> completionRate,
      Value<String> exercisesJson,
      Value<String> clientFeedback,
      Value<String> trainerNote,
      Value<int> sortOrder,
      Value<int> rowid,
    });

class $$ClientRoutineHistoryTableFilterComposer
    extends Composer<_$AppDatabase, $ClientRoutineHistoryTable> {
  $$ClientRoutineHistoryTableFilterComposer({
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

  ColumnFilters<String> get clientId => $composableBuilder(
    column: $table.clientId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dateLabel => $composableBuilder(
    column: $table.dateLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completionRate => $composableBuilder(
    column: $table.completionRate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get exercisesJson => $composableBuilder(
    column: $table.exercisesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get clientFeedback => $composableBuilder(
    column: $table.clientFeedback,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get trainerNote => $composableBuilder(
    column: $table.trainerNote,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ClientRoutineHistoryTableOrderingComposer
    extends Composer<_$AppDatabase, $ClientRoutineHistoryTable> {
  $$ClientRoutineHistoryTableOrderingComposer({
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

  ColumnOrderings<String> get clientId => $composableBuilder(
    column: $table.clientId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dateLabel => $composableBuilder(
    column: $table.dateLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completionRate => $composableBuilder(
    column: $table.completionRate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get exercisesJson => $composableBuilder(
    column: $table.exercisesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clientFeedback => $composableBuilder(
    column: $table.clientFeedback,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trainerNote => $composableBuilder(
    column: $table.trainerNote,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ClientRoutineHistoryTableAnnotationComposer
    extends Composer<_$AppDatabase, $ClientRoutineHistoryTable> {
  $$ClientRoutineHistoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get clientId =>
      $composableBuilder(column: $table.clientId, builder: (column) => column);

  GeneratedColumn<String> get dateLabel =>
      $composableBuilder(column: $table.dateLabel, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<int> get completionRate => $composableBuilder(
    column: $table.completionRate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get exercisesJson => $composableBuilder(
    column: $table.exercisesJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get clientFeedback => $composableBuilder(
    column: $table.clientFeedback,
    builder: (column) => column,
  );

  GeneratedColumn<String> get trainerNote => $composableBuilder(
    column: $table.trainerNote,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);
}

class $$ClientRoutineHistoryTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ClientRoutineHistoryTable,
          ClientRoutineHistoryRow,
          $$ClientRoutineHistoryTableFilterComposer,
          $$ClientRoutineHistoryTableOrderingComposer,
          $$ClientRoutineHistoryTableAnnotationComposer,
          $$ClientRoutineHistoryTableCreateCompanionBuilder,
          $$ClientRoutineHistoryTableUpdateCompanionBuilder,
          (
            ClientRoutineHistoryRow,
            BaseReferences<
              _$AppDatabase,
              $ClientRoutineHistoryTable,
              ClientRoutineHistoryRow
            >,
          ),
          ClientRoutineHistoryRow,
          PrefetchHooks Function()
        > {
  $$ClientRoutineHistoryTableTableManager(
    _$AppDatabase db,
    $ClientRoutineHistoryTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ClientRoutineHistoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ClientRoutineHistoryTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ClientRoutineHistoryTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> clientId = const Value.absent(),
                Value<String> dateLabel = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<int> completionRate = const Value.absent(),
                Value<String> exercisesJson = const Value.absent(),
                Value<String> clientFeedback = const Value.absent(),
                Value<String> trainerNote = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ClientRoutineHistoryCompanion(
                id: id,
                clientId: clientId,
                dateLabel: dateLabel,
                label: label,
                completionRate: completionRate,
                exercisesJson: exercisesJson,
                clientFeedback: clientFeedback,
                trainerNote: trainerNote,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String clientId,
                required String dateLabel,
                required String label,
                required int completionRate,
                required String exercisesJson,
                Value<String> clientFeedback = const Value.absent(),
                Value<String> trainerNote = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ClientRoutineHistoryCompanion.insert(
                id: id,
                clientId: clientId,
                dateLabel: dateLabel,
                label: label,
                completionRate: completionRate,
                exercisesJson: exercisesJson,
                clientFeedback: clientFeedback,
                trainerNote: trainerNote,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ClientRoutineHistoryTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ClientRoutineHistoryTable,
      ClientRoutineHistoryRow,
      $$ClientRoutineHistoryTableFilterComposer,
      $$ClientRoutineHistoryTableOrderingComposer,
      $$ClientRoutineHistoryTableAnnotationComposer,
      $$ClientRoutineHistoryTableCreateCompanionBuilder,
      $$ClientRoutineHistoryTableUpdateCompanionBuilder,
      (
        ClientRoutineHistoryRow,
        BaseReferences<
          _$AppDatabase,
          $ClientRoutineHistoryTable,
          ClientRoutineHistoryRow
        >,
      ),
      ClientRoutineHistoryRow,
      PrefetchHooks Function()
    >;
typedef $$ClientChatMessagesTableCreateCompanionBuilder =
    ClientChatMessagesCompanion Function({
      required String id,
      required String clientId,
      required String sender,
      required String body,
      required String timeLabel,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$ClientChatMessagesTableUpdateCompanionBuilder =
    ClientChatMessagesCompanion Function({
      Value<String> id,
      Value<String> clientId,
      Value<String> sender,
      Value<String> body,
      Value<String> timeLabel,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$ClientChatMessagesTableFilterComposer
    extends Composer<_$AppDatabase, $ClientChatMessagesTable> {
  $$ClientChatMessagesTableFilterComposer({
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

  ColumnFilters<String> get clientId => $composableBuilder(
    column: $table.clientId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sender => $composableBuilder(
    column: $table.sender,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get timeLabel => $composableBuilder(
    column: $table.timeLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ClientChatMessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $ClientChatMessagesTable> {
  $$ClientChatMessagesTableOrderingComposer({
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

  ColumnOrderings<String> get clientId => $composableBuilder(
    column: $table.clientId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sender => $composableBuilder(
    column: $table.sender,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get timeLabel => $composableBuilder(
    column: $table.timeLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ClientChatMessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ClientChatMessagesTable> {
  $$ClientChatMessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get clientId =>
      $composableBuilder(column: $table.clientId, builder: (column) => column);

  GeneratedColumn<String> get sender =>
      $composableBuilder(column: $table.sender, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get timeLabel =>
      $composableBuilder(column: $table.timeLabel, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ClientChatMessagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ClientChatMessagesTable,
          ClientChatMessageRow,
          $$ClientChatMessagesTableFilterComposer,
          $$ClientChatMessagesTableOrderingComposer,
          $$ClientChatMessagesTableAnnotationComposer,
          $$ClientChatMessagesTableCreateCompanionBuilder,
          $$ClientChatMessagesTableUpdateCompanionBuilder,
          (
            ClientChatMessageRow,
            BaseReferences<
              _$AppDatabase,
              $ClientChatMessagesTable,
              ClientChatMessageRow
            >,
          ),
          ClientChatMessageRow,
          PrefetchHooks Function()
        > {
  $$ClientChatMessagesTableTableManager(
    _$AppDatabase db,
    $ClientChatMessagesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ClientChatMessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ClientChatMessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ClientChatMessagesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> clientId = const Value.absent(),
                Value<String> sender = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<String> timeLabel = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ClientChatMessagesCompanion(
                id: id,
                clientId: clientId,
                sender: sender,
                body: body,
                timeLabel: timeLabel,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String clientId,
                required String sender,
                required String body,
                required String timeLabel,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => ClientChatMessagesCompanion.insert(
                id: id,
                clientId: clientId,
                sender: sender,
                body: body,
                timeLabel: timeLabel,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ClientChatMessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ClientChatMessagesTable,
      ClientChatMessageRow,
      $$ClientChatMessagesTableFilterComposer,
      $$ClientChatMessagesTableOrderingComposer,
      $$ClientChatMessagesTableAnnotationComposer,
      $$ClientChatMessagesTableCreateCompanionBuilder,
      $$ClientChatMessagesTableUpdateCompanionBuilder,
      (
        ClientChatMessageRow,
        BaseReferences<
          _$AppDatabase,
          $ClientChatMessagesTable,
          ClientChatMessageRow
        >,
      ),
      ClientChatMessageRow,
      PrefetchHooks Function()
    >;
typedef $$TrainerScheduleEntriesTableCreateCompanionBuilder =
    TrainerScheduleEntriesCompanion Function({
      required String id,
      required String date,
      required String time,
      Value<String> clientName,
      Value<String> type,
      Value<int> durationMinutes,
      required String status,
      Value<String> note,
      Value<String> programJson,
      Value<int> sortOrder,
      Value<int> rowid,
    });
typedef $$TrainerScheduleEntriesTableUpdateCompanionBuilder =
    TrainerScheduleEntriesCompanion Function({
      Value<String> id,
      Value<String> date,
      Value<String> time,
      Value<String> clientName,
      Value<String> type,
      Value<int> durationMinutes,
      Value<String> status,
      Value<String> note,
      Value<String> programJson,
      Value<int> sortOrder,
      Value<int> rowid,
    });

class $$TrainerScheduleEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $TrainerScheduleEntriesTable> {
  $$TrainerScheduleEntriesTableFilterComposer({
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

  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get time => $composableBuilder(
    column: $table.time,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get clientName => $composableBuilder(
    column: $table.clientName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMinutes => $composableBuilder(
    column: $table.durationMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get programJson => $composableBuilder(
    column: $table.programJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TrainerScheduleEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $TrainerScheduleEntriesTable> {
  $$TrainerScheduleEntriesTableOrderingComposer({
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

  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get time => $composableBuilder(
    column: $table.time,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clientName => $composableBuilder(
    column: $table.clientName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMinutes => $composableBuilder(
    column: $table.durationMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get programJson => $composableBuilder(
    column: $table.programJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TrainerScheduleEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $TrainerScheduleEntriesTable> {
  $$TrainerScheduleEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get time =>
      $composableBuilder(column: $table.time, builder: (column) => column);

  GeneratedColumn<String> get clientName => $composableBuilder(
    column: $table.clientName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get durationMinutes => $composableBuilder(
    column: $table.durationMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get programJson => $composableBuilder(
    column: $table.programJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);
}

class $$TrainerScheduleEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TrainerScheduleEntriesTable,
          TrainerScheduleRow,
          $$TrainerScheduleEntriesTableFilterComposer,
          $$TrainerScheduleEntriesTableOrderingComposer,
          $$TrainerScheduleEntriesTableAnnotationComposer,
          $$TrainerScheduleEntriesTableCreateCompanionBuilder,
          $$TrainerScheduleEntriesTableUpdateCompanionBuilder,
          (
            TrainerScheduleRow,
            BaseReferences<
              _$AppDatabase,
              $TrainerScheduleEntriesTable,
              TrainerScheduleRow
            >,
          ),
          TrainerScheduleRow,
          PrefetchHooks Function()
        > {
  $$TrainerScheduleEntriesTableTableManager(
    _$AppDatabase db,
    $TrainerScheduleEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TrainerScheduleEntriesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$TrainerScheduleEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$TrainerScheduleEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> date = const Value.absent(),
                Value<String> time = const Value.absent(),
                Value<String> clientName = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<int> durationMinutes = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<String> programJson = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TrainerScheduleEntriesCompanion(
                id: id,
                date: date,
                time: time,
                clientName: clientName,
                type: type,
                durationMinutes: durationMinutes,
                status: status,
                note: note,
                programJson: programJson,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String date,
                required String time,
                Value<String> clientName = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<int> durationMinutes = const Value.absent(),
                required String status,
                Value<String> note = const Value.absent(),
                Value<String> programJson = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TrainerScheduleEntriesCompanion.insert(
                id: id,
                date: date,
                time: time,
                clientName: clientName,
                type: type,
                durationMinutes: durationMinutes,
                status: status,
                note: note,
                programJson: programJson,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TrainerScheduleEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TrainerScheduleEntriesTable,
      TrainerScheduleRow,
      $$TrainerScheduleEntriesTableFilterComposer,
      $$TrainerScheduleEntriesTableOrderingComposer,
      $$TrainerScheduleEntriesTableAnnotationComposer,
      $$TrainerScheduleEntriesTableCreateCompanionBuilder,
      $$TrainerScheduleEntriesTableUpdateCompanionBuilder,
      (
        TrainerScheduleRow,
        BaseReferences<
          _$AppDatabase,
          $TrainerScheduleEntriesTable,
          TrainerScheduleRow
        >,
      ),
      TrainerScheduleRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$AppKeyValuesTableTableManager get appKeyValues =>
      $$AppKeyValuesTableTableManager(_db, _db.appKeyValues);
  $$TrainerClientsTableTableManager get trainerClients =>
      $$TrainerClientsTableTableManager(_db, _db.trainerClients);
  $$ClientDietEntriesTableTableManager get clientDietEntries =>
      $$ClientDietEntriesTableTableManager(_db, _db.clientDietEntries);
  $$ClientAiRoutinesTableTableManager get clientAiRoutines =>
      $$ClientAiRoutinesTableTableManager(_db, _db.clientAiRoutines);
  $$ClientRoutineHistoryTableTableManager get clientRoutineHistory =>
      $$ClientRoutineHistoryTableTableManager(_db, _db.clientRoutineHistory);
  $$ClientChatMessagesTableTableManager get clientChatMessages =>
      $$ClientChatMessagesTableTableManager(_db, _db.clientChatMessages);
  $$TrainerScheduleEntriesTableTableManager get trainerScheduleEntries =>
      $$TrainerScheduleEntriesTableTableManager(
        _db,
        _db.trainerScheduleEntries,
      );
}
