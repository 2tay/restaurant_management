// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $StoresTable extends Stores with TableInfo<$StoresTable, StoreRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StoresTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 64,
    ),
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
  static const VerificationMeta _addressLineMeta = const VerificationMeta(
    'addressLine',
  );
  @override
  late final GeneratedColumn<String> addressLine = GeneratedColumn<String>(
    'address_line',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _postalCodeMeta = const VerificationMeta(
    'postalCode',
  );
  @override
  late final GeneratedColumn<String> postalCode = GeneratedColumn<String>(
    'postal_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cityMeta = const VerificationMeta('city');
  @override
  late final GeneratedColumn<String> city = GeneratedColumn<String>(
    'city',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
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
  static const VerificationMeta _vatNumberMeta = const VerificationMeta(
    'vatNumber',
  );
  @override
  late final GeneratedColumn<String> vatNumber = GeneratedColumn<String>(
    'vat_number',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imageAssetMeta = const VerificationMeta(
    'imageAsset',
  );
  @override
  late final GeneratedColumn<String> imageAsset = GeneratedColumn<String>(
    'image_asset',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stalePartialOrderDaysMeta =
      const VerificationMeta('stalePartialOrderDays');
  @override
  late final GeneratedColumn<int> stalePartialOrderDays = GeneratedColumn<int>(
    'stale_partial_order_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(7),
  );
  static const VerificationMeta _openMinutesMeta = const VerificationMeta(
    'openMinutes',
  );
  @override
  late final GeneratedColumn<int> openMinutes = GeneratedColumn<int>(
    'open_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(8 * 60),
  );
  static const VerificationMeta _closeMinutesMeta = const VerificationMeta(
    'closeMinutes',
  );
  @override
  late final GeneratedColumn<int> closeMinutes = GeneratedColumn<int>(
    'close_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(17 * 60),
  );
  static const VerificationMeta _maxBreakMinutesMeta = const VerificationMeta(
    'maxBreakMinutes',
  );
  @override
  late final GeneratedColumn<int> maxBreakMinutes = GeneratedColumn<int>(
    'max_break_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(30),
  );
  static const VerificationMeta _overtimeMultiplierMeta =
      const VerificationMeta('overtimeMultiplier');
  @override
  late final GeneratedColumn<double> overtimeMultiplier =
      GeneratedColumn<double>(
        'overtime_multiplier',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
        defaultValue: const Constant(1.25),
      );
  static const VerificationMeta _workingDaysPerMonthMeta =
      const VerificationMeta('workingDaysPerMonth');
  @override
  late final GeneratedColumn<int> workingDaysPerMonth = GeneratedColumn<int>(
    'working_days_per_month',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(26),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    addressLine,
    postalCode,
    city,
    phone,
    createdAt,
    vatNumber,
    imageAsset,
    stalePartialOrderDays,
    openMinutes,
    closeMinutes,
    maxBreakMinutes,
    overtimeMultiplier,
    workingDaysPerMonth,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stores';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoreRow> instance, {
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
    if (data.containsKey('address_line')) {
      context.handle(
        _addressLineMeta,
        addressLine.isAcceptableOrUnknown(
          data['address_line']!,
          _addressLineMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_addressLineMeta);
    }
    if (data.containsKey('postal_code')) {
      context.handle(
        _postalCodeMeta,
        postalCode.isAcceptableOrUnknown(data['postal_code']!, _postalCodeMeta),
      );
    } else if (isInserting) {
      context.missing(_postalCodeMeta);
    }
    if (data.containsKey('city')) {
      context.handle(
        _cityMeta,
        city.isAcceptableOrUnknown(data['city']!, _cityMeta),
      );
    } else if (isInserting) {
      context.missing(_cityMeta);
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    } else if (isInserting) {
      context.missing(_phoneMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('vat_number')) {
      context.handle(
        _vatNumberMeta,
        vatNumber.isAcceptableOrUnknown(data['vat_number']!, _vatNumberMeta),
      );
    }
    if (data.containsKey('image_asset')) {
      context.handle(
        _imageAssetMeta,
        imageAsset.isAcceptableOrUnknown(data['image_asset']!, _imageAssetMeta),
      );
    }
    if (data.containsKey('stale_partial_order_days')) {
      context.handle(
        _stalePartialOrderDaysMeta,
        stalePartialOrderDays.isAcceptableOrUnknown(
          data['stale_partial_order_days']!,
          _stalePartialOrderDaysMeta,
        ),
      );
    }
    if (data.containsKey('open_minutes')) {
      context.handle(
        _openMinutesMeta,
        openMinutes.isAcceptableOrUnknown(
          data['open_minutes']!,
          _openMinutesMeta,
        ),
      );
    }
    if (data.containsKey('close_minutes')) {
      context.handle(
        _closeMinutesMeta,
        closeMinutes.isAcceptableOrUnknown(
          data['close_minutes']!,
          _closeMinutesMeta,
        ),
      );
    }
    if (data.containsKey('max_break_minutes')) {
      context.handle(
        _maxBreakMinutesMeta,
        maxBreakMinutes.isAcceptableOrUnknown(
          data['max_break_minutes']!,
          _maxBreakMinutesMeta,
        ),
      );
    }
    if (data.containsKey('overtime_multiplier')) {
      context.handle(
        _overtimeMultiplierMeta,
        overtimeMultiplier.isAcceptableOrUnknown(
          data['overtime_multiplier']!,
          _overtimeMultiplierMeta,
        ),
      );
    }
    if (data.containsKey('working_days_per_month')) {
      context.handle(
        _workingDaysPerMonthMeta,
        workingDaysPerMonth.isAcceptableOrUnknown(
          data['working_days_per_month']!,
          _workingDaysPerMonthMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StoreRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoreRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      addressLine: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address_line'],
      )!,
      postalCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}postal_code'],
      )!,
      city: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}city'],
      )!,
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      vatNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vat_number'],
      ),
      imageAsset: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_asset'],
      ),
      stalePartialOrderDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stale_partial_order_days'],
      )!,
      openMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}open_minutes'],
      )!,
      closeMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}close_minutes'],
      )!,
      maxBreakMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}max_break_minutes'],
      )!,
      overtimeMultiplier: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}overtime_multiplier'],
      )!,
      workingDaysPerMonth: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}working_days_per_month'],
      )!,
    );
  }

  @override
  $StoresTable createAlias(String alias) {
    return $StoresTable(attachedDatabase, alias);
  }
}

class StoreRow extends DataClass implements Insertable<StoreRow> {
  final String id;
  final String name;
  final String addressLine;
  final String postalCode;
  final String city;
  final String phone;
  final DateTime createdAt;

  /// Belgian business documents need it in the header. Absent renders nothing
  /// rather than an empty label, so null and '' must not both be reachable —
  /// the store form stores empty input as null.
  final String? vatNumber;
  final String? imageAsset;

  /// How many days a `partial` commande may sit before the dashboard flags it.
  ///
  /// This is where `MockSettings.stalePartialOrderDays` lands. It was a mutable
  /// global in Phase 1 with a comment promising it would become a column, and
  /// this is that column. Per store, because two establishments can reasonably
  /// disagree about how long is too long.
  final int stalePartialOrderDays;

  /// Opening / closing time, minutes since midnight — the baseline lateness and
  /// overtime are measured against for an employee with no personal schedule.
  /// `AttendanceRules.defaultOpenMinutes` / `defaultCloseMinutes` = 08:00, 17:00.
  final int openMinutes;
  final int closeMinutes;

  /// A single break segment longer than this is flagged "pause dépassée".
  /// `AttendanceRules.defaultMaxBreakMinutes`.
  final int maxBreakMinutes;

  /// Overtime hours are paid at the normal rate times this coefficient.
  /// `PayrollRules.defaultOvertimeMultiplier`.
  final double overtimeMultiplier;

  /// Divisor that turns a fixed-salary employee's monthly pay into a daily
  /// rate. `PayrollRules.defaultWorkingDaysPerMonth`.
  final int workingDaysPerMonth;
  const StoreRow({
    required this.id,
    required this.name,
    required this.addressLine,
    required this.postalCode,
    required this.city,
    required this.phone,
    required this.createdAt,
    this.vatNumber,
    this.imageAsset,
    required this.stalePartialOrderDays,
    required this.openMinutes,
    required this.closeMinutes,
    required this.maxBreakMinutes,
    required this.overtimeMultiplier,
    required this.workingDaysPerMonth,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['address_line'] = Variable<String>(addressLine);
    map['postal_code'] = Variable<String>(postalCode);
    map['city'] = Variable<String>(city);
    map['phone'] = Variable<String>(phone);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || vatNumber != null) {
      map['vat_number'] = Variable<String>(vatNumber);
    }
    if (!nullToAbsent || imageAsset != null) {
      map['image_asset'] = Variable<String>(imageAsset);
    }
    map['stale_partial_order_days'] = Variable<int>(stalePartialOrderDays);
    map['open_minutes'] = Variable<int>(openMinutes);
    map['close_minutes'] = Variable<int>(closeMinutes);
    map['max_break_minutes'] = Variable<int>(maxBreakMinutes);
    map['overtime_multiplier'] = Variable<double>(overtimeMultiplier);
    map['working_days_per_month'] = Variable<int>(workingDaysPerMonth);
    return map;
  }

  StoresCompanion toCompanion(bool nullToAbsent) {
    return StoresCompanion(
      id: Value(id),
      name: Value(name),
      addressLine: Value(addressLine),
      postalCode: Value(postalCode),
      city: Value(city),
      phone: Value(phone),
      createdAt: Value(createdAt),
      vatNumber: vatNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(vatNumber),
      imageAsset: imageAsset == null && nullToAbsent
          ? const Value.absent()
          : Value(imageAsset),
      stalePartialOrderDays: Value(stalePartialOrderDays),
      openMinutes: Value(openMinutes),
      closeMinutes: Value(closeMinutes),
      maxBreakMinutes: Value(maxBreakMinutes),
      overtimeMultiplier: Value(overtimeMultiplier),
      workingDaysPerMonth: Value(workingDaysPerMonth),
    );
  }

  factory StoreRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoreRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      addressLine: serializer.fromJson<String>(json['addressLine']),
      postalCode: serializer.fromJson<String>(json['postalCode']),
      city: serializer.fromJson<String>(json['city']),
      phone: serializer.fromJson<String>(json['phone']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      vatNumber: serializer.fromJson<String?>(json['vatNumber']),
      imageAsset: serializer.fromJson<String?>(json['imageAsset']),
      stalePartialOrderDays: serializer.fromJson<int>(
        json['stalePartialOrderDays'],
      ),
      openMinutes: serializer.fromJson<int>(json['openMinutes']),
      closeMinutes: serializer.fromJson<int>(json['closeMinutes']),
      maxBreakMinutes: serializer.fromJson<int>(json['maxBreakMinutes']),
      overtimeMultiplier: serializer.fromJson<double>(
        json['overtimeMultiplier'],
      ),
      workingDaysPerMonth: serializer.fromJson<int>(
        json['workingDaysPerMonth'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'addressLine': serializer.toJson<String>(addressLine),
      'postalCode': serializer.toJson<String>(postalCode),
      'city': serializer.toJson<String>(city),
      'phone': serializer.toJson<String>(phone),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'vatNumber': serializer.toJson<String?>(vatNumber),
      'imageAsset': serializer.toJson<String?>(imageAsset),
      'stalePartialOrderDays': serializer.toJson<int>(stalePartialOrderDays),
      'openMinutes': serializer.toJson<int>(openMinutes),
      'closeMinutes': serializer.toJson<int>(closeMinutes),
      'maxBreakMinutes': serializer.toJson<int>(maxBreakMinutes),
      'overtimeMultiplier': serializer.toJson<double>(overtimeMultiplier),
      'workingDaysPerMonth': serializer.toJson<int>(workingDaysPerMonth),
    };
  }

  StoreRow copyWith({
    String? id,
    String? name,
    String? addressLine,
    String? postalCode,
    String? city,
    String? phone,
    DateTime? createdAt,
    Value<String?> vatNumber = const Value.absent(),
    Value<String?> imageAsset = const Value.absent(),
    int? stalePartialOrderDays,
    int? openMinutes,
    int? closeMinutes,
    int? maxBreakMinutes,
    double? overtimeMultiplier,
    int? workingDaysPerMonth,
  }) => StoreRow(
    id: id ?? this.id,
    name: name ?? this.name,
    addressLine: addressLine ?? this.addressLine,
    postalCode: postalCode ?? this.postalCode,
    city: city ?? this.city,
    phone: phone ?? this.phone,
    createdAt: createdAt ?? this.createdAt,
    vatNumber: vatNumber.present ? vatNumber.value : this.vatNumber,
    imageAsset: imageAsset.present ? imageAsset.value : this.imageAsset,
    stalePartialOrderDays: stalePartialOrderDays ?? this.stalePartialOrderDays,
    openMinutes: openMinutes ?? this.openMinutes,
    closeMinutes: closeMinutes ?? this.closeMinutes,
    maxBreakMinutes: maxBreakMinutes ?? this.maxBreakMinutes,
    overtimeMultiplier: overtimeMultiplier ?? this.overtimeMultiplier,
    workingDaysPerMonth: workingDaysPerMonth ?? this.workingDaysPerMonth,
  );
  StoreRow copyWithCompanion(StoresCompanion data) {
    return StoreRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      addressLine: data.addressLine.present
          ? data.addressLine.value
          : this.addressLine,
      postalCode: data.postalCode.present
          ? data.postalCode.value
          : this.postalCode,
      city: data.city.present ? data.city.value : this.city,
      phone: data.phone.present ? data.phone.value : this.phone,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      vatNumber: data.vatNumber.present ? data.vatNumber.value : this.vatNumber,
      imageAsset: data.imageAsset.present
          ? data.imageAsset.value
          : this.imageAsset,
      stalePartialOrderDays: data.stalePartialOrderDays.present
          ? data.stalePartialOrderDays.value
          : this.stalePartialOrderDays,
      openMinutes: data.openMinutes.present
          ? data.openMinutes.value
          : this.openMinutes,
      closeMinutes: data.closeMinutes.present
          ? data.closeMinutes.value
          : this.closeMinutes,
      maxBreakMinutes: data.maxBreakMinutes.present
          ? data.maxBreakMinutes.value
          : this.maxBreakMinutes,
      overtimeMultiplier: data.overtimeMultiplier.present
          ? data.overtimeMultiplier.value
          : this.overtimeMultiplier,
      workingDaysPerMonth: data.workingDaysPerMonth.present
          ? data.workingDaysPerMonth.value
          : this.workingDaysPerMonth,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoreRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('addressLine: $addressLine, ')
          ..write('postalCode: $postalCode, ')
          ..write('city: $city, ')
          ..write('phone: $phone, ')
          ..write('createdAt: $createdAt, ')
          ..write('vatNumber: $vatNumber, ')
          ..write('imageAsset: $imageAsset, ')
          ..write('stalePartialOrderDays: $stalePartialOrderDays, ')
          ..write('openMinutes: $openMinutes, ')
          ..write('closeMinutes: $closeMinutes, ')
          ..write('maxBreakMinutes: $maxBreakMinutes, ')
          ..write('overtimeMultiplier: $overtimeMultiplier, ')
          ..write('workingDaysPerMonth: $workingDaysPerMonth')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    addressLine,
    postalCode,
    city,
    phone,
    createdAt,
    vatNumber,
    imageAsset,
    stalePartialOrderDays,
    openMinutes,
    closeMinutes,
    maxBreakMinutes,
    overtimeMultiplier,
    workingDaysPerMonth,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoreRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.addressLine == this.addressLine &&
          other.postalCode == this.postalCode &&
          other.city == this.city &&
          other.phone == this.phone &&
          other.createdAt == this.createdAt &&
          other.vatNumber == this.vatNumber &&
          other.imageAsset == this.imageAsset &&
          other.stalePartialOrderDays == this.stalePartialOrderDays &&
          other.openMinutes == this.openMinutes &&
          other.closeMinutes == this.closeMinutes &&
          other.maxBreakMinutes == this.maxBreakMinutes &&
          other.overtimeMultiplier == this.overtimeMultiplier &&
          other.workingDaysPerMonth == this.workingDaysPerMonth);
}

class StoresCompanion extends UpdateCompanion<StoreRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> addressLine;
  final Value<String> postalCode;
  final Value<String> city;
  final Value<String> phone;
  final Value<DateTime> createdAt;
  final Value<String?> vatNumber;
  final Value<String?> imageAsset;
  final Value<int> stalePartialOrderDays;
  final Value<int> openMinutes;
  final Value<int> closeMinutes;
  final Value<int> maxBreakMinutes;
  final Value<double> overtimeMultiplier;
  final Value<int> workingDaysPerMonth;
  final Value<int> rowid;
  const StoresCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.addressLine = const Value.absent(),
    this.postalCode = const Value.absent(),
    this.city = const Value.absent(),
    this.phone = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.vatNumber = const Value.absent(),
    this.imageAsset = const Value.absent(),
    this.stalePartialOrderDays = const Value.absent(),
    this.openMinutes = const Value.absent(),
    this.closeMinutes = const Value.absent(),
    this.maxBreakMinutes = const Value.absent(),
    this.overtimeMultiplier = const Value.absent(),
    this.workingDaysPerMonth = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StoresCompanion.insert({
    required String id,
    required String name,
    required String addressLine,
    required String postalCode,
    required String city,
    required String phone,
    required DateTime createdAt,
    this.vatNumber = const Value.absent(),
    this.imageAsset = const Value.absent(),
    this.stalePartialOrderDays = const Value.absent(),
    this.openMinutes = const Value.absent(),
    this.closeMinutes = const Value.absent(),
    this.maxBreakMinutes = const Value.absent(),
    this.overtimeMultiplier = const Value.absent(),
    this.workingDaysPerMonth = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       addressLine = Value(addressLine),
       postalCode = Value(postalCode),
       city = Value(city),
       phone = Value(phone),
       createdAt = Value(createdAt);
  static Insertable<StoreRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? addressLine,
    Expression<String>? postalCode,
    Expression<String>? city,
    Expression<String>? phone,
    Expression<DateTime>? createdAt,
    Expression<String>? vatNumber,
    Expression<String>? imageAsset,
    Expression<int>? stalePartialOrderDays,
    Expression<int>? openMinutes,
    Expression<int>? closeMinutes,
    Expression<int>? maxBreakMinutes,
    Expression<double>? overtimeMultiplier,
    Expression<int>? workingDaysPerMonth,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (addressLine != null) 'address_line': addressLine,
      if (postalCode != null) 'postal_code': postalCode,
      if (city != null) 'city': city,
      if (phone != null) 'phone': phone,
      if (createdAt != null) 'created_at': createdAt,
      if (vatNumber != null) 'vat_number': vatNumber,
      if (imageAsset != null) 'image_asset': imageAsset,
      if (stalePartialOrderDays != null)
        'stale_partial_order_days': stalePartialOrderDays,
      if (openMinutes != null) 'open_minutes': openMinutes,
      if (closeMinutes != null) 'close_minutes': closeMinutes,
      if (maxBreakMinutes != null) 'max_break_minutes': maxBreakMinutes,
      if (overtimeMultiplier != null) 'overtime_multiplier': overtimeMultiplier,
      if (workingDaysPerMonth != null)
        'working_days_per_month': workingDaysPerMonth,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StoresCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? addressLine,
    Value<String>? postalCode,
    Value<String>? city,
    Value<String>? phone,
    Value<DateTime>? createdAt,
    Value<String?>? vatNumber,
    Value<String?>? imageAsset,
    Value<int>? stalePartialOrderDays,
    Value<int>? openMinutes,
    Value<int>? closeMinutes,
    Value<int>? maxBreakMinutes,
    Value<double>? overtimeMultiplier,
    Value<int>? workingDaysPerMonth,
    Value<int>? rowid,
  }) {
    return StoresCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      addressLine: addressLine ?? this.addressLine,
      postalCode: postalCode ?? this.postalCode,
      city: city ?? this.city,
      phone: phone ?? this.phone,
      createdAt: createdAt ?? this.createdAt,
      vatNumber: vatNumber ?? this.vatNumber,
      imageAsset: imageAsset ?? this.imageAsset,
      stalePartialOrderDays:
          stalePartialOrderDays ?? this.stalePartialOrderDays,
      openMinutes: openMinutes ?? this.openMinutes,
      closeMinutes: closeMinutes ?? this.closeMinutes,
      maxBreakMinutes: maxBreakMinutes ?? this.maxBreakMinutes,
      overtimeMultiplier: overtimeMultiplier ?? this.overtimeMultiplier,
      workingDaysPerMonth: workingDaysPerMonth ?? this.workingDaysPerMonth,
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
    if (addressLine.present) {
      map['address_line'] = Variable<String>(addressLine.value);
    }
    if (postalCode.present) {
      map['postal_code'] = Variable<String>(postalCode.value);
    }
    if (city.present) {
      map['city'] = Variable<String>(city.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (vatNumber.present) {
      map['vat_number'] = Variable<String>(vatNumber.value);
    }
    if (imageAsset.present) {
      map['image_asset'] = Variable<String>(imageAsset.value);
    }
    if (stalePartialOrderDays.present) {
      map['stale_partial_order_days'] = Variable<int>(
        stalePartialOrderDays.value,
      );
    }
    if (openMinutes.present) {
      map['open_minutes'] = Variable<int>(openMinutes.value);
    }
    if (closeMinutes.present) {
      map['close_minutes'] = Variable<int>(closeMinutes.value);
    }
    if (maxBreakMinutes.present) {
      map['max_break_minutes'] = Variable<int>(maxBreakMinutes.value);
    }
    if (overtimeMultiplier.present) {
      map['overtime_multiplier'] = Variable<double>(overtimeMultiplier.value);
    }
    if (workingDaysPerMonth.present) {
      map['working_days_per_month'] = Variable<int>(workingDaysPerMonth.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StoresCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('addressLine: $addressLine, ')
          ..write('postalCode: $postalCode, ')
          ..write('city: $city, ')
          ..write('phone: $phone, ')
          ..write('createdAt: $createdAt, ')
          ..write('vatNumber: $vatNumber, ')
          ..write('imageAsset: $imageAsset, ')
          ..write('stalePartialOrderDays: $stalePartialOrderDays, ')
          ..write('openMinutes: $openMinutes, ')
          ..write('closeMinutes: $closeMinutes, ')
          ..write('maxBreakMinutes: $maxBreakMinutes, ')
          ..write('overtimeMultiplier: $overtimeMultiplier, ')
          ..write('workingDaysPerMonth: $workingDaysPerMonth, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MetaTable extends Meta with TableInfo<$MetaTable, MetaRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MetaTable(this.attachedDatabase, [this._alias]);
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
  static const String $name = 'meta';
  @override
  VerificationContext validateIntegrity(
    Insertable<MetaRow> instance, {
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
  MetaRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MetaRow(
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
  $MetaTable createAlias(String alias) {
    return $MetaTable(attachedDatabase, alias);
  }
}

class MetaRow extends DataClass implements Insertable<MetaRow> {
  final String key;
  final String value;
  const MetaRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  MetaCompanion toCompanion(bool nullToAbsent) {
    return MetaCompanion(key: Value(key), value: Value(value));
  }

  factory MetaRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MetaRow(
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

  MetaRow copyWith({String? key, String? value}) =>
      MetaRow(key: key ?? this.key, value: value ?? this.value);
  MetaRow copyWithCompanion(MetaCompanion data) {
    return MetaRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MetaRow(')
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
      (other is MetaRow && other.key == this.key && other.value == this.value);
}

class MetaCompanion extends UpdateCompanion<MetaRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const MetaCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MetaCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<MetaRow> custom({
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

  MetaCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return MetaCompanion(
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
    return (StringBuffer('MetaCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CategoriesTable extends Categories
    with TableInfo<$CategoriesTable, CategoryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 64,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _storeIdMeta = const VerificationMeta(
    'storeId',
  );
  @override
  late final GeneratedColumn<String> storeId = GeneratedColumn<String>(
    'store_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES stores (id) ON DELETE CASCADE',
    ),
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
  @override
  List<GeneratedColumn> get $columns => [id, storeId, name];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<CategoryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('store_id')) {
      context.handle(
        _storeIdMeta,
        storeId.isAcceptableOrUnknown(data['store_id']!, _storeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_storeIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CategoryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CategoryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      storeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}store_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
    );
  }

  @override
  $CategoriesTable createAlias(String alias) {
    return $CategoriesTable(attachedDatabase, alias);
  }
}

class CategoryRow extends DataClass implements Insertable<CategoryRow> {
  final String id;
  final String storeId;
  final String name;
  const CategoryRow({
    required this.id,
    required this.storeId,
    required this.name,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['store_id'] = Variable<String>(storeId);
    map['name'] = Variable<String>(name);
    return map;
  }

  CategoriesCompanion toCompanion(bool nullToAbsent) {
    return CategoriesCompanion(
      id: Value(id),
      storeId: Value(storeId),
      name: Value(name),
    );
  }

  factory CategoryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CategoryRow(
      id: serializer.fromJson<String>(json['id']),
      storeId: serializer.fromJson<String>(json['storeId']),
      name: serializer.fromJson<String>(json['name']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'storeId': serializer.toJson<String>(storeId),
      'name': serializer.toJson<String>(name),
    };
  }

  CategoryRow copyWith({String? id, String? storeId, String? name}) =>
      CategoryRow(
        id: id ?? this.id,
        storeId: storeId ?? this.storeId,
        name: name ?? this.name,
      );
  CategoryRow copyWithCompanion(CategoriesCompanion data) {
    return CategoryRow(
      id: data.id.present ? data.id.value : this.id,
      storeId: data.storeId.present ? data.storeId.value : this.storeId,
      name: data.name.present ? data.name.value : this.name,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CategoryRow(')
          ..write('id: $id, ')
          ..write('storeId: $storeId, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, storeId, name);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CategoryRow &&
          other.id == this.id &&
          other.storeId == this.storeId &&
          other.name == this.name);
}

class CategoriesCompanion extends UpdateCompanion<CategoryRow> {
  final Value<String> id;
  final Value<String> storeId;
  final Value<String> name;
  final Value<int> rowid;
  const CategoriesCompanion({
    this.id = const Value.absent(),
    this.storeId = const Value.absent(),
    this.name = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CategoriesCompanion.insert({
    required String id,
    required String storeId,
    required String name,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       storeId = Value(storeId),
       name = Value(name);
  static Insertable<CategoryRow> custom({
    Expression<String>? id,
    Expression<String>? storeId,
    Expression<String>? name,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (storeId != null) 'store_id': storeId,
      if (name != null) 'name': name,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CategoriesCompanion copyWith({
    Value<String>? id,
    Value<String>? storeId,
    Value<String>? name,
    Value<int>? rowid,
  }) {
    return CategoriesCompanion(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      name: name ?? this.name,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (storeId.present) {
      map['store_id'] = Variable<String>(storeId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesCompanion(')
          ..write('id: $id, ')
          ..write('storeId: $storeId, ')
          ..write('name: $name, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UnitsTable extends Units with TableInfo<$UnitsTable, UnitRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UnitsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 64,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _storeIdMeta = const VerificationMeta(
    'storeId',
  );
  @override
  late final GeneratedColumn<String> storeId = GeneratedColumn<String>(
    'store_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES stores (id) ON DELETE CASCADE',
    ),
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
  static const VerificationMeta _abbreviationMeta = const VerificationMeta(
    'abbreviation',
  );
  @override
  late final GeneratedColumn<String> abbreviation = GeneratedColumn<String>(
    'abbreviation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, storeId, name, abbreviation];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'units';
  @override
  VerificationContext validateIntegrity(
    Insertable<UnitRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('store_id')) {
      context.handle(
        _storeIdMeta,
        storeId.isAcceptableOrUnknown(data['store_id']!, _storeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_storeIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('abbreviation')) {
      context.handle(
        _abbreviationMeta,
        abbreviation.isAcceptableOrUnknown(
          data['abbreviation']!,
          _abbreviationMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_abbreviationMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UnitRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UnitRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      storeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}store_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      abbreviation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}abbreviation'],
      )!,
    );
  }

  @override
  $UnitsTable createAlias(String alias) {
    return $UnitsTable(attachedDatabase, alias);
  }
}

class UnitRow extends DataClass implements Insertable<UnitRow> {
  final String id;
  final String storeId;
  final String name;
  final String abbreviation;
  const UnitRow({
    required this.id,
    required this.storeId,
    required this.name,
    required this.abbreviation,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['store_id'] = Variable<String>(storeId);
    map['name'] = Variable<String>(name);
    map['abbreviation'] = Variable<String>(abbreviation);
    return map;
  }

  UnitsCompanion toCompanion(bool nullToAbsent) {
    return UnitsCompanion(
      id: Value(id),
      storeId: Value(storeId),
      name: Value(name),
      abbreviation: Value(abbreviation),
    );
  }

  factory UnitRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UnitRow(
      id: serializer.fromJson<String>(json['id']),
      storeId: serializer.fromJson<String>(json['storeId']),
      name: serializer.fromJson<String>(json['name']),
      abbreviation: serializer.fromJson<String>(json['abbreviation']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'storeId': serializer.toJson<String>(storeId),
      'name': serializer.toJson<String>(name),
      'abbreviation': serializer.toJson<String>(abbreviation),
    };
  }

  UnitRow copyWith({
    String? id,
    String? storeId,
    String? name,
    String? abbreviation,
  }) => UnitRow(
    id: id ?? this.id,
    storeId: storeId ?? this.storeId,
    name: name ?? this.name,
    abbreviation: abbreviation ?? this.abbreviation,
  );
  UnitRow copyWithCompanion(UnitsCompanion data) {
    return UnitRow(
      id: data.id.present ? data.id.value : this.id,
      storeId: data.storeId.present ? data.storeId.value : this.storeId,
      name: data.name.present ? data.name.value : this.name,
      abbreviation: data.abbreviation.present
          ? data.abbreviation.value
          : this.abbreviation,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UnitRow(')
          ..write('id: $id, ')
          ..write('storeId: $storeId, ')
          ..write('name: $name, ')
          ..write('abbreviation: $abbreviation')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, storeId, name, abbreviation);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UnitRow &&
          other.id == this.id &&
          other.storeId == this.storeId &&
          other.name == this.name &&
          other.abbreviation == this.abbreviation);
}

class UnitsCompanion extends UpdateCompanion<UnitRow> {
  final Value<String> id;
  final Value<String> storeId;
  final Value<String> name;
  final Value<String> abbreviation;
  final Value<int> rowid;
  const UnitsCompanion({
    this.id = const Value.absent(),
    this.storeId = const Value.absent(),
    this.name = const Value.absent(),
    this.abbreviation = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UnitsCompanion.insert({
    required String id,
    required String storeId,
    required String name,
    required String abbreviation,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       storeId = Value(storeId),
       name = Value(name),
       abbreviation = Value(abbreviation);
  static Insertable<UnitRow> custom({
    Expression<String>? id,
    Expression<String>? storeId,
    Expression<String>? name,
    Expression<String>? abbreviation,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (storeId != null) 'store_id': storeId,
      if (name != null) 'name': name,
      if (abbreviation != null) 'abbreviation': abbreviation,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UnitsCompanion copyWith({
    Value<String>? id,
    Value<String>? storeId,
    Value<String>? name,
    Value<String>? abbreviation,
    Value<int>? rowid,
  }) {
    return UnitsCompanion(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      name: name ?? this.name,
      abbreviation: abbreviation ?? this.abbreviation,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (storeId.present) {
      map['store_id'] = Variable<String>(storeId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (abbreviation.present) {
      map['abbreviation'] = Variable<String>(abbreviation.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UnitsCompanion(')
          ..write('id: $id, ')
          ..write('storeId: $storeId, ')
          ..write('name: $name, ')
          ..write('abbreviation: $abbreviation, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ItemsTable extends Items with TableInfo<$ItemsTable, ItemRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 64,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _storeIdMeta = const VerificationMeta(
    'storeId',
  );
  @override
  late final GeneratedColumn<String> storeId = GeneratedColumn<String>(
    'store_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES stores (id) ON DELETE CASCADE',
    ),
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
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES categories (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _unitIdMeta = const VerificationMeta('unitId');
  @override
  late final GeneratedColumn<String> unitId = GeneratedColumn<String>(
    'unit_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES units (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<double> quantity = GeneratedColumn<double>(
    'quantity',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lowStockThresholdMeta = const VerificationMeta(
    'lowStockThreshold',
  );
  @override
  late final GeneratedColumn<double> lowStockThreshold =
      GeneratedColumn<double>(
        'low_stock_threshold',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _maxStockMeta = const VerificationMeta(
    'maxStock',
  );
  @override
  late final GeneratedColumn<double> maxStock = GeneratedColumn<double>(
    'max_stock',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _averageCostMeta = const VerificationMeta(
    'averageCost',
  );
  @override
  late final GeneratedColumn<double> averageCost = GeneratedColumn<double>(
    'average_cost',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _defaultSupplierIdMeta = const VerificationMeta(
    'defaultSupplierId',
  );
  @override
  late final GeneratedColumn<String> defaultSupplierId =
      GeneratedColumn<String>(
        'default_supplier_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _barcodeMeta = const VerificationMeta(
    'barcode',
  );
  @override
  late final GeneratedColumn<String> barcode = GeneratedColumn<String>(
    'barcode',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    storeId,
    name,
    categoryId,
    unitId,
    quantity,
    lowStockThreshold,
    maxStock,
    updatedAt,
    averageCost,
    defaultSupplierId,
    barcode,
    note,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'items';
  @override
  VerificationContext validateIntegrity(
    Insertable<ItemRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('store_id')) {
      context.handle(
        _storeIdMeta,
        storeId.isAcceptableOrUnknown(data['store_id']!, _storeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_storeIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('unit_id')) {
      context.handle(
        _unitIdMeta,
        unitId.isAcceptableOrUnknown(data['unit_id']!, _unitIdMeta),
      );
    } else if (isInserting) {
      context.missing(_unitIdMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    } else if (isInserting) {
      context.missing(_quantityMeta);
    }
    if (data.containsKey('low_stock_threshold')) {
      context.handle(
        _lowStockThresholdMeta,
        lowStockThreshold.isAcceptableOrUnknown(
          data['low_stock_threshold']!,
          _lowStockThresholdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lowStockThresholdMeta);
    }
    if (data.containsKey('max_stock')) {
      context.handle(
        _maxStockMeta,
        maxStock.isAcceptableOrUnknown(data['max_stock']!, _maxStockMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('average_cost')) {
      context.handle(
        _averageCostMeta,
        averageCost.isAcceptableOrUnknown(
          data['average_cost']!,
          _averageCostMeta,
        ),
      );
    }
    if (data.containsKey('default_supplier_id')) {
      context.handle(
        _defaultSupplierIdMeta,
        defaultSupplierId.isAcceptableOrUnknown(
          data['default_supplier_id']!,
          _defaultSupplierIdMeta,
        ),
      );
    }
    if (data.containsKey('barcode')) {
      context.handle(
        _barcodeMeta,
        barcode.isAcceptableOrUnknown(data['barcode']!, _barcodeMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ItemRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ItemRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      storeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}store_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      )!,
      unitId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit_id'],
      )!,
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}quantity'],
      )!,
      lowStockThreshold: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}low_stock_threshold'],
      )!,
      maxStock: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}max_stock'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      averageCost: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}average_cost'],
      ),
      defaultSupplierId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}default_supplier_id'],
      ),
      barcode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}barcode'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
    );
  }

  @override
  $ItemsTable createAlias(String alias) {
    return $ItemsTable(attachedDatabase, alias);
  }
}

class ItemRow extends DataClass implements Insertable<ItemRow> {
  final String id;
  final String storeId;
  final String name;

  /// `RESTRICT`, so "a category in use cannot be deleted" is a fact about the
  /// database rather than a check somebody could forget to call. The repository
  /// keeps its own check as well — that one produces the count the dialog shows
  /// ("3 articles utilisent cette catégorie"), and this one is the backstop for
  /// every path that does not go through it.
  final String categoryId;
  final String unitId;

  /// Current quantity on hand.
  ///
  /// Written by exactly one file, `repositories/movement_repository.dart`, and
  /// always in the same transaction as the movement that explains the change.
  /// The invariant is `quantity == opening balance + sum of movements`, and
  /// `tool/ux_audit.py` guards the monopoly mechanically.
  final double quantity;
  final double lowStockThreshold;

  /// How much of this product the establishment wants on the shelf when it is
  /// fully stocked. What a commande tops up *to*.
  ///
  /// Zero means no ceiling has been declared, and the ordering screen falls
  /// back to its threshold-based figure. Not nullable for that: a maximum of
  /// zero says "order none of this, ever", which is not a thing anybody means,
  /// so the sentinel cannot collide with a real value. Defaulted rather than
  /// backfilled, so a database upgraded in place reads what a fresh one would.
  final double maxStock;
  final DateTime updatedAt;

  /// Weighted average cost (CUMP) of the stock on hand, in EUR.
  ///
  /// Nullable because null means **unknown**, not zero: an item with no cost and
  /// no supplier on file contributes nothing to the valuation. Understating
  /// beats inventing.
  final double? averageCost;

  /// The supplier pre-selected when receiving a delivery.
  ///
  /// **No foreign key, on purpose.** Deleting a supplier keeps the stock
  /// movements that name them and their closed orders, and does not walk the
  /// catalogue clearing this field — so it is allowed to point at a supplier who
  /// is gone, exactly as it was in Phase 1. The screen that reads it treats a
  /// miss as "no preference". An FK would either forbid the delete or silently
  /// rewrite history to make the constraint true.
  final String? defaultSupplierId;

  /// Unique across a store, enforced when the item form saves. Empty input is
  /// stored as null rather than '', so "no barcode" is one value and not two.
  final String? barcode;
  final String? note;
  const ItemRow({
    required this.id,
    required this.storeId,
    required this.name,
    required this.categoryId,
    required this.unitId,
    required this.quantity,
    required this.lowStockThreshold,
    required this.maxStock,
    required this.updatedAt,
    this.averageCost,
    this.defaultSupplierId,
    this.barcode,
    this.note,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['store_id'] = Variable<String>(storeId);
    map['name'] = Variable<String>(name);
    map['category_id'] = Variable<String>(categoryId);
    map['unit_id'] = Variable<String>(unitId);
    map['quantity'] = Variable<double>(quantity);
    map['low_stock_threshold'] = Variable<double>(lowStockThreshold);
    map['max_stock'] = Variable<double>(maxStock);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || averageCost != null) {
      map['average_cost'] = Variable<double>(averageCost);
    }
    if (!nullToAbsent || defaultSupplierId != null) {
      map['default_supplier_id'] = Variable<String>(defaultSupplierId);
    }
    if (!nullToAbsent || barcode != null) {
      map['barcode'] = Variable<String>(barcode);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    return map;
  }

  ItemsCompanion toCompanion(bool nullToAbsent) {
    return ItemsCompanion(
      id: Value(id),
      storeId: Value(storeId),
      name: Value(name),
      categoryId: Value(categoryId),
      unitId: Value(unitId),
      quantity: Value(quantity),
      lowStockThreshold: Value(lowStockThreshold),
      maxStock: Value(maxStock),
      updatedAt: Value(updatedAt),
      averageCost: averageCost == null && nullToAbsent
          ? const Value.absent()
          : Value(averageCost),
      defaultSupplierId: defaultSupplierId == null && nullToAbsent
          ? const Value.absent()
          : Value(defaultSupplierId),
      barcode: barcode == null && nullToAbsent
          ? const Value.absent()
          : Value(barcode),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
    );
  }

  factory ItemRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ItemRow(
      id: serializer.fromJson<String>(json['id']),
      storeId: serializer.fromJson<String>(json['storeId']),
      name: serializer.fromJson<String>(json['name']),
      categoryId: serializer.fromJson<String>(json['categoryId']),
      unitId: serializer.fromJson<String>(json['unitId']),
      quantity: serializer.fromJson<double>(json['quantity']),
      lowStockThreshold: serializer.fromJson<double>(json['lowStockThreshold']),
      maxStock: serializer.fromJson<double>(json['maxStock']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      averageCost: serializer.fromJson<double?>(json['averageCost']),
      defaultSupplierId: serializer.fromJson<String?>(
        json['defaultSupplierId'],
      ),
      barcode: serializer.fromJson<String?>(json['barcode']),
      note: serializer.fromJson<String?>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'storeId': serializer.toJson<String>(storeId),
      'name': serializer.toJson<String>(name),
      'categoryId': serializer.toJson<String>(categoryId),
      'unitId': serializer.toJson<String>(unitId),
      'quantity': serializer.toJson<double>(quantity),
      'lowStockThreshold': serializer.toJson<double>(lowStockThreshold),
      'maxStock': serializer.toJson<double>(maxStock),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'averageCost': serializer.toJson<double?>(averageCost),
      'defaultSupplierId': serializer.toJson<String?>(defaultSupplierId),
      'barcode': serializer.toJson<String?>(barcode),
      'note': serializer.toJson<String?>(note),
    };
  }

  ItemRow copyWith({
    String? id,
    String? storeId,
    String? name,
    String? categoryId,
    String? unitId,
    double? quantity,
    double? lowStockThreshold,
    double? maxStock,
    DateTime? updatedAt,
    Value<double?> averageCost = const Value.absent(),
    Value<String?> defaultSupplierId = const Value.absent(),
    Value<String?> barcode = const Value.absent(),
    Value<String?> note = const Value.absent(),
  }) => ItemRow(
    id: id ?? this.id,
    storeId: storeId ?? this.storeId,
    name: name ?? this.name,
    categoryId: categoryId ?? this.categoryId,
    unitId: unitId ?? this.unitId,
    quantity: quantity ?? this.quantity,
    lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
    maxStock: maxStock ?? this.maxStock,
    updatedAt: updatedAt ?? this.updatedAt,
    averageCost: averageCost.present ? averageCost.value : this.averageCost,
    defaultSupplierId: defaultSupplierId.present
        ? defaultSupplierId.value
        : this.defaultSupplierId,
    barcode: barcode.present ? barcode.value : this.barcode,
    note: note.present ? note.value : this.note,
  );
  ItemRow copyWithCompanion(ItemsCompanion data) {
    return ItemRow(
      id: data.id.present ? data.id.value : this.id,
      storeId: data.storeId.present ? data.storeId.value : this.storeId,
      name: data.name.present ? data.name.value : this.name,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      unitId: data.unitId.present ? data.unitId.value : this.unitId,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      lowStockThreshold: data.lowStockThreshold.present
          ? data.lowStockThreshold.value
          : this.lowStockThreshold,
      maxStock: data.maxStock.present ? data.maxStock.value : this.maxStock,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      averageCost: data.averageCost.present
          ? data.averageCost.value
          : this.averageCost,
      defaultSupplierId: data.defaultSupplierId.present
          ? data.defaultSupplierId.value
          : this.defaultSupplierId,
      barcode: data.barcode.present ? data.barcode.value : this.barcode,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ItemRow(')
          ..write('id: $id, ')
          ..write('storeId: $storeId, ')
          ..write('name: $name, ')
          ..write('categoryId: $categoryId, ')
          ..write('unitId: $unitId, ')
          ..write('quantity: $quantity, ')
          ..write('lowStockThreshold: $lowStockThreshold, ')
          ..write('maxStock: $maxStock, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('averageCost: $averageCost, ')
          ..write('defaultSupplierId: $defaultSupplierId, ')
          ..write('barcode: $barcode, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    storeId,
    name,
    categoryId,
    unitId,
    quantity,
    lowStockThreshold,
    maxStock,
    updatedAt,
    averageCost,
    defaultSupplierId,
    barcode,
    note,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ItemRow &&
          other.id == this.id &&
          other.storeId == this.storeId &&
          other.name == this.name &&
          other.categoryId == this.categoryId &&
          other.unitId == this.unitId &&
          other.quantity == this.quantity &&
          other.lowStockThreshold == this.lowStockThreshold &&
          other.maxStock == this.maxStock &&
          other.updatedAt == this.updatedAt &&
          other.averageCost == this.averageCost &&
          other.defaultSupplierId == this.defaultSupplierId &&
          other.barcode == this.barcode &&
          other.note == this.note);
}

class ItemsCompanion extends UpdateCompanion<ItemRow> {
  final Value<String> id;
  final Value<String> storeId;
  final Value<String> name;
  final Value<String> categoryId;
  final Value<String> unitId;
  final Value<double> quantity;
  final Value<double> lowStockThreshold;
  final Value<double> maxStock;
  final Value<DateTime> updatedAt;
  final Value<double?> averageCost;
  final Value<String?> defaultSupplierId;
  final Value<String?> barcode;
  final Value<String?> note;
  final Value<int> rowid;
  const ItemsCompanion({
    this.id = const Value.absent(),
    this.storeId = const Value.absent(),
    this.name = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.unitId = const Value.absent(),
    this.quantity = const Value.absent(),
    this.lowStockThreshold = const Value.absent(),
    this.maxStock = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.averageCost = const Value.absent(),
    this.defaultSupplierId = const Value.absent(),
    this.barcode = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ItemsCompanion.insert({
    required String id,
    required String storeId,
    required String name,
    required String categoryId,
    required String unitId,
    required double quantity,
    required double lowStockThreshold,
    this.maxStock = const Value.absent(),
    required DateTime updatedAt,
    this.averageCost = const Value.absent(),
    this.defaultSupplierId = const Value.absent(),
    this.barcode = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       storeId = Value(storeId),
       name = Value(name),
       categoryId = Value(categoryId),
       unitId = Value(unitId),
       quantity = Value(quantity),
       lowStockThreshold = Value(lowStockThreshold),
       updatedAt = Value(updatedAt);
  static Insertable<ItemRow> custom({
    Expression<String>? id,
    Expression<String>? storeId,
    Expression<String>? name,
    Expression<String>? categoryId,
    Expression<String>? unitId,
    Expression<double>? quantity,
    Expression<double>? lowStockThreshold,
    Expression<double>? maxStock,
    Expression<DateTime>? updatedAt,
    Expression<double>? averageCost,
    Expression<String>? defaultSupplierId,
    Expression<String>? barcode,
    Expression<String>? note,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (storeId != null) 'store_id': storeId,
      if (name != null) 'name': name,
      if (categoryId != null) 'category_id': categoryId,
      if (unitId != null) 'unit_id': unitId,
      if (quantity != null) 'quantity': quantity,
      if (lowStockThreshold != null) 'low_stock_threshold': lowStockThreshold,
      if (maxStock != null) 'max_stock': maxStock,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (averageCost != null) 'average_cost': averageCost,
      if (defaultSupplierId != null) 'default_supplier_id': defaultSupplierId,
      if (barcode != null) 'barcode': barcode,
      if (note != null) 'note': note,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? storeId,
    Value<String>? name,
    Value<String>? categoryId,
    Value<String>? unitId,
    Value<double>? quantity,
    Value<double>? lowStockThreshold,
    Value<double>? maxStock,
    Value<DateTime>? updatedAt,
    Value<double?>? averageCost,
    Value<String?>? defaultSupplierId,
    Value<String?>? barcode,
    Value<String?>? note,
    Value<int>? rowid,
  }) {
    return ItemsCompanion(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      unitId: unitId ?? this.unitId,
      quantity: quantity ?? this.quantity,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      maxStock: maxStock ?? this.maxStock,
      updatedAt: updatedAt ?? this.updatedAt,
      averageCost: averageCost ?? this.averageCost,
      defaultSupplierId: defaultSupplierId ?? this.defaultSupplierId,
      barcode: barcode ?? this.barcode,
      note: note ?? this.note,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (storeId.present) {
      map['store_id'] = Variable<String>(storeId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (unitId.present) {
      map['unit_id'] = Variable<String>(unitId.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<double>(quantity.value);
    }
    if (lowStockThreshold.present) {
      map['low_stock_threshold'] = Variable<double>(lowStockThreshold.value);
    }
    if (maxStock.present) {
      map['max_stock'] = Variable<double>(maxStock.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (averageCost.present) {
      map['average_cost'] = Variable<double>(averageCost.value);
    }
    if (defaultSupplierId.present) {
      map['default_supplier_id'] = Variable<String>(defaultSupplierId.value);
    }
    if (barcode.present) {
      map['barcode'] = Variable<String>(barcode.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ItemsCompanion(')
          ..write('id: $id, ')
          ..write('storeId: $storeId, ')
          ..write('name: $name, ')
          ..write('categoryId: $categoryId, ')
          ..write('unitId: $unitId, ')
          ..write('quantity: $quantity, ')
          ..write('lowStockThreshold: $lowStockThreshold, ')
          ..write('maxStock: $maxStock, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('averageCost: $averageCost, ')
          ..write('defaultSupplierId: $defaultSupplierId, ')
          ..write('barcode: $barcode, ')
          ..write('note: $note, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SuppliersTable extends Suppliers
    with TableInfo<$SuppliersTable, SupplierRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SuppliersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 64,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _storeIdMeta = const VerificationMeta(
    'storeId',
  );
  @override
  late final GeneratedColumn<String> storeId = GeneratedColumn<String>(
    'store_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES stores (id) ON DELETE CASCADE',
    ),
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
  static const VerificationMeta _contactNameMeta = const VerificationMeta(
    'contactName',
  );
  @override
  late final GeneratedColumn<String> contactName = GeneratedColumn<String>(
    'contact_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addressLineMeta = const VerificationMeta(
    'addressLine',
  );
  @override
  late final GeneratedColumn<String> addressLine = GeneratedColumn<String>(
    'address_line',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _postalCodeMeta = const VerificationMeta(
    'postalCode',
  );
  @override
  late final GeneratedColumn<String> postalCode = GeneratedColumn<String>(
    'postal_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cityMeta = const VerificationMeta('city');
  @override
  late final GeneratedColumn<String> city = GeneratedColumn<String>(
    'city',
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
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    storeId,
    name,
    contactName,
    email,
    phone,
    addressLine,
    postalCode,
    city,
    note,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'suppliers';
  @override
  VerificationContext validateIntegrity(
    Insertable<SupplierRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('store_id')) {
      context.handle(
        _storeIdMeta,
        storeId.isAcceptableOrUnknown(data['store_id']!, _storeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_storeIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('contact_name')) {
      context.handle(
        _contactNameMeta,
        contactName.isAcceptableOrUnknown(
          data['contact_name']!,
          _contactNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contactNameMeta);
    }
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    } else if (isInserting) {
      context.missing(_emailMeta);
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    } else if (isInserting) {
      context.missing(_phoneMeta);
    }
    if (data.containsKey('address_line')) {
      context.handle(
        _addressLineMeta,
        addressLine.isAcceptableOrUnknown(
          data['address_line']!,
          _addressLineMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_addressLineMeta);
    }
    if (data.containsKey('postal_code')) {
      context.handle(
        _postalCodeMeta,
        postalCode.isAcceptableOrUnknown(data['postal_code']!, _postalCodeMeta),
      );
    } else if (isInserting) {
      context.missing(_postalCodeMeta);
    }
    if (data.containsKey('city')) {
      context.handle(
        _cityMeta,
        city.isAcceptableOrUnknown(data['city']!, _cityMeta),
      );
    } else if (isInserting) {
      context.missing(_cityMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SupplierRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SupplierRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      storeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}store_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      contactName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}contact_name'],
      )!,
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      )!,
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      )!,
      addressLine: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address_line'],
      )!,
      postalCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}postal_code'],
      )!,
      city: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}city'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
    );
  }

  @override
  $SuppliersTable createAlias(String alias) {
    return $SuppliersTable(attachedDatabase, alias);
  }
}

class SupplierRow extends DataClass implements Insertable<SupplierRow> {
  final String id;
  final String storeId;
  final String name;
  final String contactName;
  final String email;
  final String phone;
  final String addressLine;
  final String postalCode;
  final String city;
  final String? note;
  const SupplierRow({
    required this.id,
    required this.storeId,
    required this.name,
    required this.contactName,
    required this.email,
    required this.phone,
    required this.addressLine,
    required this.postalCode,
    required this.city,
    this.note,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['store_id'] = Variable<String>(storeId);
    map['name'] = Variable<String>(name);
    map['contact_name'] = Variable<String>(contactName);
    map['email'] = Variable<String>(email);
    map['phone'] = Variable<String>(phone);
    map['address_line'] = Variable<String>(addressLine);
    map['postal_code'] = Variable<String>(postalCode);
    map['city'] = Variable<String>(city);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    return map;
  }

  SuppliersCompanion toCompanion(bool nullToAbsent) {
    return SuppliersCompanion(
      id: Value(id),
      storeId: Value(storeId),
      name: Value(name),
      contactName: Value(contactName),
      email: Value(email),
      phone: Value(phone),
      addressLine: Value(addressLine),
      postalCode: Value(postalCode),
      city: Value(city),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
    );
  }

  factory SupplierRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SupplierRow(
      id: serializer.fromJson<String>(json['id']),
      storeId: serializer.fromJson<String>(json['storeId']),
      name: serializer.fromJson<String>(json['name']),
      contactName: serializer.fromJson<String>(json['contactName']),
      email: serializer.fromJson<String>(json['email']),
      phone: serializer.fromJson<String>(json['phone']),
      addressLine: serializer.fromJson<String>(json['addressLine']),
      postalCode: serializer.fromJson<String>(json['postalCode']),
      city: serializer.fromJson<String>(json['city']),
      note: serializer.fromJson<String?>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'storeId': serializer.toJson<String>(storeId),
      'name': serializer.toJson<String>(name),
      'contactName': serializer.toJson<String>(contactName),
      'email': serializer.toJson<String>(email),
      'phone': serializer.toJson<String>(phone),
      'addressLine': serializer.toJson<String>(addressLine),
      'postalCode': serializer.toJson<String>(postalCode),
      'city': serializer.toJson<String>(city),
      'note': serializer.toJson<String?>(note),
    };
  }

  SupplierRow copyWith({
    String? id,
    String? storeId,
    String? name,
    String? contactName,
    String? email,
    String? phone,
    String? addressLine,
    String? postalCode,
    String? city,
    Value<String?> note = const Value.absent(),
  }) => SupplierRow(
    id: id ?? this.id,
    storeId: storeId ?? this.storeId,
    name: name ?? this.name,
    contactName: contactName ?? this.contactName,
    email: email ?? this.email,
    phone: phone ?? this.phone,
    addressLine: addressLine ?? this.addressLine,
    postalCode: postalCode ?? this.postalCode,
    city: city ?? this.city,
    note: note.present ? note.value : this.note,
  );
  SupplierRow copyWithCompanion(SuppliersCompanion data) {
    return SupplierRow(
      id: data.id.present ? data.id.value : this.id,
      storeId: data.storeId.present ? data.storeId.value : this.storeId,
      name: data.name.present ? data.name.value : this.name,
      contactName: data.contactName.present
          ? data.contactName.value
          : this.contactName,
      email: data.email.present ? data.email.value : this.email,
      phone: data.phone.present ? data.phone.value : this.phone,
      addressLine: data.addressLine.present
          ? data.addressLine.value
          : this.addressLine,
      postalCode: data.postalCode.present
          ? data.postalCode.value
          : this.postalCode,
      city: data.city.present ? data.city.value : this.city,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SupplierRow(')
          ..write('id: $id, ')
          ..write('storeId: $storeId, ')
          ..write('name: $name, ')
          ..write('contactName: $contactName, ')
          ..write('email: $email, ')
          ..write('phone: $phone, ')
          ..write('addressLine: $addressLine, ')
          ..write('postalCode: $postalCode, ')
          ..write('city: $city, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    storeId,
    name,
    contactName,
    email,
    phone,
    addressLine,
    postalCode,
    city,
    note,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SupplierRow &&
          other.id == this.id &&
          other.storeId == this.storeId &&
          other.name == this.name &&
          other.contactName == this.contactName &&
          other.email == this.email &&
          other.phone == this.phone &&
          other.addressLine == this.addressLine &&
          other.postalCode == this.postalCode &&
          other.city == this.city &&
          other.note == this.note);
}

class SuppliersCompanion extends UpdateCompanion<SupplierRow> {
  final Value<String> id;
  final Value<String> storeId;
  final Value<String> name;
  final Value<String> contactName;
  final Value<String> email;
  final Value<String> phone;
  final Value<String> addressLine;
  final Value<String> postalCode;
  final Value<String> city;
  final Value<String?> note;
  final Value<int> rowid;
  const SuppliersCompanion({
    this.id = const Value.absent(),
    this.storeId = const Value.absent(),
    this.name = const Value.absent(),
    this.contactName = const Value.absent(),
    this.email = const Value.absent(),
    this.phone = const Value.absent(),
    this.addressLine = const Value.absent(),
    this.postalCode = const Value.absent(),
    this.city = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SuppliersCompanion.insert({
    required String id,
    required String storeId,
    required String name,
    required String contactName,
    required String email,
    required String phone,
    required String addressLine,
    required String postalCode,
    required String city,
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       storeId = Value(storeId),
       name = Value(name),
       contactName = Value(contactName),
       email = Value(email),
       phone = Value(phone),
       addressLine = Value(addressLine),
       postalCode = Value(postalCode),
       city = Value(city);
  static Insertable<SupplierRow> custom({
    Expression<String>? id,
    Expression<String>? storeId,
    Expression<String>? name,
    Expression<String>? contactName,
    Expression<String>? email,
    Expression<String>? phone,
    Expression<String>? addressLine,
    Expression<String>? postalCode,
    Expression<String>? city,
    Expression<String>? note,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (storeId != null) 'store_id': storeId,
      if (name != null) 'name': name,
      if (contactName != null) 'contact_name': contactName,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (addressLine != null) 'address_line': addressLine,
      if (postalCode != null) 'postal_code': postalCode,
      if (city != null) 'city': city,
      if (note != null) 'note': note,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SuppliersCompanion copyWith({
    Value<String>? id,
    Value<String>? storeId,
    Value<String>? name,
    Value<String>? contactName,
    Value<String>? email,
    Value<String>? phone,
    Value<String>? addressLine,
    Value<String>? postalCode,
    Value<String>? city,
    Value<String?>? note,
    Value<int>? rowid,
  }) {
    return SuppliersCompanion(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      name: name ?? this.name,
      contactName: contactName ?? this.contactName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      addressLine: addressLine ?? this.addressLine,
      postalCode: postalCode ?? this.postalCode,
      city: city ?? this.city,
      note: note ?? this.note,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (storeId.present) {
      map['store_id'] = Variable<String>(storeId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (contactName.present) {
      map['contact_name'] = Variable<String>(contactName.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (addressLine.present) {
      map['address_line'] = Variable<String>(addressLine.value);
    }
    if (postalCode.present) {
      map['postal_code'] = Variable<String>(postalCode.value);
    }
    if (city.present) {
      map['city'] = Variable<String>(city.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SuppliersCompanion(')
          ..write('id: $id, ')
          ..write('storeId: $storeId, ')
          ..write('name: $name, ')
          ..write('contactName: $contactName, ')
          ..write('email: $email, ')
          ..write('phone: $phone, ')
          ..write('addressLine: $addressLine, ')
          ..write('postalCode: $postalCode, ')
          ..write('city: $city, ')
          ..write('note: $note, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SupplierPricesTable extends SupplierPrices
    with TableInfo<$SupplierPricesTable, SupplierPriceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SupplierPricesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 64,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES items (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _supplierIdMeta = const VerificationMeta(
    'supplierId',
  );
  @override
  late final GeneratedColumn<String> supplierId = GeneratedColumn<String>(
    'supplier_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES suppliers (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _pricePerUnitMeta = const VerificationMeta(
    'pricePerUnit',
  );
  @override
  late final GeneratedColumn<double> pricePerUnit = GeneratedColumn<double>(
    'price_per_unit',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _effectiveDateMeta = const VerificationMeta(
    'effectiveDate',
  );
  @override
  late final GeneratedColumn<DateTime> effectiveDate =
      GeneratedColumn<DateTime>(
        'effective_date',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _isDefaultMeta = const VerificationMeta(
    'isDefault',
  );
  @override
  late final GeneratedColumn<bool> isDefault = GeneratedColumn<bool>(
    'is_default',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_default" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    itemId,
    supplierId,
    pricePerUnit,
    effectiveDate,
    isDefault,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'supplier_prices';
  @override
  VerificationContext validateIntegrity(
    Insertable<SupplierPriceRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('supplier_id')) {
      context.handle(
        _supplierIdMeta,
        supplierId.isAcceptableOrUnknown(data['supplier_id']!, _supplierIdMeta),
      );
    } else if (isInserting) {
      context.missing(_supplierIdMeta);
    }
    if (data.containsKey('price_per_unit')) {
      context.handle(
        _pricePerUnitMeta,
        pricePerUnit.isAcceptableOrUnknown(
          data['price_per_unit']!,
          _pricePerUnitMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_pricePerUnitMeta);
    }
    if (data.containsKey('effective_date')) {
      context.handle(
        _effectiveDateMeta,
        effectiveDate.isAcceptableOrUnknown(
          data['effective_date']!,
          _effectiveDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_effectiveDateMeta);
    }
    if (data.containsKey('is_default')) {
      context.handle(
        _isDefaultMeta,
        isDefault.isAcceptableOrUnknown(data['is_default']!, _isDefaultMeta),
      );
    } else if (isInserting) {
      context.missing(_isDefaultMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SupplierPriceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SupplierPriceRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      supplierId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}supplier_id'],
      )!,
      pricePerUnit: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}price_per_unit'],
      )!,
      effectiveDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}effective_date'],
      )!,
      isDefault: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_default'],
      )!,
    );
  }

  @override
  $SupplierPricesTable createAlias(String alias) {
    return $SupplierPricesTable(attachedDatabase, alias);
  }
}

class SupplierPriceRow extends DataClass
    implements Insertable<SupplierPriceRow> {
  final String id;
  final String itemId;
  final String supplierId;

  /// What the *next* unit will cost. Never used to value stock on hand — that
  /// is `items.averageCost`, and confusing the two is what made the valuation
  /// report revalue last week's stock at this morning's delivery price.
  final double pricePerUnit;
  final DateTime effectiveDate;

  /// Exactly one true per item, maintained by the supplier repository in a
  /// transaction (clear, then set). Not expressible as a constraint in SQLite
  /// without a trigger, and a trigger would be a second place the rule lives.
  final bool isDefault;
  const SupplierPriceRow({
    required this.id,
    required this.itemId,
    required this.supplierId,
    required this.pricePerUnit,
    required this.effectiveDate,
    required this.isDefault,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['item_id'] = Variable<String>(itemId);
    map['supplier_id'] = Variable<String>(supplierId);
    map['price_per_unit'] = Variable<double>(pricePerUnit);
    map['effective_date'] = Variable<DateTime>(effectiveDate);
    map['is_default'] = Variable<bool>(isDefault);
    return map;
  }

  SupplierPricesCompanion toCompanion(bool nullToAbsent) {
    return SupplierPricesCompanion(
      id: Value(id),
      itemId: Value(itemId),
      supplierId: Value(supplierId),
      pricePerUnit: Value(pricePerUnit),
      effectiveDate: Value(effectiveDate),
      isDefault: Value(isDefault),
    );
  }

  factory SupplierPriceRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SupplierPriceRow(
      id: serializer.fromJson<String>(json['id']),
      itemId: serializer.fromJson<String>(json['itemId']),
      supplierId: serializer.fromJson<String>(json['supplierId']),
      pricePerUnit: serializer.fromJson<double>(json['pricePerUnit']),
      effectiveDate: serializer.fromJson<DateTime>(json['effectiveDate']),
      isDefault: serializer.fromJson<bool>(json['isDefault']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'itemId': serializer.toJson<String>(itemId),
      'supplierId': serializer.toJson<String>(supplierId),
      'pricePerUnit': serializer.toJson<double>(pricePerUnit),
      'effectiveDate': serializer.toJson<DateTime>(effectiveDate),
      'isDefault': serializer.toJson<bool>(isDefault),
    };
  }

  SupplierPriceRow copyWith({
    String? id,
    String? itemId,
    String? supplierId,
    double? pricePerUnit,
    DateTime? effectiveDate,
    bool? isDefault,
  }) => SupplierPriceRow(
    id: id ?? this.id,
    itemId: itemId ?? this.itemId,
    supplierId: supplierId ?? this.supplierId,
    pricePerUnit: pricePerUnit ?? this.pricePerUnit,
    effectiveDate: effectiveDate ?? this.effectiveDate,
    isDefault: isDefault ?? this.isDefault,
  );
  SupplierPriceRow copyWithCompanion(SupplierPricesCompanion data) {
    return SupplierPriceRow(
      id: data.id.present ? data.id.value : this.id,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      supplierId: data.supplierId.present
          ? data.supplierId.value
          : this.supplierId,
      pricePerUnit: data.pricePerUnit.present
          ? data.pricePerUnit.value
          : this.pricePerUnit,
      effectiveDate: data.effectiveDate.present
          ? data.effectiveDate.value
          : this.effectiveDate,
      isDefault: data.isDefault.present ? data.isDefault.value : this.isDefault,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SupplierPriceRow(')
          ..write('id: $id, ')
          ..write('itemId: $itemId, ')
          ..write('supplierId: $supplierId, ')
          ..write('pricePerUnit: $pricePerUnit, ')
          ..write('effectiveDate: $effectiveDate, ')
          ..write('isDefault: $isDefault')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    itemId,
    supplierId,
    pricePerUnit,
    effectiveDate,
    isDefault,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SupplierPriceRow &&
          other.id == this.id &&
          other.itemId == this.itemId &&
          other.supplierId == this.supplierId &&
          other.pricePerUnit == this.pricePerUnit &&
          other.effectiveDate == this.effectiveDate &&
          other.isDefault == this.isDefault);
}

class SupplierPricesCompanion extends UpdateCompanion<SupplierPriceRow> {
  final Value<String> id;
  final Value<String> itemId;
  final Value<String> supplierId;
  final Value<double> pricePerUnit;
  final Value<DateTime> effectiveDate;
  final Value<bool> isDefault;
  final Value<int> rowid;
  const SupplierPricesCompanion({
    this.id = const Value.absent(),
    this.itemId = const Value.absent(),
    this.supplierId = const Value.absent(),
    this.pricePerUnit = const Value.absent(),
    this.effectiveDate = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SupplierPricesCompanion.insert({
    required String id,
    required String itemId,
    required String supplierId,
    required double pricePerUnit,
    required DateTime effectiveDate,
    required bool isDefault,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       itemId = Value(itemId),
       supplierId = Value(supplierId),
       pricePerUnit = Value(pricePerUnit),
       effectiveDate = Value(effectiveDate),
       isDefault = Value(isDefault);
  static Insertable<SupplierPriceRow> custom({
    Expression<String>? id,
    Expression<String>? itemId,
    Expression<String>? supplierId,
    Expression<double>? pricePerUnit,
    Expression<DateTime>? effectiveDate,
    Expression<bool>? isDefault,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (itemId != null) 'item_id': itemId,
      if (supplierId != null) 'supplier_id': supplierId,
      if (pricePerUnit != null) 'price_per_unit': pricePerUnit,
      if (effectiveDate != null) 'effective_date': effectiveDate,
      if (isDefault != null) 'is_default': isDefault,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SupplierPricesCompanion copyWith({
    Value<String>? id,
    Value<String>? itemId,
    Value<String>? supplierId,
    Value<double>? pricePerUnit,
    Value<DateTime>? effectiveDate,
    Value<bool>? isDefault,
    Value<int>? rowid,
  }) {
    return SupplierPricesCompanion(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      supplierId: supplierId ?? this.supplierId,
      pricePerUnit: pricePerUnit ?? this.pricePerUnit,
      effectiveDate: effectiveDate ?? this.effectiveDate,
      isDefault: isDefault ?? this.isDefault,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (supplierId.present) {
      map['supplier_id'] = Variable<String>(supplierId.value);
    }
    if (pricePerUnit.present) {
      map['price_per_unit'] = Variable<double>(pricePerUnit.value);
    }
    if (effectiveDate.present) {
      map['effective_date'] = Variable<DateTime>(effectiveDate.value);
    }
    if (isDefault.present) {
      map['is_default'] = Variable<bool>(isDefault.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SupplierPricesCompanion(')
          ..write('id: $id, ')
          ..write('itemId: $itemId, ')
          ..write('supplierId: $supplierId, ')
          ..write('pricePerUnit: $pricePerUnit, ')
          ..write('effectiveDate: $effectiveDate, ')
          ..write('isDefault: $isDefault, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PriceHistoryTable extends PriceHistory
    with TableInfo<$PriceHistoryTable, PriceHistoryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PriceHistoryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 64,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES items (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _supplierIdMeta = const VerificationMeta(
    'supplierId',
  );
  @override
  late final GeneratedColumn<String> supplierId = GeneratedColumn<String>(
    'supplier_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES suppliers (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _oldPriceMeta = const VerificationMeta(
    'oldPrice',
  );
  @override
  late final GeneratedColumn<double> oldPrice = GeneratedColumn<double>(
    'old_price',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _newPriceMeta = const VerificationMeta(
    'newPrice',
  );
  @override
  late final GeneratedColumn<double> newPrice = GeneratedColumn<double>(
    'new_price',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _changedAtMeta = const VerificationMeta(
    'changedAt',
  );
  @override
  late final GeneratedColumn<DateTime> changedAt = GeneratedColumn<DateTime>(
    'changed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _changedByNameMeta = const VerificationMeta(
    'changedByName',
  );
  @override
  late final GeneratedColumn<String> changedByName = GeneratedColumn<String>(
    'changed_by_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    itemId,
    supplierId,
    oldPrice,
    newPrice,
    changedAt,
    changedByName,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'price_history';
  @override
  VerificationContext validateIntegrity(
    Insertable<PriceHistoryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('supplier_id')) {
      context.handle(
        _supplierIdMeta,
        supplierId.isAcceptableOrUnknown(data['supplier_id']!, _supplierIdMeta),
      );
    } else if (isInserting) {
      context.missing(_supplierIdMeta);
    }
    if (data.containsKey('old_price')) {
      context.handle(
        _oldPriceMeta,
        oldPrice.isAcceptableOrUnknown(data['old_price']!, _oldPriceMeta),
      );
    } else if (isInserting) {
      context.missing(_oldPriceMeta);
    }
    if (data.containsKey('new_price')) {
      context.handle(
        _newPriceMeta,
        newPrice.isAcceptableOrUnknown(data['new_price']!, _newPriceMeta),
      );
    } else if (isInserting) {
      context.missing(_newPriceMeta);
    }
    if (data.containsKey('changed_at')) {
      context.handle(
        _changedAtMeta,
        changedAt.isAcceptableOrUnknown(data['changed_at']!, _changedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_changedAtMeta);
    }
    if (data.containsKey('changed_by_name')) {
      context.handle(
        _changedByNameMeta,
        changedByName.isAcceptableOrUnknown(
          data['changed_by_name']!,
          _changedByNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_changedByNameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PriceHistoryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PriceHistoryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      supplierId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}supplier_id'],
      )!,
      oldPrice: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}old_price'],
      )!,
      newPrice: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}new_price'],
      )!,
      changedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}changed_at'],
      )!,
      changedByName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}changed_by_name'],
      )!,
    );
  }

  @override
  $PriceHistoryTable createAlias(String alias) {
    return $PriceHistoryTable(attachedDatabase, alias);
  }
}

class PriceHistoryRow extends DataClass implements Insertable<PriceHistoryRow> {
  final String id;
  final String itemId;
  final String supplierId;
  final double oldPrice;
  final double newPrice;
  final DateTime changedAt;

  /// The name, not the id. The person may leave the team; what they did to the
  /// price stays legible.
  final String changedByName;
  const PriceHistoryRow({
    required this.id,
    required this.itemId,
    required this.supplierId,
    required this.oldPrice,
    required this.newPrice,
    required this.changedAt,
    required this.changedByName,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['item_id'] = Variable<String>(itemId);
    map['supplier_id'] = Variable<String>(supplierId);
    map['old_price'] = Variable<double>(oldPrice);
    map['new_price'] = Variable<double>(newPrice);
    map['changed_at'] = Variable<DateTime>(changedAt);
    map['changed_by_name'] = Variable<String>(changedByName);
    return map;
  }

  PriceHistoryCompanion toCompanion(bool nullToAbsent) {
    return PriceHistoryCompanion(
      id: Value(id),
      itemId: Value(itemId),
      supplierId: Value(supplierId),
      oldPrice: Value(oldPrice),
      newPrice: Value(newPrice),
      changedAt: Value(changedAt),
      changedByName: Value(changedByName),
    );
  }

  factory PriceHistoryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PriceHistoryRow(
      id: serializer.fromJson<String>(json['id']),
      itemId: serializer.fromJson<String>(json['itemId']),
      supplierId: serializer.fromJson<String>(json['supplierId']),
      oldPrice: serializer.fromJson<double>(json['oldPrice']),
      newPrice: serializer.fromJson<double>(json['newPrice']),
      changedAt: serializer.fromJson<DateTime>(json['changedAt']),
      changedByName: serializer.fromJson<String>(json['changedByName']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'itemId': serializer.toJson<String>(itemId),
      'supplierId': serializer.toJson<String>(supplierId),
      'oldPrice': serializer.toJson<double>(oldPrice),
      'newPrice': serializer.toJson<double>(newPrice),
      'changedAt': serializer.toJson<DateTime>(changedAt),
      'changedByName': serializer.toJson<String>(changedByName),
    };
  }

  PriceHistoryRow copyWith({
    String? id,
    String? itemId,
    String? supplierId,
    double? oldPrice,
    double? newPrice,
    DateTime? changedAt,
    String? changedByName,
  }) => PriceHistoryRow(
    id: id ?? this.id,
    itemId: itemId ?? this.itemId,
    supplierId: supplierId ?? this.supplierId,
    oldPrice: oldPrice ?? this.oldPrice,
    newPrice: newPrice ?? this.newPrice,
    changedAt: changedAt ?? this.changedAt,
    changedByName: changedByName ?? this.changedByName,
  );
  PriceHistoryRow copyWithCompanion(PriceHistoryCompanion data) {
    return PriceHistoryRow(
      id: data.id.present ? data.id.value : this.id,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      supplierId: data.supplierId.present
          ? data.supplierId.value
          : this.supplierId,
      oldPrice: data.oldPrice.present ? data.oldPrice.value : this.oldPrice,
      newPrice: data.newPrice.present ? data.newPrice.value : this.newPrice,
      changedAt: data.changedAt.present ? data.changedAt.value : this.changedAt,
      changedByName: data.changedByName.present
          ? data.changedByName.value
          : this.changedByName,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PriceHistoryRow(')
          ..write('id: $id, ')
          ..write('itemId: $itemId, ')
          ..write('supplierId: $supplierId, ')
          ..write('oldPrice: $oldPrice, ')
          ..write('newPrice: $newPrice, ')
          ..write('changedAt: $changedAt, ')
          ..write('changedByName: $changedByName')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    itemId,
    supplierId,
    oldPrice,
    newPrice,
    changedAt,
    changedByName,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PriceHistoryRow &&
          other.id == this.id &&
          other.itemId == this.itemId &&
          other.supplierId == this.supplierId &&
          other.oldPrice == this.oldPrice &&
          other.newPrice == this.newPrice &&
          other.changedAt == this.changedAt &&
          other.changedByName == this.changedByName);
}

class PriceHistoryCompanion extends UpdateCompanion<PriceHistoryRow> {
  final Value<String> id;
  final Value<String> itemId;
  final Value<String> supplierId;
  final Value<double> oldPrice;
  final Value<double> newPrice;
  final Value<DateTime> changedAt;
  final Value<String> changedByName;
  final Value<int> rowid;
  const PriceHistoryCompanion({
    this.id = const Value.absent(),
    this.itemId = const Value.absent(),
    this.supplierId = const Value.absent(),
    this.oldPrice = const Value.absent(),
    this.newPrice = const Value.absent(),
    this.changedAt = const Value.absent(),
    this.changedByName = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PriceHistoryCompanion.insert({
    required String id,
    required String itemId,
    required String supplierId,
    required double oldPrice,
    required double newPrice,
    required DateTime changedAt,
    required String changedByName,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       itemId = Value(itemId),
       supplierId = Value(supplierId),
       oldPrice = Value(oldPrice),
       newPrice = Value(newPrice),
       changedAt = Value(changedAt),
       changedByName = Value(changedByName);
  static Insertable<PriceHistoryRow> custom({
    Expression<String>? id,
    Expression<String>? itemId,
    Expression<String>? supplierId,
    Expression<double>? oldPrice,
    Expression<double>? newPrice,
    Expression<DateTime>? changedAt,
    Expression<String>? changedByName,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (itemId != null) 'item_id': itemId,
      if (supplierId != null) 'supplier_id': supplierId,
      if (oldPrice != null) 'old_price': oldPrice,
      if (newPrice != null) 'new_price': newPrice,
      if (changedAt != null) 'changed_at': changedAt,
      if (changedByName != null) 'changed_by_name': changedByName,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PriceHistoryCompanion copyWith({
    Value<String>? id,
    Value<String>? itemId,
    Value<String>? supplierId,
    Value<double>? oldPrice,
    Value<double>? newPrice,
    Value<DateTime>? changedAt,
    Value<String>? changedByName,
    Value<int>? rowid,
  }) {
    return PriceHistoryCompanion(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      supplierId: supplierId ?? this.supplierId,
      oldPrice: oldPrice ?? this.oldPrice,
      newPrice: newPrice ?? this.newPrice,
      changedAt: changedAt ?? this.changedAt,
      changedByName: changedByName ?? this.changedByName,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (supplierId.present) {
      map['supplier_id'] = Variable<String>(supplierId.value);
    }
    if (oldPrice.present) {
      map['old_price'] = Variable<double>(oldPrice.value);
    }
    if (newPrice.present) {
      map['new_price'] = Variable<double>(newPrice.value);
    }
    if (changedAt.present) {
      map['changed_at'] = Variable<DateTime>(changedAt.value);
    }
    if (changedByName.present) {
      map['changed_by_name'] = Variable<String>(changedByName.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PriceHistoryCompanion(')
          ..write('id: $id, ')
          ..write('itemId: $itemId, ')
          ..write('supplierId: $supplierId, ')
          ..write('oldPrice: $oldPrice, ')
          ..write('newPrice: $newPrice, ')
          ..write('changedAt: $changedAt, ')
          ..write('changedByName: $changedByName, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StockMovementsTable extends StockMovements
    with TableInfo<$StockMovementsTable, StockMovementRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StockMovementsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 64,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _storeIdMeta = const VerificationMeta(
    'storeId',
  );
  @override
  late final GeneratedColumn<String> storeId = GeneratedColumn<String>(
    'store_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES stores (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES items (id) ON DELETE CASCADE',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<StockMovementType, String> type =
      GeneratedColumn<String>(
        'type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<StockMovementType>($StockMovementsTable.$convertertype);
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<double> quantity = GeneratedColumn<double>(
    'quantity',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<DateTime> occurredAt = GeneratedColumn<DateTime>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userNameMeta = const VerificationMeta(
    'userName',
  );
  @override
  late final GeneratedColumn<String> userName = GeneratedColumn<String>(
    'user_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _supplierIdMeta = const VerificationMeta(
    'supplierId',
  );
  @override
  late final GeneratedColumn<String> supplierId = GeneratedColumn<String>(
    'supplier_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _unitPriceMeta = const VerificationMeta(
    'unitPrice',
  );
  @override
  late final GeneratedColumn<double> unitPrice = GeneratedColumn<double>(
    'unit_price',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<StockOutReason?, String> reason =
      GeneratedColumn<String>(
        'reason',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<StockOutReason?>($StockMovementsTable.$converterreasonn);
  static const VerificationMeta _systemQuantityMeta = const VerificationMeta(
    'systemQuantity',
  );
  @override
  late final GeneratedColumn<double> systemQuantity = GeneratedColumn<double>(
    'system_quantity',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _countedQuantityMeta = const VerificationMeta(
    'countedQuantity',
  );
  @override
  late final GeneratedColumn<double> countedQuantity = GeneratedColumn<double>(
    'counted_quantity',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _unitCostMeta = const VerificationMeta(
    'unitCost',
  );
  @override
  late final GeneratedColumn<double> unitCost = GeneratedColumn<double>(
    'unit_cost',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _averageCostAfterMeta = const VerificationMeta(
    'averageCostAfter',
  );
  @override
  late final GeneratedColumn<double> averageCostAfter = GeneratedColumn<double>(
    'average_cost_after',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _orderIdMeta = const VerificationMeta(
    'orderId',
  );
  @override
  late final GeneratedColumn<String> orderId = GeneratedColumn<String>(
    'order_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _receiptIdMeta = const VerificationMeta(
    'receiptId',
  );
  @override
  late final GeneratedColumn<String> receiptId = GeneratedColumn<String>(
    'receipt_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    storeId,
    itemId,
    type,
    quantity,
    occurredAt,
    userName,
    supplierId,
    unitPrice,
    reason,
    systemQuantity,
    countedQuantity,
    unitCost,
    averageCostAfter,
    orderId,
    receiptId,
    note,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stock_movements';
  @override
  VerificationContext validateIntegrity(
    Insertable<StockMovementRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('store_id')) {
      context.handle(
        _storeIdMeta,
        storeId.isAcceptableOrUnknown(data['store_id']!, _storeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_storeIdMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    } else if (isInserting) {
      context.missing(_quantityMeta);
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('user_name')) {
      context.handle(
        _userNameMeta,
        userName.isAcceptableOrUnknown(data['user_name']!, _userNameMeta),
      );
    } else if (isInserting) {
      context.missing(_userNameMeta);
    }
    if (data.containsKey('supplier_id')) {
      context.handle(
        _supplierIdMeta,
        supplierId.isAcceptableOrUnknown(data['supplier_id']!, _supplierIdMeta),
      );
    }
    if (data.containsKey('unit_price')) {
      context.handle(
        _unitPriceMeta,
        unitPrice.isAcceptableOrUnknown(data['unit_price']!, _unitPriceMeta),
      );
    }
    if (data.containsKey('system_quantity')) {
      context.handle(
        _systemQuantityMeta,
        systemQuantity.isAcceptableOrUnknown(
          data['system_quantity']!,
          _systemQuantityMeta,
        ),
      );
    }
    if (data.containsKey('counted_quantity')) {
      context.handle(
        _countedQuantityMeta,
        countedQuantity.isAcceptableOrUnknown(
          data['counted_quantity']!,
          _countedQuantityMeta,
        ),
      );
    }
    if (data.containsKey('unit_cost')) {
      context.handle(
        _unitCostMeta,
        unitCost.isAcceptableOrUnknown(data['unit_cost']!, _unitCostMeta),
      );
    }
    if (data.containsKey('average_cost_after')) {
      context.handle(
        _averageCostAfterMeta,
        averageCostAfter.isAcceptableOrUnknown(
          data['average_cost_after']!,
          _averageCostAfterMeta,
        ),
      );
    }
    if (data.containsKey('order_id')) {
      context.handle(
        _orderIdMeta,
        orderId.isAcceptableOrUnknown(data['order_id']!, _orderIdMeta),
      );
    }
    if (data.containsKey('receipt_id')) {
      context.handle(
        _receiptIdMeta,
        receiptId.isAcceptableOrUnknown(data['receipt_id']!, _receiptIdMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StockMovementRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StockMovementRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      storeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}store_id'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      type: $StockMovementsTable.$convertertype.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}type'],
        )!,
      ),
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}quantity'],
      )!,
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}occurred_at'],
      )!,
      userName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_name'],
      )!,
      supplierId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}supplier_id'],
      ),
      unitPrice: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}unit_price'],
      ),
      reason: $StockMovementsTable.$converterreasonn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}reason'],
        ),
      ),
      systemQuantity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}system_quantity'],
      ),
      countedQuantity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}counted_quantity'],
      ),
      unitCost: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}unit_cost'],
      ),
      averageCostAfter: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}average_cost_after'],
      ),
      orderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}order_id'],
      ),
      receiptId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}receipt_id'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
    );
  }

  @override
  $StockMovementsTable createAlias(String alias) {
    return $StockMovementsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<StockMovementType, String, String> $convertertype =
      const EnumNameConverter<StockMovementType>(StockMovementType.values);
  static JsonTypeConverter2<StockOutReason, String, String> $converterreason =
      const EnumNameConverter<StockOutReason>(StockOutReason.values);
  static JsonTypeConverter2<StockOutReason?, String?, String?>
  $converterreasonn = JsonTypeConverter2.asNullable($converterreason);
}

class StockMovementRow extends DataClass
    implements Insertable<StockMovementRow> {
  final String id;
  final String storeId;

  /// Cascades. Deleting an article is an explicit, confirmed act that states
  /// its own counts, and leaving movements pointing at an article that no longer
  /// exists would render them as "—" with no way to work out what they said.
  final String itemId;
  final StockMovementType type;

  /// Signed: positive in, negative out, and for an adjustment the difference
  /// between what was counted and what the system thought.
  final double quantity;
  final DateTime occurredAt;

  /// The name, not the id — see `price_history.changedByName`.
  final String userName;

  /// **No foreign key, on purpose.** Deleting a supplier keeps the movements
  /// that name them: a movement records goods that really moved, and the
  /// supplier going away does not unmake that. The row keeps their id and the
  /// screen renders "Fournisseur supprimé", which is true. `ON DELETE SET NULL`
  /// would erase the id and quietly make the past tidier than it was.
  final String? supplierId;

  /// What was paid per unit on this delivery, when it is known.
  final double? unitPrice;

  /// Only meaningful on a stock-out.
  final StockOutReason? reason;

  /// Only meaningful on an adjustment: what the system said, and what the count
  /// actually found.
  final double? systemQuantity;
  final double? countedQuantity;

  /// The cost this movement applied, and the weighted average it produced.
  ///
  /// Stamped at the time and never recomputed. Together they are what makes the
  /// average auditable — every step of it can be read back off the log.
  final double? unitCost;
  final double? averageCostAfter;

  /// Back-references to the delivery that caused this movement. No foreign
  /// keys: like [supplierId] these are historical pointers, and a movement that
  /// outlives what it points at is still a true record of goods that moved.
  final String? orderId;
  final String? receiptId;
  final String? note;
  const StockMovementRow({
    required this.id,
    required this.storeId,
    required this.itemId,
    required this.type,
    required this.quantity,
    required this.occurredAt,
    required this.userName,
    this.supplierId,
    this.unitPrice,
    this.reason,
    this.systemQuantity,
    this.countedQuantity,
    this.unitCost,
    this.averageCostAfter,
    this.orderId,
    this.receiptId,
    this.note,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['store_id'] = Variable<String>(storeId);
    map['item_id'] = Variable<String>(itemId);
    {
      map['type'] = Variable<String>(
        $StockMovementsTable.$convertertype.toSql(type),
      );
    }
    map['quantity'] = Variable<double>(quantity);
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    map['user_name'] = Variable<String>(userName);
    if (!nullToAbsent || supplierId != null) {
      map['supplier_id'] = Variable<String>(supplierId);
    }
    if (!nullToAbsent || unitPrice != null) {
      map['unit_price'] = Variable<double>(unitPrice);
    }
    if (!nullToAbsent || reason != null) {
      map['reason'] = Variable<String>(
        $StockMovementsTable.$converterreasonn.toSql(reason),
      );
    }
    if (!nullToAbsent || systemQuantity != null) {
      map['system_quantity'] = Variable<double>(systemQuantity);
    }
    if (!nullToAbsent || countedQuantity != null) {
      map['counted_quantity'] = Variable<double>(countedQuantity);
    }
    if (!nullToAbsent || unitCost != null) {
      map['unit_cost'] = Variable<double>(unitCost);
    }
    if (!nullToAbsent || averageCostAfter != null) {
      map['average_cost_after'] = Variable<double>(averageCostAfter);
    }
    if (!nullToAbsent || orderId != null) {
      map['order_id'] = Variable<String>(orderId);
    }
    if (!nullToAbsent || receiptId != null) {
      map['receipt_id'] = Variable<String>(receiptId);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    return map;
  }

  StockMovementsCompanion toCompanion(bool nullToAbsent) {
    return StockMovementsCompanion(
      id: Value(id),
      storeId: Value(storeId),
      itemId: Value(itemId),
      type: Value(type),
      quantity: Value(quantity),
      occurredAt: Value(occurredAt),
      userName: Value(userName),
      supplierId: supplierId == null && nullToAbsent
          ? const Value.absent()
          : Value(supplierId),
      unitPrice: unitPrice == null && nullToAbsent
          ? const Value.absent()
          : Value(unitPrice),
      reason: reason == null && nullToAbsent
          ? const Value.absent()
          : Value(reason),
      systemQuantity: systemQuantity == null && nullToAbsent
          ? const Value.absent()
          : Value(systemQuantity),
      countedQuantity: countedQuantity == null && nullToAbsent
          ? const Value.absent()
          : Value(countedQuantity),
      unitCost: unitCost == null && nullToAbsent
          ? const Value.absent()
          : Value(unitCost),
      averageCostAfter: averageCostAfter == null && nullToAbsent
          ? const Value.absent()
          : Value(averageCostAfter),
      orderId: orderId == null && nullToAbsent
          ? const Value.absent()
          : Value(orderId),
      receiptId: receiptId == null && nullToAbsent
          ? const Value.absent()
          : Value(receiptId),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
    );
  }

  factory StockMovementRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StockMovementRow(
      id: serializer.fromJson<String>(json['id']),
      storeId: serializer.fromJson<String>(json['storeId']),
      itemId: serializer.fromJson<String>(json['itemId']),
      type: $StockMovementsTable.$convertertype.fromJson(
        serializer.fromJson<String>(json['type']),
      ),
      quantity: serializer.fromJson<double>(json['quantity']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
      userName: serializer.fromJson<String>(json['userName']),
      supplierId: serializer.fromJson<String?>(json['supplierId']),
      unitPrice: serializer.fromJson<double?>(json['unitPrice']),
      reason: $StockMovementsTable.$converterreasonn.fromJson(
        serializer.fromJson<String?>(json['reason']),
      ),
      systemQuantity: serializer.fromJson<double?>(json['systemQuantity']),
      countedQuantity: serializer.fromJson<double?>(json['countedQuantity']),
      unitCost: serializer.fromJson<double?>(json['unitCost']),
      averageCostAfter: serializer.fromJson<double?>(json['averageCostAfter']),
      orderId: serializer.fromJson<String?>(json['orderId']),
      receiptId: serializer.fromJson<String?>(json['receiptId']),
      note: serializer.fromJson<String?>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'storeId': serializer.toJson<String>(storeId),
      'itemId': serializer.toJson<String>(itemId),
      'type': serializer.toJson<String>(
        $StockMovementsTable.$convertertype.toJson(type),
      ),
      'quantity': serializer.toJson<double>(quantity),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
      'userName': serializer.toJson<String>(userName),
      'supplierId': serializer.toJson<String?>(supplierId),
      'unitPrice': serializer.toJson<double?>(unitPrice),
      'reason': serializer.toJson<String?>(
        $StockMovementsTable.$converterreasonn.toJson(reason),
      ),
      'systemQuantity': serializer.toJson<double?>(systemQuantity),
      'countedQuantity': serializer.toJson<double?>(countedQuantity),
      'unitCost': serializer.toJson<double?>(unitCost),
      'averageCostAfter': serializer.toJson<double?>(averageCostAfter),
      'orderId': serializer.toJson<String?>(orderId),
      'receiptId': serializer.toJson<String?>(receiptId),
      'note': serializer.toJson<String?>(note),
    };
  }

  StockMovementRow copyWith({
    String? id,
    String? storeId,
    String? itemId,
    StockMovementType? type,
    double? quantity,
    DateTime? occurredAt,
    String? userName,
    Value<String?> supplierId = const Value.absent(),
    Value<double?> unitPrice = const Value.absent(),
    Value<StockOutReason?> reason = const Value.absent(),
    Value<double?> systemQuantity = const Value.absent(),
    Value<double?> countedQuantity = const Value.absent(),
    Value<double?> unitCost = const Value.absent(),
    Value<double?> averageCostAfter = const Value.absent(),
    Value<String?> orderId = const Value.absent(),
    Value<String?> receiptId = const Value.absent(),
    Value<String?> note = const Value.absent(),
  }) => StockMovementRow(
    id: id ?? this.id,
    storeId: storeId ?? this.storeId,
    itemId: itemId ?? this.itemId,
    type: type ?? this.type,
    quantity: quantity ?? this.quantity,
    occurredAt: occurredAt ?? this.occurredAt,
    userName: userName ?? this.userName,
    supplierId: supplierId.present ? supplierId.value : this.supplierId,
    unitPrice: unitPrice.present ? unitPrice.value : this.unitPrice,
    reason: reason.present ? reason.value : this.reason,
    systemQuantity: systemQuantity.present
        ? systemQuantity.value
        : this.systemQuantity,
    countedQuantity: countedQuantity.present
        ? countedQuantity.value
        : this.countedQuantity,
    unitCost: unitCost.present ? unitCost.value : this.unitCost,
    averageCostAfter: averageCostAfter.present
        ? averageCostAfter.value
        : this.averageCostAfter,
    orderId: orderId.present ? orderId.value : this.orderId,
    receiptId: receiptId.present ? receiptId.value : this.receiptId,
    note: note.present ? note.value : this.note,
  );
  StockMovementRow copyWithCompanion(StockMovementsCompanion data) {
    return StockMovementRow(
      id: data.id.present ? data.id.value : this.id,
      storeId: data.storeId.present ? data.storeId.value : this.storeId,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      type: data.type.present ? data.type.value : this.type,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      userName: data.userName.present ? data.userName.value : this.userName,
      supplierId: data.supplierId.present
          ? data.supplierId.value
          : this.supplierId,
      unitPrice: data.unitPrice.present ? data.unitPrice.value : this.unitPrice,
      reason: data.reason.present ? data.reason.value : this.reason,
      systemQuantity: data.systemQuantity.present
          ? data.systemQuantity.value
          : this.systemQuantity,
      countedQuantity: data.countedQuantity.present
          ? data.countedQuantity.value
          : this.countedQuantity,
      unitCost: data.unitCost.present ? data.unitCost.value : this.unitCost,
      averageCostAfter: data.averageCostAfter.present
          ? data.averageCostAfter.value
          : this.averageCostAfter,
      orderId: data.orderId.present ? data.orderId.value : this.orderId,
      receiptId: data.receiptId.present ? data.receiptId.value : this.receiptId,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StockMovementRow(')
          ..write('id: $id, ')
          ..write('storeId: $storeId, ')
          ..write('itemId: $itemId, ')
          ..write('type: $type, ')
          ..write('quantity: $quantity, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('userName: $userName, ')
          ..write('supplierId: $supplierId, ')
          ..write('unitPrice: $unitPrice, ')
          ..write('reason: $reason, ')
          ..write('systemQuantity: $systemQuantity, ')
          ..write('countedQuantity: $countedQuantity, ')
          ..write('unitCost: $unitCost, ')
          ..write('averageCostAfter: $averageCostAfter, ')
          ..write('orderId: $orderId, ')
          ..write('receiptId: $receiptId, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    storeId,
    itemId,
    type,
    quantity,
    occurredAt,
    userName,
    supplierId,
    unitPrice,
    reason,
    systemQuantity,
    countedQuantity,
    unitCost,
    averageCostAfter,
    orderId,
    receiptId,
    note,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StockMovementRow &&
          other.id == this.id &&
          other.storeId == this.storeId &&
          other.itemId == this.itemId &&
          other.type == this.type &&
          other.quantity == this.quantity &&
          other.occurredAt == this.occurredAt &&
          other.userName == this.userName &&
          other.supplierId == this.supplierId &&
          other.unitPrice == this.unitPrice &&
          other.reason == this.reason &&
          other.systemQuantity == this.systemQuantity &&
          other.countedQuantity == this.countedQuantity &&
          other.unitCost == this.unitCost &&
          other.averageCostAfter == this.averageCostAfter &&
          other.orderId == this.orderId &&
          other.receiptId == this.receiptId &&
          other.note == this.note);
}

class StockMovementsCompanion extends UpdateCompanion<StockMovementRow> {
  final Value<String> id;
  final Value<String> storeId;
  final Value<String> itemId;
  final Value<StockMovementType> type;
  final Value<double> quantity;
  final Value<DateTime> occurredAt;
  final Value<String> userName;
  final Value<String?> supplierId;
  final Value<double?> unitPrice;
  final Value<StockOutReason?> reason;
  final Value<double?> systemQuantity;
  final Value<double?> countedQuantity;
  final Value<double?> unitCost;
  final Value<double?> averageCostAfter;
  final Value<String?> orderId;
  final Value<String?> receiptId;
  final Value<String?> note;
  final Value<int> rowid;
  const StockMovementsCompanion({
    this.id = const Value.absent(),
    this.storeId = const Value.absent(),
    this.itemId = const Value.absent(),
    this.type = const Value.absent(),
    this.quantity = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.userName = const Value.absent(),
    this.supplierId = const Value.absent(),
    this.unitPrice = const Value.absent(),
    this.reason = const Value.absent(),
    this.systemQuantity = const Value.absent(),
    this.countedQuantity = const Value.absent(),
    this.unitCost = const Value.absent(),
    this.averageCostAfter = const Value.absent(),
    this.orderId = const Value.absent(),
    this.receiptId = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StockMovementsCompanion.insert({
    required String id,
    required String storeId,
    required String itemId,
    required StockMovementType type,
    required double quantity,
    required DateTime occurredAt,
    required String userName,
    this.supplierId = const Value.absent(),
    this.unitPrice = const Value.absent(),
    this.reason = const Value.absent(),
    this.systemQuantity = const Value.absent(),
    this.countedQuantity = const Value.absent(),
    this.unitCost = const Value.absent(),
    this.averageCostAfter = const Value.absent(),
    this.orderId = const Value.absent(),
    this.receiptId = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       storeId = Value(storeId),
       itemId = Value(itemId),
       type = Value(type),
       quantity = Value(quantity),
       occurredAt = Value(occurredAt),
       userName = Value(userName);
  static Insertable<StockMovementRow> custom({
    Expression<String>? id,
    Expression<String>? storeId,
    Expression<String>? itemId,
    Expression<String>? type,
    Expression<double>? quantity,
    Expression<DateTime>? occurredAt,
    Expression<String>? userName,
    Expression<String>? supplierId,
    Expression<double>? unitPrice,
    Expression<String>? reason,
    Expression<double>? systemQuantity,
    Expression<double>? countedQuantity,
    Expression<double>? unitCost,
    Expression<double>? averageCostAfter,
    Expression<String>? orderId,
    Expression<String>? receiptId,
    Expression<String>? note,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (storeId != null) 'store_id': storeId,
      if (itemId != null) 'item_id': itemId,
      if (type != null) 'type': type,
      if (quantity != null) 'quantity': quantity,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (userName != null) 'user_name': userName,
      if (supplierId != null) 'supplier_id': supplierId,
      if (unitPrice != null) 'unit_price': unitPrice,
      if (reason != null) 'reason': reason,
      if (systemQuantity != null) 'system_quantity': systemQuantity,
      if (countedQuantity != null) 'counted_quantity': countedQuantity,
      if (unitCost != null) 'unit_cost': unitCost,
      if (averageCostAfter != null) 'average_cost_after': averageCostAfter,
      if (orderId != null) 'order_id': orderId,
      if (receiptId != null) 'receipt_id': receiptId,
      if (note != null) 'note': note,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StockMovementsCompanion copyWith({
    Value<String>? id,
    Value<String>? storeId,
    Value<String>? itemId,
    Value<StockMovementType>? type,
    Value<double>? quantity,
    Value<DateTime>? occurredAt,
    Value<String>? userName,
    Value<String?>? supplierId,
    Value<double?>? unitPrice,
    Value<StockOutReason?>? reason,
    Value<double?>? systemQuantity,
    Value<double?>? countedQuantity,
    Value<double?>? unitCost,
    Value<double?>? averageCostAfter,
    Value<String?>? orderId,
    Value<String?>? receiptId,
    Value<String?>? note,
    Value<int>? rowid,
  }) {
    return StockMovementsCompanion(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      itemId: itemId ?? this.itemId,
      type: type ?? this.type,
      quantity: quantity ?? this.quantity,
      occurredAt: occurredAt ?? this.occurredAt,
      userName: userName ?? this.userName,
      supplierId: supplierId ?? this.supplierId,
      unitPrice: unitPrice ?? this.unitPrice,
      reason: reason ?? this.reason,
      systemQuantity: systemQuantity ?? this.systemQuantity,
      countedQuantity: countedQuantity ?? this.countedQuantity,
      unitCost: unitCost ?? this.unitCost,
      averageCostAfter: averageCostAfter ?? this.averageCostAfter,
      orderId: orderId ?? this.orderId,
      receiptId: receiptId ?? this.receiptId,
      note: note ?? this.note,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (storeId.present) {
      map['store_id'] = Variable<String>(storeId.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(
        $StockMovementsTable.$convertertype.toSql(type.value),
      );
    }
    if (quantity.present) {
      map['quantity'] = Variable<double>(quantity.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    if (userName.present) {
      map['user_name'] = Variable<String>(userName.value);
    }
    if (supplierId.present) {
      map['supplier_id'] = Variable<String>(supplierId.value);
    }
    if (unitPrice.present) {
      map['unit_price'] = Variable<double>(unitPrice.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(
        $StockMovementsTable.$converterreasonn.toSql(reason.value),
      );
    }
    if (systemQuantity.present) {
      map['system_quantity'] = Variable<double>(systemQuantity.value);
    }
    if (countedQuantity.present) {
      map['counted_quantity'] = Variable<double>(countedQuantity.value);
    }
    if (unitCost.present) {
      map['unit_cost'] = Variable<double>(unitCost.value);
    }
    if (averageCostAfter.present) {
      map['average_cost_after'] = Variable<double>(averageCostAfter.value);
    }
    if (orderId.present) {
      map['order_id'] = Variable<String>(orderId.value);
    }
    if (receiptId.present) {
      map['receipt_id'] = Variable<String>(receiptId.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StockMovementsCompanion(')
          ..write('id: $id, ')
          ..write('storeId: $storeId, ')
          ..write('itemId: $itemId, ')
          ..write('type: $type, ')
          ..write('quantity: $quantity, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('userName: $userName, ')
          ..write('supplierId: $supplierId, ')
          ..write('unitPrice: $unitPrice, ')
          ..write('reason: $reason, ')
          ..write('systemQuantity: $systemQuantity, ')
          ..write('countedQuantity: $countedQuantity, ')
          ..write('unitCost: $unitCost, ')
          ..write('averageCostAfter: $averageCostAfter, ')
          ..write('orderId: $orderId, ')
          ..write('receiptId: $receiptId, ')
          ..write('note: $note, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PurchaseOrdersTable extends PurchaseOrders
    with TableInfo<$PurchaseOrdersTable, PurchaseOrderRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PurchaseOrdersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 64,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _storeIdMeta = const VerificationMeta(
    'storeId',
  );
  @override
  late final GeneratedColumn<String> storeId = GeneratedColumn<String>(
    'store_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES stores (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _supplierIdMeta = const VerificationMeta(
    'supplierId',
  );
  @override
  late final GeneratedColumn<String> supplierId = GeneratedColumn<String>(
    'supplier_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _referenceMeta = const VerificationMeta(
    'reference',
  );
  @override
  late final GeneratedColumn<String> reference = GeneratedColumn<String>(
    'reference',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<PurchaseOrderStatus, String>
  status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<PurchaseOrderStatus>($PurchaseOrdersTable.$converterstatus);
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
  static const VerificationMeta _sentAtMeta = const VerificationMeta('sentAt');
  @override
  late final GeneratedColumn<DateTime> sentAt = GeneratedColumn<DateTime>(
    'sent_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _closedAtMeta = const VerificationMeta(
    'closedAt',
  );
  @override
  late final GeneratedColumn<DateTime> closedAt = GeneratedColumn<DateTime>(
    'closed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    storeId,
    supplierId,
    reference,
    status,
    createdAt,
    sentAt,
    closedAt,
    note,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'purchase_orders';
  @override
  VerificationContext validateIntegrity(
    Insertable<PurchaseOrderRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('store_id')) {
      context.handle(
        _storeIdMeta,
        storeId.isAcceptableOrUnknown(data['store_id']!, _storeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_storeIdMeta);
    }
    if (data.containsKey('supplier_id')) {
      context.handle(
        _supplierIdMeta,
        supplierId.isAcceptableOrUnknown(data['supplier_id']!, _supplierIdMeta),
      );
    } else if (isInserting) {
      context.missing(_supplierIdMeta);
    }
    if (data.containsKey('reference')) {
      context.handle(
        _referenceMeta,
        reference.isAcceptableOrUnknown(data['reference']!, _referenceMeta),
      );
    } else if (isInserting) {
      context.missing(_referenceMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('sent_at')) {
      context.handle(
        _sentAtMeta,
        sentAt.isAcceptableOrUnknown(data['sent_at']!, _sentAtMeta),
      );
    }
    if (data.containsKey('closed_at')) {
      context.handle(
        _closedAtMeta,
        closedAt.isAcceptableOrUnknown(data['closed_at']!, _closedAtMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PurchaseOrderRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PurchaseOrderRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      storeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}store_id'],
      )!,
      supplierId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}supplier_id'],
      )!,
      reference: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reference'],
      )!,
      status: $PurchaseOrdersTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      sentAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}sent_at'],
      ),
      closedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}closed_at'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
    );
  }

  @override
  $PurchaseOrdersTable createAlias(String alias) {
    return $PurchaseOrdersTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<PurchaseOrderStatus, String, String>
  $converterstatus = const EnumNameConverter<PurchaseOrderStatus>(
    PurchaseOrderStatus.values,
  );
}

class PurchaseOrderRow extends DataClass
    implements Insertable<PurchaseOrderRow> {
  final String id;
  final String storeId;

  /// **No foreign key, on purpose.** A supplier can be deleted once they have
  /// no open order, and their closed orders are kept — the order history is how
  /// an owner sees who they used to buy from. Cascading would delete that
  /// history; restricting would forbid ever removing a supplier once used.
  final String supplierId;

  /// `CMD-2026-017`. Account-global rather than per store, which is what Phase 1
  /// did — the `storeId` argument to the old `_nextReference` was accepted and
  /// ignored. Preserved deliberately: renumbering would rewrite the demo.
  final String reference;
  final PurchaseOrderStatus status;
  final DateTime createdAt;
  final DateTime? sentAt;
  final DateTime? closedAt;
  final String? note;
  const PurchaseOrderRow({
    required this.id,
    required this.storeId,
    required this.supplierId,
    required this.reference,
    required this.status,
    required this.createdAt,
    this.sentAt,
    this.closedAt,
    this.note,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['store_id'] = Variable<String>(storeId);
    map['supplier_id'] = Variable<String>(supplierId);
    map['reference'] = Variable<String>(reference);
    {
      map['status'] = Variable<String>(
        $PurchaseOrdersTable.$converterstatus.toSql(status),
      );
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || sentAt != null) {
      map['sent_at'] = Variable<DateTime>(sentAt);
    }
    if (!nullToAbsent || closedAt != null) {
      map['closed_at'] = Variable<DateTime>(closedAt);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    return map;
  }

  PurchaseOrdersCompanion toCompanion(bool nullToAbsent) {
    return PurchaseOrdersCompanion(
      id: Value(id),
      storeId: Value(storeId),
      supplierId: Value(supplierId),
      reference: Value(reference),
      status: Value(status),
      createdAt: Value(createdAt),
      sentAt: sentAt == null && nullToAbsent
          ? const Value.absent()
          : Value(sentAt),
      closedAt: closedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(closedAt),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
    );
  }

  factory PurchaseOrderRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PurchaseOrderRow(
      id: serializer.fromJson<String>(json['id']),
      storeId: serializer.fromJson<String>(json['storeId']),
      supplierId: serializer.fromJson<String>(json['supplierId']),
      reference: serializer.fromJson<String>(json['reference']),
      status: $PurchaseOrdersTable.$converterstatus.fromJson(
        serializer.fromJson<String>(json['status']),
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      sentAt: serializer.fromJson<DateTime?>(json['sentAt']),
      closedAt: serializer.fromJson<DateTime?>(json['closedAt']),
      note: serializer.fromJson<String?>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'storeId': serializer.toJson<String>(storeId),
      'supplierId': serializer.toJson<String>(supplierId),
      'reference': serializer.toJson<String>(reference),
      'status': serializer.toJson<String>(
        $PurchaseOrdersTable.$converterstatus.toJson(status),
      ),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'sentAt': serializer.toJson<DateTime?>(sentAt),
      'closedAt': serializer.toJson<DateTime?>(closedAt),
      'note': serializer.toJson<String?>(note),
    };
  }

  PurchaseOrderRow copyWith({
    String? id,
    String? storeId,
    String? supplierId,
    String? reference,
    PurchaseOrderStatus? status,
    DateTime? createdAt,
    Value<DateTime?> sentAt = const Value.absent(),
    Value<DateTime?> closedAt = const Value.absent(),
    Value<String?> note = const Value.absent(),
  }) => PurchaseOrderRow(
    id: id ?? this.id,
    storeId: storeId ?? this.storeId,
    supplierId: supplierId ?? this.supplierId,
    reference: reference ?? this.reference,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    sentAt: sentAt.present ? sentAt.value : this.sentAt,
    closedAt: closedAt.present ? closedAt.value : this.closedAt,
    note: note.present ? note.value : this.note,
  );
  PurchaseOrderRow copyWithCompanion(PurchaseOrdersCompanion data) {
    return PurchaseOrderRow(
      id: data.id.present ? data.id.value : this.id,
      storeId: data.storeId.present ? data.storeId.value : this.storeId,
      supplierId: data.supplierId.present
          ? data.supplierId.value
          : this.supplierId,
      reference: data.reference.present ? data.reference.value : this.reference,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      sentAt: data.sentAt.present ? data.sentAt.value : this.sentAt,
      closedAt: data.closedAt.present ? data.closedAt.value : this.closedAt,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PurchaseOrderRow(')
          ..write('id: $id, ')
          ..write('storeId: $storeId, ')
          ..write('supplierId: $supplierId, ')
          ..write('reference: $reference, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('sentAt: $sentAt, ')
          ..write('closedAt: $closedAt, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    storeId,
    supplierId,
    reference,
    status,
    createdAt,
    sentAt,
    closedAt,
    note,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PurchaseOrderRow &&
          other.id == this.id &&
          other.storeId == this.storeId &&
          other.supplierId == this.supplierId &&
          other.reference == this.reference &&
          other.status == this.status &&
          other.createdAt == this.createdAt &&
          other.sentAt == this.sentAt &&
          other.closedAt == this.closedAt &&
          other.note == this.note);
}

class PurchaseOrdersCompanion extends UpdateCompanion<PurchaseOrderRow> {
  final Value<String> id;
  final Value<String> storeId;
  final Value<String> supplierId;
  final Value<String> reference;
  final Value<PurchaseOrderStatus> status;
  final Value<DateTime> createdAt;
  final Value<DateTime?> sentAt;
  final Value<DateTime?> closedAt;
  final Value<String?> note;
  final Value<int> rowid;
  const PurchaseOrdersCompanion({
    this.id = const Value.absent(),
    this.storeId = const Value.absent(),
    this.supplierId = const Value.absent(),
    this.reference = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.sentAt = const Value.absent(),
    this.closedAt = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PurchaseOrdersCompanion.insert({
    required String id,
    required String storeId,
    required String supplierId,
    required String reference,
    required PurchaseOrderStatus status,
    required DateTime createdAt,
    this.sentAt = const Value.absent(),
    this.closedAt = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       storeId = Value(storeId),
       supplierId = Value(supplierId),
       reference = Value(reference),
       status = Value(status),
       createdAt = Value(createdAt);
  static Insertable<PurchaseOrderRow> custom({
    Expression<String>? id,
    Expression<String>? storeId,
    Expression<String>? supplierId,
    Expression<String>? reference,
    Expression<String>? status,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? sentAt,
    Expression<DateTime>? closedAt,
    Expression<String>? note,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (storeId != null) 'store_id': storeId,
      if (supplierId != null) 'supplier_id': supplierId,
      if (reference != null) 'reference': reference,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (sentAt != null) 'sent_at': sentAt,
      if (closedAt != null) 'closed_at': closedAt,
      if (note != null) 'note': note,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PurchaseOrdersCompanion copyWith({
    Value<String>? id,
    Value<String>? storeId,
    Value<String>? supplierId,
    Value<String>? reference,
    Value<PurchaseOrderStatus>? status,
    Value<DateTime>? createdAt,
    Value<DateTime?>? sentAt,
    Value<DateTime?>? closedAt,
    Value<String?>? note,
    Value<int>? rowid,
  }) {
    return PurchaseOrdersCompanion(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      supplierId: supplierId ?? this.supplierId,
      reference: reference ?? this.reference,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      sentAt: sentAt ?? this.sentAt,
      closedAt: closedAt ?? this.closedAt,
      note: note ?? this.note,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (storeId.present) {
      map['store_id'] = Variable<String>(storeId.value);
    }
    if (supplierId.present) {
      map['supplier_id'] = Variable<String>(supplierId.value);
    }
    if (reference.present) {
      map['reference'] = Variable<String>(reference.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $PurchaseOrdersTable.$converterstatus.toSql(status.value),
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (sentAt.present) {
      map['sent_at'] = Variable<DateTime>(sentAt.value);
    }
    if (closedAt.present) {
      map['closed_at'] = Variable<DateTime>(closedAt.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PurchaseOrdersCompanion(')
          ..write('id: $id, ')
          ..write('storeId: $storeId, ')
          ..write('supplierId: $supplierId, ')
          ..write('reference: $reference, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('sentAt: $sentAt, ')
          ..write('closedAt: $closedAt, ')
          ..write('note: $note, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PurchaseOrderLinesTable extends PurchaseOrderLines
    with TableInfo<$PurchaseOrderLinesTable, PurchaseOrderLineRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PurchaseOrderLinesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 64,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _orderIdMeta = const VerificationMeta(
    'orderId',
  );
  @override
  late final GeneratedColumn<String> orderId = GeneratedColumn<String>(
    'order_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES purchase_orders (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quantityOrderedMeta = const VerificationMeta(
    'quantityOrdered',
  );
  @override
  late final GeneratedColumn<double> quantityOrdered = GeneratedColumn<double>(
    'quantity_ordered',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quantityReceivedMeta = const VerificationMeta(
    'quantityReceived',
  );
  @override
  late final GeneratedColumn<double> quantityReceived = GeneratedColumn<double>(
    'quantity_received',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _unitPriceMeta = const VerificationMeta(
    'unitPrice',
  );
  @override
  late final GeneratedColumn<double> unitPrice = GeneratedColumn<double>(
    'unit_price',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _closedShortMeta = const VerificationMeta(
    'closedShort',
  );
  @override
  late final GeneratedColumn<bool> closedShort = GeneratedColumn<bool>(
    'closed_short',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("closed_short" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    orderId,
    itemId,
    quantityOrdered,
    quantityReceived,
    unitPrice,
    closedShort,
    position,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'purchase_order_lines';
  @override
  VerificationContext validateIntegrity(
    Insertable<PurchaseOrderLineRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('order_id')) {
      context.handle(
        _orderIdMeta,
        orderId.isAcceptableOrUnknown(data['order_id']!, _orderIdMeta),
      );
    } else if (isInserting) {
      context.missing(_orderIdMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('quantity_ordered')) {
      context.handle(
        _quantityOrderedMeta,
        quantityOrdered.isAcceptableOrUnknown(
          data['quantity_ordered']!,
          _quantityOrderedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_quantityOrderedMeta);
    }
    if (data.containsKey('quantity_received')) {
      context.handle(
        _quantityReceivedMeta,
        quantityReceived.isAcceptableOrUnknown(
          data['quantity_received']!,
          _quantityReceivedMeta,
        ),
      );
    }
    if (data.containsKey('unit_price')) {
      context.handle(
        _unitPriceMeta,
        unitPrice.isAcceptableOrUnknown(data['unit_price']!, _unitPriceMeta),
      );
    } else if (isInserting) {
      context.missing(_unitPriceMeta);
    }
    if (data.containsKey('closed_short')) {
      context.handle(
        _closedShortMeta,
        closedShort.isAcceptableOrUnknown(
          data['closed_short']!,
          _closedShortMeta,
        ),
      );
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PurchaseOrderLineRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PurchaseOrderLineRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      orderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}order_id'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      quantityOrdered: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}quantity_ordered'],
      )!,
      quantityReceived: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}quantity_received'],
      )!,
      unitPrice: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}unit_price'],
      )!,
      closedShort: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}closed_short'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
    );
  }

  @override
  $PurchaseOrderLinesTable createAlias(String alias) {
    return $PurchaseOrderLinesTable(attachedDatabase, alias);
  }
}

class PurchaseOrderLineRow extends DataClass
    implements Insertable<PurchaseOrderLineRow> {
  final String id;
  final String orderId;

  /// **No foreign key, on purpose.** An article can be deleted while closed
  /// orders still list it — deletion is only blocked by an *open* order. An FK
  /// would either forbid deleting anything ever ordered, or delete lines out of
  /// a completed commande, and a commande that quietly loses a line is worse
  /// than one naming an article that is gone.
  final String itemId;
  final double quantityOrdered;

  /// Accumulated across receipts. A commande can be delivered in several goes,
  /// and this is the running total, not the last delivery.
  final double quantityReceived;

  /// The price agreed when the commande was sent. What actually arrives is on
  /// the receipt line; the two differing is the point of the réserves section.
  final double unitPrice;

  /// The receiver said the rest is not coming. Settles the line short rather
  /// than leaving the commande open forever with an inflated on-order quantity.
  final bool closedShort;

  /// Where this line sits in the commande, from zero.
  ///
  /// `PurchaseOrder.lines` is an ordered list on the model, and a child table
  /// has no order of its own. Sorting by `id` would work for the demo, whose
  /// line ids happen to end in an ordinal, and would shuffle a real commande
  /// into UUID order the moment it was saved — the person who typed the lines
  /// would watch them rearrange. Sorting by `rowid` would work until the day
  /// somebody runs `VACUUM`. So the position is a column.
  final int position;
  const PurchaseOrderLineRow({
    required this.id,
    required this.orderId,
    required this.itemId,
    required this.quantityOrdered,
    required this.quantityReceived,
    required this.unitPrice,
    required this.closedShort,
    required this.position,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['order_id'] = Variable<String>(orderId);
    map['item_id'] = Variable<String>(itemId);
    map['quantity_ordered'] = Variable<double>(quantityOrdered);
    map['quantity_received'] = Variable<double>(quantityReceived);
    map['unit_price'] = Variable<double>(unitPrice);
    map['closed_short'] = Variable<bool>(closedShort);
    map['position'] = Variable<int>(position);
    return map;
  }

  PurchaseOrderLinesCompanion toCompanion(bool nullToAbsent) {
    return PurchaseOrderLinesCompanion(
      id: Value(id),
      orderId: Value(orderId),
      itemId: Value(itemId),
      quantityOrdered: Value(quantityOrdered),
      quantityReceived: Value(quantityReceived),
      unitPrice: Value(unitPrice),
      closedShort: Value(closedShort),
      position: Value(position),
    );
  }

  factory PurchaseOrderLineRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PurchaseOrderLineRow(
      id: serializer.fromJson<String>(json['id']),
      orderId: serializer.fromJson<String>(json['orderId']),
      itemId: serializer.fromJson<String>(json['itemId']),
      quantityOrdered: serializer.fromJson<double>(json['quantityOrdered']),
      quantityReceived: serializer.fromJson<double>(json['quantityReceived']),
      unitPrice: serializer.fromJson<double>(json['unitPrice']),
      closedShort: serializer.fromJson<bool>(json['closedShort']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'orderId': serializer.toJson<String>(orderId),
      'itemId': serializer.toJson<String>(itemId),
      'quantityOrdered': serializer.toJson<double>(quantityOrdered),
      'quantityReceived': serializer.toJson<double>(quantityReceived),
      'unitPrice': serializer.toJson<double>(unitPrice),
      'closedShort': serializer.toJson<bool>(closedShort),
      'position': serializer.toJson<int>(position),
    };
  }

  PurchaseOrderLineRow copyWith({
    String? id,
    String? orderId,
    String? itemId,
    double? quantityOrdered,
    double? quantityReceived,
    double? unitPrice,
    bool? closedShort,
    int? position,
  }) => PurchaseOrderLineRow(
    id: id ?? this.id,
    orderId: orderId ?? this.orderId,
    itemId: itemId ?? this.itemId,
    quantityOrdered: quantityOrdered ?? this.quantityOrdered,
    quantityReceived: quantityReceived ?? this.quantityReceived,
    unitPrice: unitPrice ?? this.unitPrice,
    closedShort: closedShort ?? this.closedShort,
    position: position ?? this.position,
  );
  PurchaseOrderLineRow copyWithCompanion(PurchaseOrderLinesCompanion data) {
    return PurchaseOrderLineRow(
      id: data.id.present ? data.id.value : this.id,
      orderId: data.orderId.present ? data.orderId.value : this.orderId,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      quantityOrdered: data.quantityOrdered.present
          ? data.quantityOrdered.value
          : this.quantityOrdered,
      quantityReceived: data.quantityReceived.present
          ? data.quantityReceived.value
          : this.quantityReceived,
      unitPrice: data.unitPrice.present ? data.unitPrice.value : this.unitPrice,
      closedShort: data.closedShort.present
          ? data.closedShort.value
          : this.closedShort,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PurchaseOrderLineRow(')
          ..write('id: $id, ')
          ..write('orderId: $orderId, ')
          ..write('itemId: $itemId, ')
          ..write('quantityOrdered: $quantityOrdered, ')
          ..write('quantityReceived: $quantityReceived, ')
          ..write('unitPrice: $unitPrice, ')
          ..write('closedShort: $closedShort, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    orderId,
    itemId,
    quantityOrdered,
    quantityReceived,
    unitPrice,
    closedShort,
    position,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PurchaseOrderLineRow &&
          other.id == this.id &&
          other.orderId == this.orderId &&
          other.itemId == this.itemId &&
          other.quantityOrdered == this.quantityOrdered &&
          other.quantityReceived == this.quantityReceived &&
          other.unitPrice == this.unitPrice &&
          other.closedShort == this.closedShort &&
          other.position == this.position);
}

class PurchaseOrderLinesCompanion
    extends UpdateCompanion<PurchaseOrderLineRow> {
  final Value<String> id;
  final Value<String> orderId;
  final Value<String> itemId;
  final Value<double> quantityOrdered;
  final Value<double> quantityReceived;
  final Value<double> unitPrice;
  final Value<bool> closedShort;
  final Value<int> position;
  final Value<int> rowid;
  const PurchaseOrderLinesCompanion({
    this.id = const Value.absent(),
    this.orderId = const Value.absent(),
    this.itemId = const Value.absent(),
    this.quantityOrdered = const Value.absent(),
    this.quantityReceived = const Value.absent(),
    this.unitPrice = const Value.absent(),
    this.closedShort = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PurchaseOrderLinesCompanion.insert({
    required String id,
    required String orderId,
    required String itemId,
    required double quantityOrdered,
    this.quantityReceived = const Value.absent(),
    required double unitPrice,
    this.closedShort = const Value.absent(),
    required int position,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       orderId = Value(orderId),
       itemId = Value(itemId),
       quantityOrdered = Value(quantityOrdered),
       unitPrice = Value(unitPrice),
       position = Value(position);
  static Insertable<PurchaseOrderLineRow> custom({
    Expression<String>? id,
    Expression<String>? orderId,
    Expression<String>? itemId,
    Expression<double>? quantityOrdered,
    Expression<double>? quantityReceived,
    Expression<double>? unitPrice,
    Expression<bool>? closedShort,
    Expression<int>? position,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (orderId != null) 'order_id': orderId,
      if (itemId != null) 'item_id': itemId,
      if (quantityOrdered != null) 'quantity_ordered': quantityOrdered,
      if (quantityReceived != null) 'quantity_received': quantityReceived,
      if (unitPrice != null) 'unit_price': unitPrice,
      if (closedShort != null) 'closed_short': closedShort,
      if (position != null) 'position': position,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PurchaseOrderLinesCompanion copyWith({
    Value<String>? id,
    Value<String>? orderId,
    Value<String>? itemId,
    Value<double>? quantityOrdered,
    Value<double>? quantityReceived,
    Value<double>? unitPrice,
    Value<bool>? closedShort,
    Value<int>? position,
    Value<int>? rowid,
  }) {
    return PurchaseOrderLinesCompanion(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      itemId: itemId ?? this.itemId,
      quantityOrdered: quantityOrdered ?? this.quantityOrdered,
      quantityReceived: quantityReceived ?? this.quantityReceived,
      unitPrice: unitPrice ?? this.unitPrice,
      closedShort: closedShort ?? this.closedShort,
      position: position ?? this.position,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (orderId.present) {
      map['order_id'] = Variable<String>(orderId.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (quantityOrdered.present) {
      map['quantity_ordered'] = Variable<double>(quantityOrdered.value);
    }
    if (quantityReceived.present) {
      map['quantity_received'] = Variable<double>(quantityReceived.value);
    }
    if (unitPrice.present) {
      map['unit_price'] = Variable<double>(unitPrice.value);
    }
    if (closedShort.present) {
      map['closed_short'] = Variable<bool>(closedShort.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PurchaseOrderLinesCompanion(')
          ..write('id: $id, ')
          ..write('orderId: $orderId, ')
          ..write('itemId: $itemId, ')
          ..write('quantityOrdered: $quantityOrdered, ')
          ..write('quantityReceived: $quantityReceived, ')
          ..write('unitPrice: $unitPrice, ')
          ..write('closedShort: $closedShort, ')
          ..write('position: $position, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GoodsReceiptsTable extends GoodsReceipts
    with TableInfo<$GoodsReceiptsTable, GoodsReceiptRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GoodsReceiptsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 64,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _orderIdMeta = const VerificationMeta(
    'orderId',
  );
  @override
  late final GeneratedColumn<String> orderId = GeneratedColumn<String>(
    'order_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES purchase_orders (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _storeIdMeta = const VerificationMeta(
    'storeId',
  );
  @override
  late final GeneratedColumn<String> storeId = GeneratedColumn<String>(
    'store_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES stores (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _receivedAtMeta = const VerificationMeta(
    'receivedAt',
  );
  @override
  late final GeneratedColumn<DateTime> receivedAt = GeneratedColumn<DateTime>(
    'received_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _receivedByNameMeta = const VerificationMeta(
    'receivedByName',
  );
  @override
  late final GeneratedColumn<String> receivedByName = GeneratedColumn<String>(
    'received_by_name',
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
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    orderId,
    storeId,
    receivedAt,
    receivedByName,
    note,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'goods_receipts';
  @override
  VerificationContext validateIntegrity(
    Insertable<GoodsReceiptRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('order_id')) {
      context.handle(
        _orderIdMeta,
        orderId.isAcceptableOrUnknown(data['order_id']!, _orderIdMeta),
      );
    } else if (isInserting) {
      context.missing(_orderIdMeta);
    }
    if (data.containsKey('store_id')) {
      context.handle(
        _storeIdMeta,
        storeId.isAcceptableOrUnknown(data['store_id']!, _storeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_storeIdMeta);
    }
    if (data.containsKey('received_at')) {
      context.handle(
        _receivedAtMeta,
        receivedAt.isAcceptableOrUnknown(data['received_at']!, _receivedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_receivedAtMeta);
    }
    if (data.containsKey('received_by_name')) {
      context.handle(
        _receivedByNameMeta,
        receivedByName.isAcceptableOrUnknown(
          data['received_by_name']!,
          _receivedByNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_receivedByNameMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GoodsReceiptRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GoodsReceiptRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      orderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}order_id'],
      )!,
      storeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}store_id'],
      )!,
      receivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}received_at'],
      )!,
      receivedByName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}received_by_name'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
    );
  }

  @override
  $GoodsReceiptsTable createAlias(String alias) {
    return $GoodsReceiptsTable(attachedDatabase, alias);
  }
}

class GoodsReceiptRow extends DataClass implements Insertable<GoodsReceiptRow> {
  final String id;

  /// Cascades, because a receipt has no meaning without its commande — the
  /// derived reference `BR-2026-014/2` is literally the order's reference plus
  /// this receipt's position within it. In practice the cascade never fires: an
  /// order that has been received cannot be deleted.
  final String orderId;
  final String storeId;

  /// Receipts for one order are read oldest first — the `/2` in the derived
  /// reference is a position in that order, so it has to be stable.
  final DateTime receivedAt;
  final String receivedByName;
  final String? note;
  const GoodsReceiptRow({
    required this.id,
    required this.orderId,
    required this.storeId,
    required this.receivedAt,
    required this.receivedByName,
    this.note,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['order_id'] = Variable<String>(orderId);
    map['store_id'] = Variable<String>(storeId);
    map['received_at'] = Variable<DateTime>(receivedAt);
    map['received_by_name'] = Variable<String>(receivedByName);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    return map;
  }

  GoodsReceiptsCompanion toCompanion(bool nullToAbsent) {
    return GoodsReceiptsCompanion(
      id: Value(id),
      orderId: Value(orderId),
      storeId: Value(storeId),
      receivedAt: Value(receivedAt),
      receivedByName: Value(receivedByName),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
    );
  }

  factory GoodsReceiptRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GoodsReceiptRow(
      id: serializer.fromJson<String>(json['id']),
      orderId: serializer.fromJson<String>(json['orderId']),
      storeId: serializer.fromJson<String>(json['storeId']),
      receivedAt: serializer.fromJson<DateTime>(json['receivedAt']),
      receivedByName: serializer.fromJson<String>(json['receivedByName']),
      note: serializer.fromJson<String?>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'orderId': serializer.toJson<String>(orderId),
      'storeId': serializer.toJson<String>(storeId),
      'receivedAt': serializer.toJson<DateTime>(receivedAt),
      'receivedByName': serializer.toJson<String>(receivedByName),
      'note': serializer.toJson<String?>(note),
    };
  }

  GoodsReceiptRow copyWith({
    String? id,
    String? orderId,
    String? storeId,
    DateTime? receivedAt,
    String? receivedByName,
    Value<String?> note = const Value.absent(),
  }) => GoodsReceiptRow(
    id: id ?? this.id,
    orderId: orderId ?? this.orderId,
    storeId: storeId ?? this.storeId,
    receivedAt: receivedAt ?? this.receivedAt,
    receivedByName: receivedByName ?? this.receivedByName,
    note: note.present ? note.value : this.note,
  );
  GoodsReceiptRow copyWithCompanion(GoodsReceiptsCompanion data) {
    return GoodsReceiptRow(
      id: data.id.present ? data.id.value : this.id,
      orderId: data.orderId.present ? data.orderId.value : this.orderId,
      storeId: data.storeId.present ? data.storeId.value : this.storeId,
      receivedAt: data.receivedAt.present
          ? data.receivedAt.value
          : this.receivedAt,
      receivedByName: data.receivedByName.present
          ? data.receivedByName.value
          : this.receivedByName,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GoodsReceiptRow(')
          ..write('id: $id, ')
          ..write('orderId: $orderId, ')
          ..write('storeId: $storeId, ')
          ..write('receivedAt: $receivedAt, ')
          ..write('receivedByName: $receivedByName, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, orderId, storeId, receivedAt, receivedByName, note);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GoodsReceiptRow &&
          other.id == this.id &&
          other.orderId == this.orderId &&
          other.storeId == this.storeId &&
          other.receivedAt == this.receivedAt &&
          other.receivedByName == this.receivedByName &&
          other.note == this.note);
}

class GoodsReceiptsCompanion extends UpdateCompanion<GoodsReceiptRow> {
  final Value<String> id;
  final Value<String> orderId;
  final Value<String> storeId;
  final Value<DateTime> receivedAt;
  final Value<String> receivedByName;
  final Value<String?> note;
  final Value<int> rowid;
  const GoodsReceiptsCompanion({
    this.id = const Value.absent(),
    this.orderId = const Value.absent(),
    this.storeId = const Value.absent(),
    this.receivedAt = const Value.absent(),
    this.receivedByName = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GoodsReceiptsCompanion.insert({
    required String id,
    required String orderId,
    required String storeId,
    required DateTime receivedAt,
    required String receivedByName,
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       orderId = Value(orderId),
       storeId = Value(storeId),
       receivedAt = Value(receivedAt),
       receivedByName = Value(receivedByName);
  static Insertable<GoodsReceiptRow> custom({
    Expression<String>? id,
    Expression<String>? orderId,
    Expression<String>? storeId,
    Expression<DateTime>? receivedAt,
    Expression<String>? receivedByName,
    Expression<String>? note,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (orderId != null) 'order_id': orderId,
      if (storeId != null) 'store_id': storeId,
      if (receivedAt != null) 'received_at': receivedAt,
      if (receivedByName != null) 'received_by_name': receivedByName,
      if (note != null) 'note': note,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GoodsReceiptsCompanion copyWith({
    Value<String>? id,
    Value<String>? orderId,
    Value<String>? storeId,
    Value<DateTime>? receivedAt,
    Value<String>? receivedByName,
    Value<String?>? note,
    Value<int>? rowid,
  }) {
    return GoodsReceiptsCompanion(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      storeId: storeId ?? this.storeId,
      receivedAt: receivedAt ?? this.receivedAt,
      receivedByName: receivedByName ?? this.receivedByName,
      note: note ?? this.note,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (orderId.present) {
      map['order_id'] = Variable<String>(orderId.value);
    }
    if (storeId.present) {
      map['store_id'] = Variable<String>(storeId.value);
    }
    if (receivedAt.present) {
      map['received_at'] = Variable<DateTime>(receivedAt.value);
    }
    if (receivedByName.present) {
      map['received_by_name'] = Variable<String>(receivedByName.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GoodsReceiptsCompanion(')
          ..write('id: $id, ')
          ..write('orderId: $orderId, ')
          ..write('storeId: $storeId, ')
          ..write('receivedAt: $receivedAt, ')
          ..write('receivedByName: $receivedByName, ')
          ..write('note: $note, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GoodsReceiptLinesTable extends GoodsReceiptLines
    with TableInfo<$GoodsReceiptLinesTable, GoodsReceiptLineRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GoodsReceiptLinesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 64,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _receiptIdMeta = const VerificationMeta(
    'receiptId',
  );
  @override
  late final GeneratedColumn<String> receiptId = GeneratedColumn<String>(
    'receipt_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES goods_receipts (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quantityOrderedMeta = const VerificationMeta(
    'quantityOrdered',
  );
  @override
  late final GeneratedColumn<double> quantityOrdered = GeneratedColumn<double>(
    'quantity_ordered',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quantityReceivedMeta = const VerificationMeta(
    'quantityReceived',
  );
  @override
  late final GeneratedColumn<double> quantityReceived = GeneratedColumn<double>(
    'quantity_received',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actualUnitPriceMeta = const VerificationMeta(
    'actualUnitPrice',
  );
  @override
  late final GeneratedColumn<double> actualUnitPrice = GeneratedColumn<double>(
    'actual_unit_price',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _closedShortMeta = const VerificationMeta(
    'closedShort',
  );
  @override
  late final GeneratedColumn<bool> closedShort = GeneratedColumn<bool>(
    'closed_short',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("closed_short" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _wasUnorderedMeta = const VerificationMeta(
    'wasUnordered',
  );
  @override
  late final GeneratedColumn<bool> wasUnordered = GeneratedColumn<bool>(
    'was_unordered',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("was_unordered" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    receiptId,
    itemId,
    quantityOrdered,
    quantityReceived,
    actualUnitPrice,
    closedShort,
    wasUnordered,
    note,
    position,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'goods_receipt_lines';
  @override
  VerificationContext validateIntegrity(
    Insertable<GoodsReceiptLineRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('receipt_id')) {
      context.handle(
        _receiptIdMeta,
        receiptId.isAcceptableOrUnknown(data['receipt_id']!, _receiptIdMeta),
      );
    } else if (isInserting) {
      context.missing(_receiptIdMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('quantity_ordered')) {
      context.handle(
        _quantityOrderedMeta,
        quantityOrdered.isAcceptableOrUnknown(
          data['quantity_ordered']!,
          _quantityOrderedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_quantityOrderedMeta);
    }
    if (data.containsKey('quantity_received')) {
      context.handle(
        _quantityReceivedMeta,
        quantityReceived.isAcceptableOrUnknown(
          data['quantity_received']!,
          _quantityReceivedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_quantityReceivedMeta);
    }
    if (data.containsKey('actual_unit_price')) {
      context.handle(
        _actualUnitPriceMeta,
        actualUnitPrice.isAcceptableOrUnknown(
          data['actual_unit_price']!,
          _actualUnitPriceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_actualUnitPriceMeta);
    }
    if (data.containsKey('closed_short')) {
      context.handle(
        _closedShortMeta,
        closedShort.isAcceptableOrUnknown(
          data['closed_short']!,
          _closedShortMeta,
        ),
      );
    }
    if (data.containsKey('was_unordered')) {
      context.handle(
        _wasUnorderedMeta,
        wasUnordered.isAcceptableOrUnknown(
          data['was_unordered']!,
          _wasUnorderedMeta,
        ),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GoodsReceiptLineRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GoodsReceiptLineRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      receiptId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}receipt_id'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      quantityOrdered: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}quantity_ordered'],
      )!,
      quantityReceived: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}quantity_received'],
      )!,
      actualUnitPrice: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}actual_unit_price'],
      )!,
      closedShort: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}closed_short'],
      )!,
      wasUnordered: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}was_unordered'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
    );
  }

  @override
  $GoodsReceiptLinesTable createAlias(String alias) {
    return $GoodsReceiptLinesTable(attachedDatabase, alias);
  }
}

class GoodsReceiptLineRow extends DataClass
    implements Insertable<GoodsReceiptLineRow> {
  final String id;
  final String receiptId;

  /// No foreign key, for the reason given on `purchase_order_lines.itemId`.
  final String itemId;

  /// What the commande asked for, copied onto the receipt at the time. Zero for
  /// an unordered line. Copied rather than joined so the document still reads
  /// correctly after the commande's own lines move on.
  final double quantityOrdered;
  final double quantityReceived;

  /// What the delivery actually charged, which is the number compared against
  /// the price on file to decide whether the price history gains an entry.
  final double actualUnitPrice;
  final bool closedShort;

  /// Arrived without being ordered. Kept on the receipt and stocked in, but
  /// deliberately not added to the commande — the commande is what was agreed.
  final bool wasUnordered;
  final String? note;

  /// Where this line sits on the document, from zero. See the same column on
  /// `purchase_order_lines`; it matters more here, because the bon de réception
  /// is a pure projection of the receipt and two renders of it have to produce
  /// the same page.
  final int position;
  const GoodsReceiptLineRow({
    required this.id,
    required this.receiptId,
    required this.itemId,
    required this.quantityOrdered,
    required this.quantityReceived,
    required this.actualUnitPrice,
    required this.closedShort,
    required this.wasUnordered,
    this.note,
    required this.position,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['receipt_id'] = Variable<String>(receiptId);
    map['item_id'] = Variable<String>(itemId);
    map['quantity_ordered'] = Variable<double>(quantityOrdered);
    map['quantity_received'] = Variable<double>(quantityReceived);
    map['actual_unit_price'] = Variable<double>(actualUnitPrice);
    map['closed_short'] = Variable<bool>(closedShort);
    map['was_unordered'] = Variable<bool>(wasUnordered);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['position'] = Variable<int>(position);
    return map;
  }

  GoodsReceiptLinesCompanion toCompanion(bool nullToAbsent) {
    return GoodsReceiptLinesCompanion(
      id: Value(id),
      receiptId: Value(receiptId),
      itemId: Value(itemId),
      quantityOrdered: Value(quantityOrdered),
      quantityReceived: Value(quantityReceived),
      actualUnitPrice: Value(actualUnitPrice),
      closedShort: Value(closedShort),
      wasUnordered: Value(wasUnordered),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      position: Value(position),
    );
  }

  factory GoodsReceiptLineRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GoodsReceiptLineRow(
      id: serializer.fromJson<String>(json['id']),
      receiptId: serializer.fromJson<String>(json['receiptId']),
      itemId: serializer.fromJson<String>(json['itemId']),
      quantityOrdered: serializer.fromJson<double>(json['quantityOrdered']),
      quantityReceived: serializer.fromJson<double>(json['quantityReceived']),
      actualUnitPrice: serializer.fromJson<double>(json['actualUnitPrice']),
      closedShort: serializer.fromJson<bool>(json['closedShort']),
      wasUnordered: serializer.fromJson<bool>(json['wasUnordered']),
      note: serializer.fromJson<String?>(json['note']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'receiptId': serializer.toJson<String>(receiptId),
      'itemId': serializer.toJson<String>(itemId),
      'quantityOrdered': serializer.toJson<double>(quantityOrdered),
      'quantityReceived': serializer.toJson<double>(quantityReceived),
      'actualUnitPrice': serializer.toJson<double>(actualUnitPrice),
      'closedShort': serializer.toJson<bool>(closedShort),
      'wasUnordered': serializer.toJson<bool>(wasUnordered),
      'note': serializer.toJson<String?>(note),
      'position': serializer.toJson<int>(position),
    };
  }

  GoodsReceiptLineRow copyWith({
    String? id,
    String? receiptId,
    String? itemId,
    double? quantityOrdered,
    double? quantityReceived,
    double? actualUnitPrice,
    bool? closedShort,
    bool? wasUnordered,
    Value<String?> note = const Value.absent(),
    int? position,
  }) => GoodsReceiptLineRow(
    id: id ?? this.id,
    receiptId: receiptId ?? this.receiptId,
    itemId: itemId ?? this.itemId,
    quantityOrdered: quantityOrdered ?? this.quantityOrdered,
    quantityReceived: quantityReceived ?? this.quantityReceived,
    actualUnitPrice: actualUnitPrice ?? this.actualUnitPrice,
    closedShort: closedShort ?? this.closedShort,
    wasUnordered: wasUnordered ?? this.wasUnordered,
    note: note.present ? note.value : this.note,
    position: position ?? this.position,
  );
  GoodsReceiptLineRow copyWithCompanion(GoodsReceiptLinesCompanion data) {
    return GoodsReceiptLineRow(
      id: data.id.present ? data.id.value : this.id,
      receiptId: data.receiptId.present ? data.receiptId.value : this.receiptId,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      quantityOrdered: data.quantityOrdered.present
          ? data.quantityOrdered.value
          : this.quantityOrdered,
      quantityReceived: data.quantityReceived.present
          ? data.quantityReceived.value
          : this.quantityReceived,
      actualUnitPrice: data.actualUnitPrice.present
          ? data.actualUnitPrice.value
          : this.actualUnitPrice,
      closedShort: data.closedShort.present
          ? data.closedShort.value
          : this.closedShort,
      wasUnordered: data.wasUnordered.present
          ? data.wasUnordered.value
          : this.wasUnordered,
      note: data.note.present ? data.note.value : this.note,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GoodsReceiptLineRow(')
          ..write('id: $id, ')
          ..write('receiptId: $receiptId, ')
          ..write('itemId: $itemId, ')
          ..write('quantityOrdered: $quantityOrdered, ')
          ..write('quantityReceived: $quantityReceived, ')
          ..write('actualUnitPrice: $actualUnitPrice, ')
          ..write('closedShort: $closedShort, ')
          ..write('wasUnordered: $wasUnordered, ')
          ..write('note: $note, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    receiptId,
    itemId,
    quantityOrdered,
    quantityReceived,
    actualUnitPrice,
    closedShort,
    wasUnordered,
    note,
    position,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GoodsReceiptLineRow &&
          other.id == this.id &&
          other.receiptId == this.receiptId &&
          other.itemId == this.itemId &&
          other.quantityOrdered == this.quantityOrdered &&
          other.quantityReceived == this.quantityReceived &&
          other.actualUnitPrice == this.actualUnitPrice &&
          other.closedShort == this.closedShort &&
          other.wasUnordered == this.wasUnordered &&
          other.note == this.note &&
          other.position == this.position);
}

class GoodsReceiptLinesCompanion extends UpdateCompanion<GoodsReceiptLineRow> {
  final Value<String> id;
  final Value<String> receiptId;
  final Value<String> itemId;
  final Value<double> quantityOrdered;
  final Value<double> quantityReceived;
  final Value<double> actualUnitPrice;
  final Value<bool> closedShort;
  final Value<bool> wasUnordered;
  final Value<String?> note;
  final Value<int> position;
  final Value<int> rowid;
  const GoodsReceiptLinesCompanion({
    this.id = const Value.absent(),
    this.receiptId = const Value.absent(),
    this.itemId = const Value.absent(),
    this.quantityOrdered = const Value.absent(),
    this.quantityReceived = const Value.absent(),
    this.actualUnitPrice = const Value.absent(),
    this.closedShort = const Value.absent(),
    this.wasUnordered = const Value.absent(),
    this.note = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GoodsReceiptLinesCompanion.insert({
    required String id,
    required String receiptId,
    required String itemId,
    required double quantityOrdered,
    required double quantityReceived,
    required double actualUnitPrice,
    this.closedShort = const Value.absent(),
    this.wasUnordered = const Value.absent(),
    this.note = const Value.absent(),
    required int position,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       receiptId = Value(receiptId),
       itemId = Value(itemId),
       quantityOrdered = Value(quantityOrdered),
       quantityReceived = Value(quantityReceived),
       actualUnitPrice = Value(actualUnitPrice),
       position = Value(position);
  static Insertable<GoodsReceiptLineRow> custom({
    Expression<String>? id,
    Expression<String>? receiptId,
    Expression<String>? itemId,
    Expression<double>? quantityOrdered,
    Expression<double>? quantityReceived,
    Expression<double>? actualUnitPrice,
    Expression<bool>? closedShort,
    Expression<bool>? wasUnordered,
    Expression<String>? note,
    Expression<int>? position,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (receiptId != null) 'receipt_id': receiptId,
      if (itemId != null) 'item_id': itemId,
      if (quantityOrdered != null) 'quantity_ordered': quantityOrdered,
      if (quantityReceived != null) 'quantity_received': quantityReceived,
      if (actualUnitPrice != null) 'actual_unit_price': actualUnitPrice,
      if (closedShort != null) 'closed_short': closedShort,
      if (wasUnordered != null) 'was_unordered': wasUnordered,
      if (note != null) 'note': note,
      if (position != null) 'position': position,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GoodsReceiptLinesCompanion copyWith({
    Value<String>? id,
    Value<String>? receiptId,
    Value<String>? itemId,
    Value<double>? quantityOrdered,
    Value<double>? quantityReceived,
    Value<double>? actualUnitPrice,
    Value<bool>? closedShort,
    Value<bool>? wasUnordered,
    Value<String?>? note,
    Value<int>? position,
    Value<int>? rowid,
  }) {
    return GoodsReceiptLinesCompanion(
      id: id ?? this.id,
      receiptId: receiptId ?? this.receiptId,
      itemId: itemId ?? this.itemId,
      quantityOrdered: quantityOrdered ?? this.quantityOrdered,
      quantityReceived: quantityReceived ?? this.quantityReceived,
      actualUnitPrice: actualUnitPrice ?? this.actualUnitPrice,
      closedShort: closedShort ?? this.closedShort,
      wasUnordered: wasUnordered ?? this.wasUnordered,
      note: note ?? this.note,
      position: position ?? this.position,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (receiptId.present) {
      map['receipt_id'] = Variable<String>(receiptId.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (quantityOrdered.present) {
      map['quantity_ordered'] = Variable<double>(quantityOrdered.value);
    }
    if (quantityReceived.present) {
      map['quantity_received'] = Variable<double>(quantityReceived.value);
    }
    if (actualUnitPrice.present) {
      map['actual_unit_price'] = Variable<double>(actualUnitPrice.value);
    }
    if (closedShort.present) {
      map['closed_short'] = Variable<bool>(closedShort.value);
    }
    if (wasUnordered.present) {
      map['was_unordered'] = Variable<bool>(wasUnordered.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GoodsReceiptLinesCompanion(')
          ..write('id: $id, ')
          ..write('receiptId: $receiptId, ')
          ..write('itemId: $itemId, ')
          ..write('quantityOrdered: $quantityOrdered, ')
          ..write('quantityReceived: $quantityReceived, ')
          ..write('actualUnitPrice: $actualUnitPrice, ')
          ..write('closedShort: $closedShort, ')
          ..write('wasUnordered: $wasUnordered, ')
          ..write('note: $note, ')
          ..write('position: $position, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NotificationsTable extends Notifications
    with TableInfo<$NotificationsTable, NotificationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotificationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 64,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _storeIdMeta = const VerificationMeta(
    'storeId',
  );
  @override
  late final GeneratedColumn<String> storeId = GeneratedColumn<String>(
    'store_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES stores (id) ON DELETE CASCADE',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<NotificationKind, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<NotificationKind>($NotificationsTable.$converterkind);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
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
  static const VerificationMeta _isReadMeta = const VerificationMeta('isRead');
  @override
  late final GeneratedColumn<bool> isRead = GeneratedColumn<bool>(
    'is_read',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_read" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _relatedItemIdMeta = const VerificationMeta(
    'relatedItemId',
  );
  @override
  late final GeneratedColumn<String> relatedItemId = GeneratedColumn<String>(
    'related_item_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _relatedSupplierIdMeta = const VerificationMeta(
    'relatedSupplierId',
  );
  @override
  late final GeneratedColumn<String> relatedSupplierId =
      GeneratedColumn<String>(
        'related_supplier_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    storeId,
    kind,
    title,
    body,
    createdAt,
    isRead,
    relatedItemId,
    relatedSupplierId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notifications';
  @override
  VerificationContext validateIntegrity(
    Insertable<NotificationRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('store_id')) {
      context.handle(
        _storeIdMeta,
        storeId.isAcceptableOrUnknown(data['store_id']!, _storeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_storeIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('is_read')) {
      context.handle(
        _isReadMeta,
        isRead.isAcceptableOrUnknown(data['is_read']!, _isReadMeta),
      );
    }
    if (data.containsKey('related_item_id')) {
      context.handle(
        _relatedItemIdMeta,
        relatedItemId.isAcceptableOrUnknown(
          data['related_item_id']!,
          _relatedItemIdMeta,
        ),
      );
    }
    if (data.containsKey('related_supplier_id')) {
      context.handle(
        _relatedSupplierIdMeta,
        relatedSupplierId.isAcceptableOrUnknown(
          data['related_supplier_id']!,
          _relatedSupplierIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  NotificationRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NotificationRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      storeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}store_id'],
      )!,
      kind: $NotificationsTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      isRead: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_read'],
      )!,
      relatedItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}related_item_id'],
      ),
      relatedSupplierId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}related_supplier_id'],
      ),
    );
  }

  @override
  $NotificationsTable createAlias(String alias) {
    return $NotificationsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<NotificationKind, String, String> $converterkind =
      const EnumNameConverter<NotificationKind>(NotificationKind.values);
}

class NotificationRow extends DataClass implements Insertable<NotificationRow> {
  final String id;
  final String storeId;
  final NotificationKind kind;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;

  /// What tapping the notification opens. No foreign keys: a notification about
  /// an article outlives the article, and it still reads correctly — the tap
  /// target is what disappears, not the message.
  final String? relatedItemId;
  final String? relatedSupplierId;
  const NotificationRow({
    required this.id,
    required this.storeId,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.isRead,
    this.relatedItemId,
    this.relatedSupplierId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['store_id'] = Variable<String>(storeId);
    {
      map['kind'] = Variable<String>(
        $NotificationsTable.$converterkind.toSql(kind),
      );
    }
    map['title'] = Variable<String>(title);
    map['body'] = Variable<String>(body);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['is_read'] = Variable<bool>(isRead);
    if (!nullToAbsent || relatedItemId != null) {
      map['related_item_id'] = Variable<String>(relatedItemId);
    }
    if (!nullToAbsent || relatedSupplierId != null) {
      map['related_supplier_id'] = Variable<String>(relatedSupplierId);
    }
    return map;
  }

  NotificationsCompanion toCompanion(bool nullToAbsent) {
    return NotificationsCompanion(
      id: Value(id),
      storeId: Value(storeId),
      kind: Value(kind),
      title: Value(title),
      body: Value(body),
      createdAt: Value(createdAt),
      isRead: Value(isRead),
      relatedItemId: relatedItemId == null && nullToAbsent
          ? const Value.absent()
          : Value(relatedItemId),
      relatedSupplierId: relatedSupplierId == null && nullToAbsent
          ? const Value.absent()
          : Value(relatedSupplierId),
    );
  }

  factory NotificationRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NotificationRow(
      id: serializer.fromJson<String>(json['id']),
      storeId: serializer.fromJson<String>(json['storeId']),
      kind: $NotificationsTable.$converterkind.fromJson(
        serializer.fromJson<String>(json['kind']),
      ),
      title: serializer.fromJson<String>(json['title']),
      body: serializer.fromJson<String>(json['body']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      isRead: serializer.fromJson<bool>(json['isRead']),
      relatedItemId: serializer.fromJson<String?>(json['relatedItemId']),
      relatedSupplierId: serializer.fromJson<String?>(
        json['relatedSupplierId'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'storeId': serializer.toJson<String>(storeId),
      'kind': serializer.toJson<String>(
        $NotificationsTable.$converterkind.toJson(kind),
      ),
      'title': serializer.toJson<String>(title),
      'body': serializer.toJson<String>(body),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'isRead': serializer.toJson<bool>(isRead),
      'relatedItemId': serializer.toJson<String?>(relatedItemId),
      'relatedSupplierId': serializer.toJson<String?>(relatedSupplierId),
    };
  }

  NotificationRow copyWith({
    String? id,
    String? storeId,
    NotificationKind? kind,
    String? title,
    String? body,
    DateTime? createdAt,
    bool? isRead,
    Value<String?> relatedItemId = const Value.absent(),
    Value<String?> relatedSupplierId = const Value.absent(),
  }) => NotificationRow(
    id: id ?? this.id,
    storeId: storeId ?? this.storeId,
    kind: kind ?? this.kind,
    title: title ?? this.title,
    body: body ?? this.body,
    createdAt: createdAt ?? this.createdAt,
    isRead: isRead ?? this.isRead,
    relatedItemId: relatedItemId.present
        ? relatedItemId.value
        : this.relatedItemId,
    relatedSupplierId: relatedSupplierId.present
        ? relatedSupplierId.value
        : this.relatedSupplierId,
  );
  NotificationRow copyWithCompanion(NotificationsCompanion data) {
    return NotificationRow(
      id: data.id.present ? data.id.value : this.id,
      storeId: data.storeId.present ? data.storeId.value : this.storeId,
      kind: data.kind.present ? data.kind.value : this.kind,
      title: data.title.present ? data.title.value : this.title,
      body: data.body.present ? data.body.value : this.body,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      isRead: data.isRead.present ? data.isRead.value : this.isRead,
      relatedItemId: data.relatedItemId.present
          ? data.relatedItemId.value
          : this.relatedItemId,
      relatedSupplierId: data.relatedSupplierId.present
          ? data.relatedSupplierId.value
          : this.relatedSupplierId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NotificationRow(')
          ..write('id: $id, ')
          ..write('storeId: $storeId, ')
          ..write('kind: $kind, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('createdAt: $createdAt, ')
          ..write('isRead: $isRead, ')
          ..write('relatedItemId: $relatedItemId, ')
          ..write('relatedSupplierId: $relatedSupplierId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    storeId,
    kind,
    title,
    body,
    createdAt,
    isRead,
    relatedItemId,
    relatedSupplierId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NotificationRow &&
          other.id == this.id &&
          other.storeId == this.storeId &&
          other.kind == this.kind &&
          other.title == this.title &&
          other.body == this.body &&
          other.createdAt == this.createdAt &&
          other.isRead == this.isRead &&
          other.relatedItemId == this.relatedItemId &&
          other.relatedSupplierId == this.relatedSupplierId);
}

class NotificationsCompanion extends UpdateCompanion<NotificationRow> {
  final Value<String> id;
  final Value<String> storeId;
  final Value<NotificationKind> kind;
  final Value<String> title;
  final Value<String> body;
  final Value<DateTime> createdAt;
  final Value<bool> isRead;
  final Value<String?> relatedItemId;
  final Value<String?> relatedSupplierId;
  final Value<int> rowid;
  const NotificationsCompanion({
    this.id = const Value.absent(),
    this.storeId = const Value.absent(),
    this.kind = const Value.absent(),
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.isRead = const Value.absent(),
    this.relatedItemId = const Value.absent(),
    this.relatedSupplierId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NotificationsCompanion.insert({
    required String id,
    required String storeId,
    required NotificationKind kind,
    required String title,
    required String body,
    required DateTime createdAt,
    this.isRead = const Value.absent(),
    this.relatedItemId = const Value.absent(),
    this.relatedSupplierId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       storeId = Value(storeId),
       kind = Value(kind),
       title = Value(title),
       body = Value(body),
       createdAt = Value(createdAt);
  static Insertable<NotificationRow> custom({
    Expression<String>? id,
    Expression<String>? storeId,
    Expression<String>? kind,
    Expression<String>? title,
    Expression<String>? body,
    Expression<DateTime>? createdAt,
    Expression<bool>? isRead,
    Expression<String>? relatedItemId,
    Expression<String>? relatedSupplierId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (storeId != null) 'store_id': storeId,
      if (kind != null) 'kind': kind,
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (createdAt != null) 'created_at': createdAt,
      if (isRead != null) 'is_read': isRead,
      if (relatedItemId != null) 'related_item_id': relatedItemId,
      if (relatedSupplierId != null) 'related_supplier_id': relatedSupplierId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NotificationsCompanion copyWith({
    Value<String>? id,
    Value<String>? storeId,
    Value<NotificationKind>? kind,
    Value<String>? title,
    Value<String>? body,
    Value<DateTime>? createdAt,
    Value<bool>? isRead,
    Value<String?>? relatedItemId,
    Value<String?>? relatedSupplierId,
    Value<int>? rowid,
  }) {
    return NotificationsCompanion(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      relatedItemId: relatedItemId ?? this.relatedItemId,
      relatedSupplierId: relatedSupplierId ?? this.relatedSupplierId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (storeId.present) {
      map['store_id'] = Variable<String>(storeId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
        $NotificationsTable.$converterkind.toSql(kind.value),
      );
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (isRead.present) {
      map['is_read'] = Variable<bool>(isRead.value);
    }
    if (relatedItemId.present) {
      map['related_item_id'] = Variable<String>(relatedItemId.value);
    }
    if (relatedSupplierId.present) {
      map['related_supplier_id'] = Variable<String>(relatedSupplierId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotificationsCompanion(')
          ..write('id: $id, ')
          ..write('storeId: $storeId, ')
          ..write('kind: $kind, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('createdAt: $createdAt, ')
          ..write('isRead: $isRead, ')
          ..write('relatedItemId: $relatedItemId, ')
          ..write('relatedSupplierId: $relatedSupplierId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EmployeesTable extends Employees
    with TableInfo<$EmployeesTable, EmployeeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EmployeesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 64,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _storeIdMeta = const VerificationMeta(
    'storeId',
  );
  @override
  late final GeneratedColumn<String> storeId = GeneratedColumn<String>(
    'store_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES stores (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _firstNameMeta = const VerificationMeta(
    'firstName',
  );
  @override
  late final GeneratedColumn<String> firstName = GeneratedColumn<String>(
    'first_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastNameMeta = const VerificationMeta(
    'lastName',
  );
  @override
  late final GeneratedColumn<String> lastName = GeneratedColumn<String>(
    'last_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cinMeta = const VerificationMeta('cin');
  @override
  late final GeneratedColumn<String> cin = GeneratedColumn<String>(
    'cin',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _photoAssetMeta = const VerificationMeta(
    'photoAsset',
  );
  @override
  late final GeneratedColumn<String> photoAsset = GeneratedColumn<String>(
    'photo_asset',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hireDateMeta = const VerificationMeta(
    'hireDate',
  );
  @override
  late final GeneratedColumn<DateTime> hireDate = GeneratedColumn<DateTime>(
    'hire_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<EmployeeRole, String> role =
      GeneratedColumn<String>(
        'role',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<EmployeeRole>($EmployeesTable.$converterrole);
  @override
  late final GeneratedColumnWithTypeConverter<ContractType, String>
  contractType = GeneratedColumn<String>(
    'contract_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<ContractType>($EmployeesTable.$convertercontractType);
  static const VerificationMeta _payMeta = const VerificationMeta('pay');
  @override
  late final GeneratedColumn<double> pay = GeneratedColumn<double>(
    'pay',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scheduledStartMinutesMeta =
      const VerificationMeta('scheduledStartMinutes');
  @override
  late final GeneratedColumn<int> scheduledStartMinutes = GeneratedColumn<int>(
    'scheduled_start_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scheduledEndMinutesMeta =
      const VerificationMeta('scheduledEndMinutes');
  @override
  late final GeneratedColumn<int> scheduledEndMinutes = GeneratedColumn<int>(
    'scheduled_end_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
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
  static const VerificationMeta _archivedAtMeta = const VerificationMeta(
    'archivedAt',
  );
  @override
  late final GeneratedColumn<DateTime> archivedAt = GeneratedColumn<DateTime>(
    'archived_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    storeId,
    firstName,
    lastName,
    cin,
    phone,
    email,
    photoAsset,
    hireDate,
    role,
    contractType,
    pay,
    scheduledStartMinutes,
    scheduledEndMinutes,
    createdAt,
    archivedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'employees';
  @override
  VerificationContext validateIntegrity(
    Insertable<EmployeeRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('store_id')) {
      context.handle(
        _storeIdMeta,
        storeId.isAcceptableOrUnknown(data['store_id']!, _storeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_storeIdMeta);
    }
    if (data.containsKey('first_name')) {
      context.handle(
        _firstNameMeta,
        firstName.isAcceptableOrUnknown(data['first_name']!, _firstNameMeta),
      );
    } else if (isInserting) {
      context.missing(_firstNameMeta);
    }
    if (data.containsKey('last_name')) {
      context.handle(
        _lastNameMeta,
        lastName.isAcceptableOrUnknown(data['last_name']!, _lastNameMeta),
      );
    } else if (isInserting) {
      context.missing(_lastNameMeta);
    }
    if (data.containsKey('cin')) {
      context.handle(
        _cinMeta,
        cin.isAcceptableOrUnknown(data['cin']!, _cinMeta),
      );
    } else if (isInserting) {
      context.missing(_cinMeta);
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    } else if (isInserting) {
      context.missing(_phoneMeta);
    }
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    } else if (isInserting) {
      context.missing(_emailMeta);
    }
    if (data.containsKey('photo_asset')) {
      context.handle(
        _photoAssetMeta,
        photoAsset.isAcceptableOrUnknown(data['photo_asset']!, _photoAssetMeta),
      );
    }
    if (data.containsKey('hire_date')) {
      context.handle(
        _hireDateMeta,
        hireDate.isAcceptableOrUnknown(data['hire_date']!, _hireDateMeta),
      );
    } else if (isInserting) {
      context.missing(_hireDateMeta);
    }
    if (data.containsKey('pay')) {
      context.handle(
        _payMeta,
        pay.isAcceptableOrUnknown(data['pay']!, _payMeta),
      );
    } else if (isInserting) {
      context.missing(_payMeta);
    }
    if (data.containsKey('scheduled_start_minutes')) {
      context.handle(
        _scheduledStartMinutesMeta,
        scheduledStartMinutes.isAcceptableOrUnknown(
          data['scheduled_start_minutes']!,
          _scheduledStartMinutesMeta,
        ),
      );
    }
    if (data.containsKey('scheduled_end_minutes')) {
      context.handle(
        _scheduledEndMinutesMeta,
        scheduledEndMinutes.isAcceptableOrUnknown(
          data['scheduled_end_minutes']!,
          _scheduledEndMinutesMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('archived_at')) {
      context.handle(
        _archivedAtMeta,
        archivedAt.isAcceptableOrUnknown(data['archived_at']!, _archivedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EmployeeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EmployeeRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      storeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}store_id'],
      )!,
      firstName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}first_name'],
      )!,
      lastName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_name'],
      )!,
      cin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cin'],
      )!,
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      )!,
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      )!,
      photoAsset: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}photo_asset'],
      ),
      hireDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}hire_date'],
      )!,
      role: $EmployeesTable.$converterrole.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}role'],
        )!,
      ),
      contractType: $EmployeesTable.$convertercontractType.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}contract_type'],
        )!,
      ),
      pay: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}pay'],
      )!,
      scheduledStartMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}scheduled_start_minutes'],
      ),
      scheduledEndMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}scheduled_end_minutes'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      archivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}archived_at'],
      ),
    );
  }

  @override
  $EmployeesTable createAlias(String alias) {
    return $EmployeesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<EmployeeRole, String, String> $converterrole =
      const EnumNameConverter<EmployeeRole>(EmployeeRole.values);
  static JsonTypeConverter2<ContractType, String, String>
  $convertercontractType = const EnumNameConverter<ContractType>(
    ContractType.values,
  );
}

class EmployeeRow extends DataClass implements Insertable<EmployeeRow> {
  final String id;

  /// `RESTRICT` — an establishment with staff on file cannot be deleted. The
  /// domain has no flow that would need to; the constraint makes the absence a
  /// fact rather than a gap.
  final String storeId;
  final String firstName;
  final String lastName;

  /// Carte d'identité nationale — the identity document, and the login
  /// identifier (Phase 6). Unique across the whole account, not per store; the
  /// index above makes that a constraint, and the repository keeps its own
  /// check for the message the form shows.
  final String cin;
  final String phone;

  /// Unique across the whole account.
  final String email;

  /// Mocked, like `stores.imageAsset`: a nullable path with no picker behind it.
  final String? photoAsset;
  final DateTime hireDate;
  final EmployeeRole role;
  final ContractType contractType;

  /// Monthly EUR when `fixed`, EUR per hour when `extra` — read per
  /// [contractType].
  final double pay;

  /// Minutes since midnight for this person's own start / end of day. Null means
  /// "use the establishment's opening hours" — the resolved schedule is what
  /// lateness and overtime are measured against. Stored as an int, not a
  /// `DateTime`: these are times of day, not instants.
  final int? scheduledStartMinutes;
  final int? scheduledEndMinutes;
  final DateTime createdAt;

  /// Null while active. The only form of removal — there is no hard delete.
  final DateTime? archivedAt;
  const EmployeeRow({
    required this.id,
    required this.storeId,
    required this.firstName,
    required this.lastName,
    required this.cin,
    required this.phone,
    required this.email,
    this.photoAsset,
    required this.hireDate,
    required this.role,
    required this.contractType,
    required this.pay,
    this.scheduledStartMinutes,
    this.scheduledEndMinutes,
    required this.createdAt,
    this.archivedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['store_id'] = Variable<String>(storeId);
    map['first_name'] = Variable<String>(firstName);
    map['last_name'] = Variable<String>(lastName);
    map['cin'] = Variable<String>(cin);
    map['phone'] = Variable<String>(phone);
    map['email'] = Variable<String>(email);
    if (!nullToAbsent || photoAsset != null) {
      map['photo_asset'] = Variable<String>(photoAsset);
    }
    map['hire_date'] = Variable<DateTime>(hireDate);
    {
      map['role'] = Variable<String>(
        $EmployeesTable.$converterrole.toSql(role),
      );
    }
    {
      map['contract_type'] = Variable<String>(
        $EmployeesTable.$convertercontractType.toSql(contractType),
      );
    }
    map['pay'] = Variable<double>(pay);
    if (!nullToAbsent || scheduledStartMinutes != null) {
      map['scheduled_start_minutes'] = Variable<int>(scheduledStartMinutes);
    }
    if (!nullToAbsent || scheduledEndMinutes != null) {
      map['scheduled_end_minutes'] = Variable<int>(scheduledEndMinutes);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<DateTime>(archivedAt);
    }
    return map;
  }

  EmployeesCompanion toCompanion(bool nullToAbsent) {
    return EmployeesCompanion(
      id: Value(id),
      storeId: Value(storeId),
      firstName: Value(firstName),
      lastName: Value(lastName),
      cin: Value(cin),
      phone: Value(phone),
      email: Value(email),
      photoAsset: photoAsset == null && nullToAbsent
          ? const Value.absent()
          : Value(photoAsset),
      hireDate: Value(hireDate),
      role: Value(role),
      contractType: Value(contractType),
      pay: Value(pay),
      scheduledStartMinutes: scheduledStartMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(scheduledStartMinutes),
      scheduledEndMinutes: scheduledEndMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(scheduledEndMinutes),
      createdAt: Value(createdAt),
      archivedAt: archivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAt),
    );
  }

  factory EmployeeRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EmployeeRow(
      id: serializer.fromJson<String>(json['id']),
      storeId: serializer.fromJson<String>(json['storeId']),
      firstName: serializer.fromJson<String>(json['firstName']),
      lastName: serializer.fromJson<String>(json['lastName']),
      cin: serializer.fromJson<String>(json['cin']),
      phone: serializer.fromJson<String>(json['phone']),
      email: serializer.fromJson<String>(json['email']),
      photoAsset: serializer.fromJson<String?>(json['photoAsset']),
      hireDate: serializer.fromJson<DateTime>(json['hireDate']),
      role: $EmployeesTable.$converterrole.fromJson(
        serializer.fromJson<String>(json['role']),
      ),
      contractType: $EmployeesTable.$convertercontractType.fromJson(
        serializer.fromJson<String>(json['contractType']),
      ),
      pay: serializer.fromJson<double>(json['pay']),
      scheduledStartMinutes: serializer.fromJson<int?>(
        json['scheduledStartMinutes'],
      ),
      scheduledEndMinutes: serializer.fromJson<int?>(
        json['scheduledEndMinutes'],
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      archivedAt: serializer.fromJson<DateTime?>(json['archivedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'storeId': serializer.toJson<String>(storeId),
      'firstName': serializer.toJson<String>(firstName),
      'lastName': serializer.toJson<String>(lastName),
      'cin': serializer.toJson<String>(cin),
      'phone': serializer.toJson<String>(phone),
      'email': serializer.toJson<String>(email),
      'photoAsset': serializer.toJson<String?>(photoAsset),
      'hireDate': serializer.toJson<DateTime>(hireDate),
      'role': serializer.toJson<String>(
        $EmployeesTable.$converterrole.toJson(role),
      ),
      'contractType': serializer.toJson<String>(
        $EmployeesTable.$convertercontractType.toJson(contractType),
      ),
      'pay': serializer.toJson<double>(pay),
      'scheduledStartMinutes': serializer.toJson<int?>(scheduledStartMinutes),
      'scheduledEndMinutes': serializer.toJson<int?>(scheduledEndMinutes),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'archivedAt': serializer.toJson<DateTime?>(archivedAt),
    };
  }

  EmployeeRow copyWith({
    String? id,
    String? storeId,
    String? firstName,
    String? lastName,
    String? cin,
    String? phone,
    String? email,
    Value<String?> photoAsset = const Value.absent(),
    DateTime? hireDate,
    EmployeeRole? role,
    ContractType? contractType,
    double? pay,
    Value<int?> scheduledStartMinutes = const Value.absent(),
    Value<int?> scheduledEndMinutes = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> archivedAt = const Value.absent(),
  }) => EmployeeRow(
    id: id ?? this.id,
    storeId: storeId ?? this.storeId,
    firstName: firstName ?? this.firstName,
    lastName: lastName ?? this.lastName,
    cin: cin ?? this.cin,
    phone: phone ?? this.phone,
    email: email ?? this.email,
    photoAsset: photoAsset.present ? photoAsset.value : this.photoAsset,
    hireDate: hireDate ?? this.hireDate,
    role: role ?? this.role,
    contractType: contractType ?? this.contractType,
    pay: pay ?? this.pay,
    scheduledStartMinutes: scheduledStartMinutes.present
        ? scheduledStartMinutes.value
        : this.scheduledStartMinutes,
    scheduledEndMinutes: scheduledEndMinutes.present
        ? scheduledEndMinutes.value
        : this.scheduledEndMinutes,
    createdAt: createdAt ?? this.createdAt,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
  );
  EmployeeRow copyWithCompanion(EmployeesCompanion data) {
    return EmployeeRow(
      id: data.id.present ? data.id.value : this.id,
      storeId: data.storeId.present ? data.storeId.value : this.storeId,
      firstName: data.firstName.present ? data.firstName.value : this.firstName,
      lastName: data.lastName.present ? data.lastName.value : this.lastName,
      cin: data.cin.present ? data.cin.value : this.cin,
      phone: data.phone.present ? data.phone.value : this.phone,
      email: data.email.present ? data.email.value : this.email,
      photoAsset: data.photoAsset.present
          ? data.photoAsset.value
          : this.photoAsset,
      hireDate: data.hireDate.present ? data.hireDate.value : this.hireDate,
      role: data.role.present ? data.role.value : this.role,
      contractType: data.contractType.present
          ? data.contractType.value
          : this.contractType,
      pay: data.pay.present ? data.pay.value : this.pay,
      scheduledStartMinutes: data.scheduledStartMinutes.present
          ? data.scheduledStartMinutes.value
          : this.scheduledStartMinutes,
      scheduledEndMinutes: data.scheduledEndMinutes.present
          ? data.scheduledEndMinutes.value
          : this.scheduledEndMinutes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      archivedAt: data.archivedAt.present
          ? data.archivedAt.value
          : this.archivedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EmployeeRow(')
          ..write('id: $id, ')
          ..write('storeId: $storeId, ')
          ..write('firstName: $firstName, ')
          ..write('lastName: $lastName, ')
          ..write('cin: $cin, ')
          ..write('phone: $phone, ')
          ..write('email: $email, ')
          ..write('photoAsset: $photoAsset, ')
          ..write('hireDate: $hireDate, ')
          ..write('role: $role, ')
          ..write('contractType: $contractType, ')
          ..write('pay: $pay, ')
          ..write('scheduledStartMinutes: $scheduledStartMinutes, ')
          ..write('scheduledEndMinutes: $scheduledEndMinutes, ')
          ..write('createdAt: $createdAt, ')
          ..write('archivedAt: $archivedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    storeId,
    firstName,
    lastName,
    cin,
    phone,
    email,
    photoAsset,
    hireDate,
    role,
    contractType,
    pay,
    scheduledStartMinutes,
    scheduledEndMinutes,
    createdAt,
    archivedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EmployeeRow &&
          other.id == this.id &&
          other.storeId == this.storeId &&
          other.firstName == this.firstName &&
          other.lastName == this.lastName &&
          other.cin == this.cin &&
          other.phone == this.phone &&
          other.email == this.email &&
          other.photoAsset == this.photoAsset &&
          other.hireDate == this.hireDate &&
          other.role == this.role &&
          other.contractType == this.contractType &&
          other.pay == this.pay &&
          other.scheduledStartMinutes == this.scheduledStartMinutes &&
          other.scheduledEndMinutes == this.scheduledEndMinutes &&
          other.createdAt == this.createdAt &&
          other.archivedAt == this.archivedAt);
}

class EmployeesCompanion extends UpdateCompanion<EmployeeRow> {
  final Value<String> id;
  final Value<String> storeId;
  final Value<String> firstName;
  final Value<String> lastName;
  final Value<String> cin;
  final Value<String> phone;
  final Value<String> email;
  final Value<String?> photoAsset;
  final Value<DateTime> hireDate;
  final Value<EmployeeRole> role;
  final Value<ContractType> contractType;
  final Value<double> pay;
  final Value<int?> scheduledStartMinutes;
  final Value<int?> scheduledEndMinutes;
  final Value<DateTime> createdAt;
  final Value<DateTime?> archivedAt;
  final Value<int> rowid;
  const EmployeesCompanion({
    this.id = const Value.absent(),
    this.storeId = const Value.absent(),
    this.firstName = const Value.absent(),
    this.lastName = const Value.absent(),
    this.cin = const Value.absent(),
    this.phone = const Value.absent(),
    this.email = const Value.absent(),
    this.photoAsset = const Value.absent(),
    this.hireDate = const Value.absent(),
    this.role = const Value.absent(),
    this.contractType = const Value.absent(),
    this.pay = const Value.absent(),
    this.scheduledStartMinutes = const Value.absent(),
    this.scheduledEndMinutes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EmployeesCompanion.insert({
    required String id,
    required String storeId,
    required String firstName,
    required String lastName,
    required String cin,
    required String phone,
    required String email,
    this.photoAsset = const Value.absent(),
    required DateTime hireDate,
    required EmployeeRole role,
    required ContractType contractType,
    required double pay,
    this.scheduledStartMinutes = const Value.absent(),
    this.scheduledEndMinutes = const Value.absent(),
    required DateTime createdAt,
    this.archivedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       storeId = Value(storeId),
       firstName = Value(firstName),
       lastName = Value(lastName),
       cin = Value(cin),
       phone = Value(phone),
       email = Value(email),
       hireDate = Value(hireDate),
       role = Value(role),
       contractType = Value(contractType),
       pay = Value(pay),
       createdAt = Value(createdAt);
  static Insertable<EmployeeRow> custom({
    Expression<String>? id,
    Expression<String>? storeId,
    Expression<String>? firstName,
    Expression<String>? lastName,
    Expression<String>? cin,
    Expression<String>? phone,
    Expression<String>? email,
    Expression<String>? photoAsset,
    Expression<DateTime>? hireDate,
    Expression<String>? role,
    Expression<String>? contractType,
    Expression<double>? pay,
    Expression<int>? scheduledStartMinutes,
    Expression<int>? scheduledEndMinutes,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? archivedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (storeId != null) 'store_id': storeId,
      if (firstName != null) 'first_name': firstName,
      if (lastName != null) 'last_name': lastName,
      if (cin != null) 'cin': cin,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      if (photoAsset != null) 'photo_asset': photoAsset,
      if (hireDate != null) 'hire_date': hireDate,
      if (role != null) 'role': role,
      if (contractType != null) 'contract_type': contractType,
      if (pay != null) 'pay': pay,
      if (scheduledStartMinutes != null)
        'scheduled_start_minutes': scheduledStartMinutes,
      if (scheduledEndMinutes != null)
        'scheduled_end_minutes': scheduledEndMinutes,
      if (createdAt != null) 'created_at': createdAt,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EmployeesCompanion copyWith({
    Value<String>? id,
    Value<String>? storeId,
    Value<String>? firstName,
    Value<String>? lastName,
    Value<String>? cin,
    Value<String>? phone,
    Value<String>? email,
    Value<String?>? photoAsset,
    Value<DateTime>? hireDate,
    Value<EmployeeRole>? role,
    Value<ContractType>? contractType,
    Value<double>? pay,
    Value<int?>? scheduledStartMinutes,
    Value<int?>? scheduledEndMinutes,
    Value<DateTime>? createdAt,
    Value<DateTime?>? archivedAt,
    Value<int>? rowid,
  }) {
    return EmployeesCompanion(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      cin: cin ?? this.cin,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      photoAsset: photoAsset ?? this.photoAsset,
      hireDate: hireDate ?? this.hireDate,
      role: role ?? this.role,
      contractType: contractType ?? this.contractType,
      pay: pay ?? this.pay,
      scheduledStartMinutes:
          scheduledStartMinutes ?? this.scheduledStartMinutes,
      scheduledEndMinutes: scheduledEndMinutes ?? this.scheduledEndMinutes,
      createdAt: createdAt ?? this.createdAt,
      archivedAt: archivedAt ?? this.archivedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (storeId.present) {
      map['store_id'] = Variable<String>(storeId.value);
    }
    if (firstName.present) {
      map['first_name'] = Variable<String>(firstName.value);
    }
    if (lastName.present) {
      map['last_name'] = Variable<String>(lastName.value);
    }
    if (cin.present) {
      map['cin'] = Variable<String>(cin.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (photoAsset.present) {
      map['photo_asset'] = Variable<String>(photoAsset.value);
    }
    if (hireDate.present) {
      map['hire_date'] = Variable<DateTime>(hireDate.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(
        $EmployeesTable.$converterrole.toSql(role.value),
      );
    }
    if (contractType.present) {
      map['contract_type'] = Variable<String>(
        $EmployeesTable.$convertercontractType.toSql(contractType.value),
      );
    }
    if (pay.present) {
      map['pay'] = Variable<double>(pay.value);
    }
    if (scheduledStartMinutes.present) {
      map['scheduled_start_minutes'] = Variable<int>(
        scheduledStartMinutes.value,
      );
    }
    if (scheduledEndMinutes.present) {
      map['scheduled_end_minutes'] = Variable<int>(scheduledEndMinutes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<DateTime>(archivedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EmployeesCompanion(')
          ..write('id: $id, ')
          ..write('storeId: $storeId, ')
          ..write('firstName: $firstName, ')
          ..write('lastName: $lastName, ')
          ..write('cin: $cin, ')
          ..write('phone: $phone, ')
          ..write('email: $email, ')
          ..write('photoAsset: $photoAsset, ')
          ..write('hireDate: $hireDate, ')
          ..write('role: $role, ')
          ..write('contractType: $contractType, ')
          ..write('pay: $pay, ')
          ..write('scheduledStartMinutes: $scheduledStartMinutes, ')
          ..write('scheduledEndMinutes: $scheduledEndMinutes, ')
          ..write('createdAt: $createdAt, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EmployeeCredentialsTable extends EmployeeCredentials
    with TableInfo<$EmployeeCredentialsTable, EmployeeCredentialRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EmployeeCredentialsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 64,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _employeeIdMeta = const VerificationMeta(
    'employeeId',
  );
  @override
  late final GeneratedColumn<String> employeeId = GeneratedColumn<String>(
    'employee_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES employees (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _pinHashMeta = const VerificationMeta(
    'pinHash',
  );
  @override
  late final GeneratedColumn<String> pinHash = GeneratedColumn<String>(
    'pin_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _failedAttemptsMeta = const VerificationMeta(
    'failedAttempts',
  );
  @override
  late final GeneratedColumn<int> failedAttempts = GeneratedColumn<int>(
    'failed_attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lockedUntilMeta = const VerificationMeta(
    'lockedUntil',
  );
  @override
  late final GeneratedColumn<DateTime> lockedUntil = GeneratedColumn<DateTime>(
    'locked_until',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastLoginAtMeta = const VerificationMeta(
    'lastLoginAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastLoginAt = GeneratedColumn<DateTime>(
    'last_login_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    employeeId,
    pinHash,
    failedAttempts,
    lockedUntil,
    lastLoginAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'employee_credentials';
  @override
  VerificationContext validateIntegrity(
    Insertable<EmployeeCredentialRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('employee_id')) {
      context.handle(
        _employeeIdMeta,
        employeeId.isAcceptableOrUnknown(data['employee_id']!, _employeeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_employeeIdMeta);
    }
    if (data.containsKey('pin_hash')) {
      context.handle(
        _pinHashMeta,
        pinHash.isAcceptableOrUnknown(data['pin_hash']!, _pinHashMeta),
      );
    } else if (isInserting) {
      context.missing(_pinHashMeta);
    }
    if (data.containsKey('failed_attempts')) {
      context.handle(
        _failedAttemptsMeta,
        failedAttempts.isAcceptableOrUnknown(
          data['failed_attempts']!,
          _failedAttemptsMeta,
        ),
      );
    }
    if (data.containsKey('locked_until')) {
      context.handle(
        _lockedUntilMeta,
        lockedUntil.isAcceptableOrUnknown(
          data['locked_until']!,
          _lockedUntilMeta,
        ),
      );
    }
    if (data.containsKey('last_login_at')) {
      context.handle(
        _lastLoginAtMeta,
        lastLoginAt.isAcceptableOrUnknown(
          data['last_login_at']!,
          _lastLoginAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EmployeeCredentialRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EmployeeCredentialRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      employeeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}employee_id'],
      )!,
      pinHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pin_hash'],
      )!,
      failedAttempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}failed_attempts'],
      )!,
      lockedUntil: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}locked_until'],
      ),
      lastLoginAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_login_at'],
      ),
    );
  }

  @override
  $EmployeeCredentialsTable createAlias(String alias) {
    return $EmployeeCredentialsTable(attachedDatabase, alias);
  }
}

class EmployeeCredentialRow extends DataClass
    implements Insertable<EmployeeCredentialRow> {
  final String id;

  /// `ON DELETE CASCADE` and unique — one credential per employee, and it goes
  /// when they do.
  final String employeeId;
  final String pinHash;
  final int failedAttempts;
  final DateTime? lockedUntil;
  final DateTime? lastLoginAt;
  const EmployeeCredentialRow({
    required this.id,
    required this.employeeId,
    required this.pinHash,
    required this.failedAttempts,
    this.lockedUntil,
    this.lastLoginAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['employee_id'] = Variable<String>(employeeId);
    map['pin_hash'] = Variable<String>(pinHash);
    map['failed_attempts'] = Variable<int>(failedAttempts);
    if (!nullToAbsent || lockedUntil != null) {
      map['locked_until'] = Variable<DateTime>(lockedUntil);
    }
    if (!nullToAbsent || lastLoginAt != null) {
      map['last_login_at'] = Variable<DateTime>(lastLoginAt);
    }
    return map;
  }

  EmployeeCredentialsCompanion toCompanion(bool nullToAbsent) {
    return EmployeeCredentialsCompanion(
      id: Value(id),
      employeeId: Value(employeeId),
      pinHash: Value(pinHash),
      failedAttempts: Value(failedAttempts),
      lockedUntil: lockedUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(lockedUntil),
      lastLoginAt: lastLoginAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastLoginAt),
    );
  }

  factory EmployeeCredentialRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EmployeeCredentialRow(
      id: serializer.fromJson<String>(json['id']),
      employeeId: serializer.fromJson<String>(json['employeeId']),
      pinHash: serializer.fromJson<String>(json['pinHash']),
      failedAttempts: serializer.fromJson<int>(json['failedAttempts']),
      lockedUntil: serializer.fromJson<DateTime?>(json['lockedUntil']),
      lastLoginAt: serializer.fromJson<DateTime?>(json['lastLoginAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'employeeId': serializer.toJson<String>(employeeId),
      'pinHash': serializer.toJson<String>(pinHash),
      'failedAttempts': serializer.toJson<int>(failedAttempts),
      'lockedUntil': serializer.toJson<DateTime?>(lockedUntil),
      'lastLoginAt': serializer.toJson<DateTime?>(lastLoginAt),
    };
  }

  EmployeeCredentialRow copyWith({
    String? id,
    String? employeeId,
    String? pinHash,
    int? failedAttempts,
    Value<DateTime?> lockedUntil = const Value.absent(),
    Value<DateTime?> lastLoginAt = const Value.absent(),
  }) => EmployeeCredentialRow(
    id: id ?? this.id,
    employeeId: employeeId ?? this.employeeId,
    pinHash: pinHash ?? this.pinHash,
    failedAttempts: failedAttempts ?? this.failedAttempts,
    lockedUntil: lockedUntil.present ? lockedUntil.value : this.lockedUntil,
    lastLoginAt: lastLoginAt.present ? lastLoginAt.value : this.lastLoginAt,
  );
  EmployeeCredentialRow copyWithCompanion(EmployeeCredentialsCompanion data) {
    return EmployeeCredentialRow(
      id: data.id.present ? data.id.value : this.id,
      employeeId: data.employeeId.present
          ? data.employeeId.value
          : this.employeeId,
      pinHash: data.pinHash.present ? data.pinHash.value : this.pinHash,
      failedAttempts: data.failedAttempts.present
          ? data.failedAttempts.value
          : this.failedAttempts,
      lockedUntil: data.lockedUntil.present
          ? data.lockedUntil.value
          : this.lockedUntil,
      lastLoginAt: data.lastLoginAt.present
          ? data.lastLoginAt.value
          : this.lastLoginAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EmployeeCredentialRow(')
          ..write('id: $id, ')
          ..write('employeeId: $employeeId, ')
          ..write('pinHash: $pinHash, ')
          ..write('failedAttempts: $failedAttempts, ')
          ..write('lockedUntil: $lockedUntil, ')
          ..write('lastLoginAt: $lastLoginAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    employeeId,
    pinHash,
    failedAttempts,
    lockedUntil,
    lastLoginAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EmployeeCredentialRow &&
          other.id == this.id &&
          other.employeeId == this.employeeId &&
          other.pinHash == this.pinHash &&
          other.failedAttempts == this.failedAttempts &&
          other.lockedUntil == this.lockedUntil &&
          other.lastLoginAt == this.lastLoginAt);
}

class EmployeeCredentialsCompanion
    extends UpdateCompanion<EmployeeCredentialRow> {
  final Value<String> id;
  final Value<String> employeeId;
  final Value<String> pinHash;
  final Value<int> failedAttempts;
  final Value<DateTime?> lockedUntil;
  final Value<DateTime?> lastLoginAt;
  final Value<int> rowid;
  const EmployeeCredentialsCompanion({
    this.id = const Value.absent(),
    this.employeeId = const Value.absent(),
    this.pinHash = const Value.absent(),
    this.failedAttempts = const Value.absent(),
    this.lockedUntil = const Value.absent(),
    this.lastLoginAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EmployeeCredentialsCompanion.insert({
    required String id,
    required String employeeId,
    required String pinHash,
    this.failedAttempts = const Value.absent(),
    this.lockedUntil = const Value.absent(),
    this.lastLoginAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       employeeId = Value(employeeId),
       pinHash = Value(pinHash);
  static Insertable<EmployeeCredentialRow> custom({
    Expression<String>? id,
    Expression<String>? employeeId,
    Expression<String>? pinHash,
    Expression<int>? failedAttempts,
    Expression<DateTime>? lockedUntil,
    Expression<DateTime>? lastLoginAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (employeeId != null) 'employee_id': employeeId,
      if (pinHash != null) 'pin_hash': pinHash,
      if (failedAttempts != null) 'failed_attempts': failedAttempts,
      if (lockedUntil != null) 'locked_until': lockedUntil,
      if (lastLoginAt != null) 'last_login_at': lastLoginAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EmployeeCredentialsCompanion copyWith({
    Value<String>? id,
    Value<String>? employeeId,
    Value<String>? pinHash,
    Value<int>? failedAttempts,
    Value<DateTime?>? lockedUntil,
    Value<DateTime?>? lastLoginAt,
    Value<int>? rowid,
  }) {
    return EmployeeCredentialsCompanion(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      pinHash: pinHash ?? this.pinHash,
      failedAttempts: failedAttempts ?? this.failedAttempts,
      lockedUntil: lockedUntil ?? this.lockedUntil,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (employeeId.present) {
      map['employee_id'] = Variable<String>(employeeId.value);
    }
    if (pinHash.present) {
      map['pin_hash'] = Variable<String>(pinHash.value);
    }
    if (failedAttempts.present) {
      map['failed_attempts'] = Variable<int>(failedAttempts.value);
    }
    if (lockedUntil.present) {
      map['locked_until'] = Variable<DateTime>(lockedUntil.value);
    }
    if (lastLoginAt.present) {
      map['last_login_at'] = Variable<DateTime>(lastLoginAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EmployeeCredentialsCompanion(')
          ..write('id: $id, ')
          ..write('employeeId: $employeeId, ')
          ..write('pinHash: $pinHash, ')
          ..write('failedAttempts: $failedAttempts, ')
          ..write('lockedUntil: $lockedUntil, ')
          ..write('lastLoginAt: $lastLoginAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PayrollPeriodsTable extends PayrollPeriods
    with TableInfo<$PayrollPeriodsTable, PayrollPeriodRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PayrollPeriodsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 64,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _employeeIdMeta = const VerificationMeta(
    'employeeId',
  );
  @override
  late final GeneratedColumn<String> employeeId = GeneratedColumn<String>(
    'employee_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES employees (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _storeIdMeta = const VerificationMeta(
    'storeId',
  );
  @override
  late final GeneratedColumn<String> storeId = GeneratedColumn<String>(
    'store_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES stores (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  @override
  late final GeneratedColumn<DateTime> startDate = GeneratedColumn<DateTime>(
    'start_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endDateMeta = const VerificationMeta(
    'endDate',
  );
  @override
  late final GeneratedColumn<DateTime> endDate = GeneratedColumn<DateTime>(
    'end_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _workedDaysMeta = const VerificationMeta(
    'workedDays',
  );
  @override
  late final GeneratedColumn<int> workedDays = GeneratedColumn<int>(
    'worked_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalWorkedHoursMeta = const VerificationMeta(
    'totalWorkedHours',
  );
  @override
  late final GeneratedColumn<double> totalWorkedHours = GeneratedColumn<double>(
    'total_worked_hours',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalOvertimeHoursMeta =
      const VerificationMeta('totalOvertimeHours');
  @override
  late final GeneratedColumn<double> totalOvertimeHours =
      GeneratedColumn<double>(
        'total_overtime_hours',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _appliedRateMeta = const VerificationMeta(
    'appliedRate',
  );
  @override
  late final GeneratedColumn<double> appliedRate = GeneratedColumn<double>(
    'applied_rate',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _computedAmountMeta = const VerificationMeta(
    'computedAmount',
  );
  @override
  late final GeneratedColumn<double> computedAmount = GeneratedColumn<double>(
    'computed_amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<PayrollStatus, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<PayrollStatus>($PayrollPeriodsTable.$converterstatus);
  static const VerificationMeta _paidByEmployeeIdMeta = const VerificationMeta(
    'paidByEmployeeId',
  );
  @override
  late final GeneratedColumn<String> paidByEmployeeId = GeneratedColumn<String>(
    'paid_by_employee_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _paidAtMeta = const VerificationMeta('paidAt');
  @override
  late final GeneratedColumn<DateTime> paidAt = GeneratedColumn<DateTime>(
    'paid_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
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
    employeeId,
    storeId,
    startDate,
    endDate,
    workedDays,
    totalWorkedHours,
    totalOvertimeHours,
    appliedRate,
    computedAmount,
    status,
    paidByEmployeeId,
    paidAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'payroll_periods';
  @override
  VerificationContext validateIntegrity(
    Insertable<PayrollPeriodRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('employee_id')) {
      context.handle(
        _employeeIdMeta,
        employeeId.isAcceptableOrUnknown(data['employee_id']!, _employeeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_employeeIdMeta);
    }
    if (data.containsKey('store_id')) {
      context.handle(
        _storeIdMeta,
        storeId.isAcceptableOrUnknown(data['store_id']!, _storeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_storeIdMeta);
    }
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    } else if (isInserting) {
      context.missing(_startDateMeta);
    }
    if (data.containsKey('end_date')) {
      context.handle(
        _endDateMeta,
        endDate.isAcceptableOrUnknown(data['end_date']!, _endDateMeta),
      );
    } else if (isInserting) {
      context.missing(_endDateMeta);
    }
    if (data.containsKey('worked_days')) {
      context.handle(
        _workedDaysMeta,
        workedDays.isAcceptableOrUnknown(data['worked_days']!, _workedDaysMeta),
      );
    } else if (isInserting) {
      context.missing(_workedDaysMeta);
    }
    if (data.containsKey('total_worked_hours')) {
      context.handle(
        _totalWorkedHoursMeta,
        totalWorkedHours.isAcceptableOrUnknown(
          data['total_worked_hours']!,
          _totalWorkedHoursMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_totalWorkedHoursMeta);
    }
    if (data.containsKey('total_overtime_hours')) {
      context.handle(
        _totalOvertimeHoursMeta,
        totalOvertimeHours.isAcceptableOrUnknown(
          data['total_overtime_hours']!,
          _totalOvertimeHoursMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_totalOvertimeHoursMeta);
    }
    if (data.containsKey('applied_rate')) {
      context.handle(
        _appliedRateMeta,
        appliedRate.isAcceptableOrUnknown(
          data['applied_rate']!,
          _appliedRateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_appliedRateMeta);
    }
    if (data.containsKey('computed_amount')) {
      context.handle(
        _computedAmountMeta,
        computedAmount.isAcceptableOrUnknown(
          data['computed_amount']!,
          _computedAmountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_computedAmountMeta);
    }
    if (data.containsKey('paid_by_employee_id')) {
      context.handle(
        _paidByEmployeeIdMeta,
        paidByEmployeeId.isAcceptableOrUnknown(
          data['paid_by_employee_id']!,
          _paidByEmployeeIdMeta,
        ),
      );
    }
    if (data.containsKey('paid_at')) {
      context.handle(
        _paidAtMeta,
        paidAt.isAcceptableOrUnknown(data['paid_at']!, _paidAtMeta),
      );
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
  PayrollPeriodRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PayrollPeriodRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      employeeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}employee_id'],
      )!,
      storeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}store_id'],
      )!,
      startDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_date'],
      )!,
      endDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}end_date'],
      )!,
      workedDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}worked_days'],
      )!,
      totalWorkedHours: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}total_worked_hours'],
      )!,
      totalOvertimeHours: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}total_overtime_hours'],
      )!,
      appliedRate: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}applied_rate'],
      )!,
      computedAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}computed_amount'],
      )!,
      status: $PayrollPeriodsTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      paidByEmployeeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}paid_by_employee_id'],
      ),
      paidAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}paid_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $PayrollPeriodsTable createAlias(String alias) {
    return $PayrollPeriodsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<PayrollStatus, String, String> $converterstatus =
      const EnumNameConverter<PayrollStatus>(PayrollStatus.values);
}

class PayrollPeriodRow extends DataClass
    implements Insertable<PayrollPeriodRow> {
  final String id;
  final String employeeId;
  final String storeId;

  /// First and last work day this run covered (midnight-normalised).
  final DateTime startDate;
  final DateTime endDate;
  final int workedDays;
  final double totalWorkedHours;
  final double totalOvertimeHours;

  /// Snapshot of the employee's pay (monthly EUR for `fixed`, EUR/h for
  /// `extra`) at pay time — a later raise cannot rewrite history.
  final double appliedRate;
  final double computedAmount;
  final PayrollStatus status;

  /// The owner who validated the run. **No foreign key** — they may later be
  /// archived, and the row keeps their id to render their name, the same
  /// pattern as `stock_movements.supplierId`.
  final String? paidByEmployeeId;
  final DateTime? paidAt;
  final DateTime createdAt;
  const PayrollPeriodRow({
    required this.id,
    required this.employeeId,
    required this.storeId,
    required this.startDate,
    required this.endDate,
    required this.workedDays,
    required this.totalWorkedHours,
    required this.totalOvertimeHours,
    required this.appliedRate,
    required this.computedAmount,
    required this.status,
    this.paidByEmployeeId,
    this.paidAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['employee_id'] = Variable<String>(employeeId);
    map['store_id'] = Variable<String>(storeId);
    map['start_date'] = Variable<DateTime>(startDate);
    map['end_date'] = Variable<DateTime>(endDate);
    map['worked_days'] = Variable<int>(workedDays);
    map['total_worked_hours'] = Variable<double>(totalWorkedHours);
    map['total_overtime_hours'] = Variable<double>(totalOvertimeHours);
    map['applied_rate'] = Variable<double>(appliedRate);
    map['computed_amount'] = Variable<double>(computedAmount);
    {
      map['status'] = Variable<String>(
        $PayrollPeriodsTable.$converterstatus.toSql(status),
      );
    }
    if (!nullToAbsent || paidByEmployeeId != null) {
      map['paid_by_employee_id'] = Variable<String>(paidByEmployeeId);
    }
    if (!nullToAbsent || paidAt != null) {
      map['paid_at'] = Variable<DateTime>(paidAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PayrollPeriodsCompanion toCompanion(bool nullToAbsent) {
    return PayrollPeriodsCompanion(
      id: Value(id),
      employeeId: Value(employeeId),
      storeId: Value(storeId),
      startDate: Value(startDate),
      endDate: Value(endDate),
      workedDays: Value(workedDays),
      totalWorkedHours: Value(totalWorkedHours),
      totalOvertimeHours: Value(totalOvertimeHours),
      appliedRate: Value(appliedRate),
      computedAmount: Value(computedAmount),
      status: Value(status),
      paidByEmployeeId: paidByEmployeeId == null && nullToAbsent
          ? const Value.absent()
          : Value(paidByEmployeeId),
      paidAt: paidAt == null && nullToAbsent
          ? const Value.absent()
          : Value(paidAt),
      createdAt: Value(createdAt),
    );
  }

  factory PayrollPeriodRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PayrollPeriodRow(
      id: serializer.fromJson<String>(json['id']),
      employeeId: serializer.fromJson<String>(json['employeeId']),
      storeId: serializer.fromJson<String>(json['storeId']),
      startDate: serializer.fromJson<DateTime>(json['startDate']),
      endDate: serializer.fromJson<DateTime>(json['endDate']),
      workedDays: serializer.fromJson<int>(json['workedDays']),
      totalWorkedHours: serializer.fromJson<double>(json['totalWorkedHours']),
      totalOvertimeHours: serializer.fromJson<double>(
        json['totalOvertimeHours'],
      ),
      appliedRate: serializer.fromJson<double>(json['appliedRate']),
      computedAmount: serializer.fromJson<double>(json['computedAmount']),
      status: $PayrollPeriodsTable.$converterstatus.fromJson(
        serializer.fromJson<String>(json['status']),
      ),
      paidByEmployeeId: serializer.fromJson<String?>(json['paidByEmployeeId']),
      paidAt: serializer.fromJson<DateTime?>(json['paidAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'employeeId': serializer.toJson<String>(employeeId),
      'storeId': serializer.toJson<String>(storeId),
      'startDate': serializer.toJson<DateTime>(startDate),
      'endDate': serializer.toJson<DateTime>(endDate),
      'workedDays': serializer.toJson<int>(workedDays),
      'totalWorkedHours': serializer.toJson<double>(totalWorkedHours),
      'totalOvertimeHours': serializer.toJson<double>(totalOvertimeHours),
      'appliedRate': serializer.toJson<double>(appliedRate),
      'computedAmount': serializer.toJson<double>(computedAmount),
      'status': serializer.toJson<String>(
        $PayrollPeriodsTable.$converterstatus.toJson(status),
      ),
      'paidByEmployeeId': serializer.toJson<String?>(paidByEmployeeId),
      'paidAt': serializer.toJson<DateTime?>(paidAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  PayrollPeriodRow copyWith({
    String? id,
    String? employeeId,
    String? storeId,
    DateTime? startDate,
    DateTime? endDate,
    int? workedDays,
    double? totalWorkedHours,
    double? totalOvertimeHours,
    double? appliedRate,
    double? computedAmount,
    PayrollStatus? status,
    Value<String?> paidByEmployeeId = const Value.absent(),
    Value<DateTime?> paidAt = const Value.absent(),
    DateTime? createdAt,
  }) => PayrollPeriodRow(
    id: id ?? this.id,
    employeeId: employeeId ?? this.employeeId,
    storeId: storeId ?? this.storeId,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    workedDays: workedDays ?? this.workedDays,
    totalWorkedHours: totalWorkedHours ?? this.totalWorkedHours,
    totalOvertimeHours: totalOvertimeHours ?? this.totalOvertimeHours,
    appliedRate: appliedRate ?? this.appliedRate,
    computedAmount: computedAmount ?? this.computedAmount,
    status: status ?? this.status,
    paidByEmployeeId: paidByEmployeeId.present
        ? paidByEmployeeId.value
        : this.paidByEmployeeId,
    paidAt: paidAt.present ? paidAt.value : this.paidAt,
    createdAt: createdAt ?? this.createdAt,
  );
  PayrollPeriodRow copyWithCompanion(PayrollPeriodsCompanion data) {
    return PayrollPeriodRow(
      id: data.id.present ? data.id.value : this.id,
      employeeId: data.employeeId.present
          ? data.employeeId.value
          : this.employeeId,
      storeId: data.storeId.present ? data.storeId.value : this.storeId,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      endDate: data.endDate.present ? data.endDate.value : this.endDate,
      workedDays: data.workedDays.present
          ? data.workedDays.value
          : this.workedDays,
      totalWorkedHours: data.totalWorkedHours.present
          ? data.totalWorkedHours.value
          : this.totalWorkedHours,
      totalOvertimeHours: data.totalOvertimeHours.present
          ? data.totalOvertimeHours.value
          : this.totalOvertimeHours,
      appliedRate: data.appliedRate.present
          ? data.appliedRate.value
          : this.appliedRate,
      computedAmount: data.computedAmount.present
          ? data.computedAmount.value
          : this.computedAmount,
      status: data.status.present ? data.status.value : this.status,
      paidByEmployeeId: data.paidByEmployeeId.present
          ? data.paidByEmployeeId.value
          : this.paidByEmployeeId,
      paidAt: data.paidAt.present ? data.paidAt.value : this.paidAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PayrollPeriodRow(')
          ..write('id: $id, ')
          ..write('employeeId: $employeeId, ')
          ..write('storeId: $storeId, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('workedDays: $workedDays, ')
          ..write('totalWorkedHours: $totalWorkedHours, ')
          ..write('totalOvertimeHours: $totalOvertimeHours, ')
          ..write('appliedRate: $appliedRate, ')
          ..write('computedAmount: $computedAmount, ')
          ..write('status: $status, ')
          ..write('paidByEmployeeId: $paidByEmployeeId, ')
          ..write('paidAt: $paidAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    employeeId,
    storeId,
    startDate,
    endDate,
    workedDays,
    totalWorkedHours,
    totalOvertimeHours,
    appliedRate,
    computedAmount,
    status,
    paidByEmployeeId,
    paidAt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PayrollPeriodRow &&
          other.id == this.id &&
          other.employeeId == this.employeeId &&
          other.storeId == this.storeId &&
          other.startDate == this.startDate &&
          other.endDate == this.endDate &&
          other.workedDays == this.workedDays &&
          other.totalWorkedHours == this.totalWorkedHours &&
          other.totalOvertimeHours == this.totalOvertimeHours &&
          other.appliedRate == this.appliedRate &&
          other.computedAmount == this.computedAmount &&
          other.status == this.status &&
          other.paidByEmployeeId == this.paidByEmployeeId &&
          other.paidAt == this.paidAt &&
          other.createdAt == this.createdAt);
}

class PayrollPeriodsCompanion extends UpdateCompanion<PayrollPeriodRow> {
  final Value<String> id;
  final Value<String> employeeId;
  final Value<String> storeId;
  final Value<DateTime> startDate;
  final Value<DateTime> endDate;
  final Value<int> workedDays;
  final Value<double> totalWorkedHours;
  final Value<double> totalOvertimeHours;
  final Value<double> appliedRate;
  final Value<double> computedAmount;
  final Value<PayrollStatus> status;
  final Value<String?> paidByEmployeeId;
  final Value<DateTime?> paidAt;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const PayrollPeriodsCompanion({
    this.id = const Value.absent(),
    this.employeeId = const Value.absent(),
    this.storeId = const Value.absent(),
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
    this.workedDays = const Value.absent(),
    this.totalWorkedHours = const Value.absent(),
    this.totalOvertimeHours = const Value.absent(),
    this.appliedRate = const Value.absent(),
    this.computedAmount = const Value.absent(),
    this.status = const Value.absent(),
    this.paidByEmployeeId = const Value.absent(),
    this.paidAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PayrollPeriodsCompanion.insert({
    required String id,
    required String employeeId,
    required String storeId,
    required DateTime startDate,
    required DateTime endDate,
    required int workedDays,
    required double totalWorkedHours,
    required double totalOvertimeHours,
    required double appliedRate,
    required double computedAmount,
    required PayrollStatus status,
    this.paidByEmployeeId = const Value.absent(),
    this.paidAt = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       employeeId = Value(employeeId),
       storeId = Value(storeId),
       startDate = Value(startDate),
       endDate = Value(endDate),
       workedDays = Value(workedDays),
       totalWorkedHours = Value(totalWorkedHours),
       totalOvertimeHours = Value(totalOvertimeHours),
       appliedRate = Value(appliedRate),
       computedAmount = Value(computedAmount),
       status = Value(status),
       createdAt = Value(createdAt);
  static Insertable<PayrollPeriodRow> custom({
    Expression<String>? id,
    Expression<String>? employeeId,
    Expression<String>? storeId,
    Expression<DateTime>? startDate,
    Expression<DateTime>? endDate,
    Expression<int>? workedDays,
    Expression<double>? totalWorkedHours,
    Expression<double>? totalOvertimeHours,
    Expression<double>? appliedRate,
    Expression<double>? computedAmount,
    Expression<String>? status,
    Expression<String>? paidByEmployeeId,
    Expression<DateTime>? paidAt,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (employeeId != null) 'employee_id': employeeId,
      if (storeId != null) 'store_id': storeId,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (workedDays != null) 'worked_days': workedDays,
      if (totalWorkedHours != null) 'total_worked_hours': totalWorkedHours,
      if (totalOvertimeHours != null)
        'total_overtime_hours': totalOvertimeHours,
      if (appliedRate != null) 'applied_rate': appliedRate,
      if (computedAmount != null) 'computed_amount': computedAmount,
      if (status != null) 'status': status,
      if (paidByEmployeeId != null) 'paid_by_employee_id': paidByEmployeeId,
      if (paidAt != null) 'paid_at': paidAt,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PayrollPeriodsCompanion copyWith({
    Value<String>? id,
    Value<String>? employeeId,
    Value<String>? storeId,
    Value<DateTime>? startDate,
    Value<DateTime>? endDate,
    Value<int>? workedDays,
    Value<double>? totalWorkedHours,
    Value<double>? totalOvertimeHours,
    Value<double>? appliedRate,
    Value<double>? computedAmount,
    Value<PayrollStatus>? status,
    Value<String?>? paidByEmployeeId,
    Value<DateTime?>? paidAt,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return PayrollPeriodsCompanion(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      storeId: storeId ?? this.storeId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      workedDays: workedDays ?? this.workedDays,
      totalWorkedHours: totalWorkedHours ?? this.totalWorkedHours,
      totalOvertimeHours: totalOvertimeHours ?? this.totalOvertimeHours,
      appliedRate: appliedRate ?? this.appliedRate,
      computedAmount: computedAmount ?? this.computedAmount,
      status: status ?? this.status,
      paidByEmployeeId: paidByEmployeeId ?? this.paidByEmployeeId,
      paidAt: paidAt ?? this.paidAt,
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
    if (employeeId.present) {
      map['employee_id'] = Variable<String>(employeeId.value);
    }
    if (storeId.present) {
      map['store_id'] = Variable<String>(storeId.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<DateTime>(startDate.value);
    }
    if (endDate.present) {
      map['end_date'] = Variable<DateTime>(endDate.value);
    }
    if (workedDays.present) {
      map['worked_days'] = Variable<int>(workedDays.value);
    }
    if (totalWorkedHours.present) {
      map['total_worked_hours'] = Variable<double>(totalWorkedHours.value);
    }
    if (totalOvertimeHours.present) {
      map['total_overtime_hours'] = Variable<double>(totalOvertimeHours.value);
    }
    if (appliedRate.present) {
      map['applied_rate'] = Variable<double>(appliedRate.value);
    }
    if (computedAmount.present) {
      map['computed_amount'] = Variable<double>(computedAmount.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $PayrollPeriodsTable.$converterstatus.toSql(status.value),
      );
    }
    if (paidByEmployeeId.present) {
      map['paid_by_employee_id'] = Variable<String>(paidByEmployeeId.value);
    }
    if (paidAt.present) {
      map['paid_at'] = Variable<DateTime>(paidAt.value);
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
    return (StringBuffer('PayrollPeriodsCompanion(')
          ..write('id: $id, ')
          ..write('employeeId: $employeeId, ')
          ..write('storeId: $storeId, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('workedDays: $workedDays, ')
          ..write('totalWorkedHours: $totalWorkedHours, ')
          ..write('totalOvertimeHours: $totalOvertimeHours, ')
          ..write('appliedRate: $appliedRate, ')
          ..write('computedAmount: $computedAmount, ')
          ..write('status: $status, ')
          ..write('paidByEmployeeId: $paidByEmployeeId, ')
          ..write('paidAt: $paidAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AttendancesTable extends Attendances
    with TableInfo<$AttendancesTable, AttendanceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AttendancesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 64,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _storeIdMeta = const VerificationMeta(
    'storeId',
  );
  @override
  late final GeneratedColumn<String> storeId = GeneratedColumn<String>(
    'store_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES stores (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _employeeIdMeta = const VerificationMeta(
    'employeeId',
  );
  @override
  late final GeneratedColumn<String> employeeId = GeneratedColumn<String>(
    'employee_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES employees (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<AttendanceStatus, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<AttendanceStatus>($AttendancesTable.$converterstatus);
  static const VerificationMeta _clockInAtMeta = const VerificationMeta(
    'clockInAt',
  );
  @override
  late final GeneratedColumn<DateTime> clockInAt = GeneratedColumn<DateTime>(
    'clock_in_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _clockOutAtMeta = const VerificationMeta(
    'clockOutAt',
  );
  @override
  late final GeneratedColumn<DateTime> clockOutAt = GeneratedColumn<DateTime>(
    'clock_out_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _payrollPeriodIdMeta = const VerificationMeta(
    'payrollPeriodId',
  );
  @override
  late final GeneratedColumn<String> payrollPeriodId = GeneratedColumn<String>(
    'payroll_period_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES payroll_periods (id) ON DELETE RESTRICT',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    storeId,
    employeeId,
    date,
    status,
    clockInAt,
    clockOutAt,
    payrollPeriodId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'attendances';
  @override
  VerificationContext validateIntegrity(
    Insertable<AttendanceRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('store_id')) {
      context.handle(
        _storeIdMeta,
        storeId.isAcceptableOrUnknown(data['store_id']!, _storeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_storeIdMeta);
    }
    if (data.containsKey('employee_id')) {
      context.handle(
        _employeeIdMeta,
        employeeId.isAcceptableOrUnknown(data['employee_id']!, _employeeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_employeeIdMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('clock_in_at')) {
      context.handle(
        _clockInAtMeta,
        clockInAt.isAcceptableOrUnknown(data['clock_in_at']!, _clockInAtMeta),
      );
    }
    if (data.containsKey('clock_out_at')) {
      context.handle(
        _clockOutAtMeta,
        clockOutAt.isAcceptableOrUnknown(
          data['clock_out_at']!,
          _clockOutAtMeta,
        ),
      );
    }
    if (data.containsKey('payroll_period_id')) {
      context.handle(
        _payrollPeriodIdMeta,
        payrollPeriodId.isAcceptableOrUnknown(
          data['payroll_period_id']!,
          _payrollPeriodIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AttendanceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AttendanceRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      storeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}store_id'],
      )!,
      employeeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}employee_id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      status: $AttendancesTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      clockInAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}clock_in_at'],
      ),
      clockOutAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}clock_out_at'],
      ),
      payrollPeriodId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payroll_period_id'],
      ),
    );
  }

  @override
  $AttendancesTable createAlias(String alias) {
    return $AttendancesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<AttendanceStatus, String, String> $converterstatus =
      const EnumNameConverter<AttendanceStatus>(AttendanceStatus.values);
}

class AttendanceRow extends DataClass implements Insertable<AttendanceRow> {
  final String id;
  final String storeId;
  final String employeeId;

  /// Midnight-normalised — the work day this row is for, not when it was
  /// created.
  final DateTime date;
  final AttendanceStatus status;
  final DateTime? clockInAt;
  final DateTime? clockOutAt;

  /// Set when a [PayrollPeriods] row locks this day. While set the row is
  /// immutable — every attendance write refuses it — and the model's
  /// `paymentStatus` reads `paid`. `RESTRICT`: a paid period cannot be deleted
  /// out from under the days it covers.
  final String? payrollPeriodId;
  const AttendanceRow({
    required this.id,
    required this.storeId,
    required this.employeeId,
    required this.date,
    required this.status,
    this.clockInAt,
    this.clockOutAt,
    this.payrollPeriodId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['store_id'] = Variable<String>(storeId);
    map['employee_id'] = Variable<String>(employeeId);
    map['date'] = Variable<DateTime>(date);
    {
      map['status'] = Variable<String>(
        $AttendancesTable.$converterstatus.toSql(status),
      );
    }
    if (!nullToAbsent || clockInAt != null) {
      map['clock_in_at'] = Variable<DateTime>(clockInAt);
    }
    if (!nullToAbsent || clockOutAt != null) {
      map['clock_out_at'] = Variable<DateTime>(clockOutAt);
    }
    if (!nullToAbsent || payrollPeriodId != null) {
      map['payroll_period_id'] = Variable<String>(payrollPeriodId);
    }
    return map;
  }

  AttendancesCompanion toCompanion(bool nullToAbsent) {
    return AttendancesCompanion(
      id: Value(id),
      storeId: Value(storeId),
      employeeId: Value(employeeId),
      date: Value(date),
      status: Value(status),
      clockInAt: clockInAt == null && nullToAbsent
          ? const Value.absent()
          : Value(clockInAt),
      clockOutAt: clockOutAt == null && nullToAbsent
          ? const Value.absent()
          : Value(clockOutAt),
      payrollPeriodId: payrollPeriodId == null && nullToAbsent
          ? const Value.absent()
          : Value(payrollPeriodId),
    );
  }

  factory AttendanceRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AttendanceRow(
      id: serializer.fromJson<String>(json['id']),
      storeId: serializer.fromJson<String>(json['storeId']),
      employeeId: serializer.fromJson<String>(json['employeeId']),
      date: serializer.fromJson<DateTime>(json['date']),
      status: $AttendancesTable.$converterstatus.fromJson(
        serializer.fromJson<String>(json['status']),
      ),
      clockInAt: serializer.fromJson<DateTime?>(json['clockInAt']),
      clockOutAt: serializer.fromJson<DateTime?>(json['clockOutAt']),
      payrollPeriodId: serializer.fromJson<String?>(json['payrollPeriodId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'storeId': serializer.toJson<String>(storeId),
      'employeeId': serializer.toJson<String>(employeeId),
      'date': serializer.toJson<DateTime>(date),
      'status': serializer.toJson<String>(
        $AttendancesTable.$converterstatus.toJson(status),
      ),
      'clockInAt': serializer.toJson<DateTime?>(clockInAt),
      'clockOutAt': serializer.toJson<DateTime?>(clockOutAt),
      'payrollPeriodId': serializer.toJson<String?>(payrollPeriodId),
    };
  }

  AttendanceRow copyWith({
    String? id,
    String? storeId,
    String? employeeId,
    DateTime? date,
    AttendanceStatus? status,
    Value<DateTime?> clockInAt = const Value.absent(),
    Value<DateTime?> clockOutAt = const Value.absent(),
    Value<String?> payrollPeriodId = const Value.absent(),
  }) => AttendanceRow(
    id: id ?? this.id,
    storeId: storeId ?? this.storeId,
    employeeId: employeeId ?? this.employeeId,
    date: date ?? this.date,
    status: status ?? this.status,
    clockInAt: clockInAt.present ? clockInAt.value : this.clockInAt,
    clockOutAt: clockOutAt.present ? clockOutAt.value : this.clockOutAt,
    payrollPeriodId: payrollPeriodId.present
        ? payrollPeriodId.value
        : this.payrollPeriodId,
  );
  AttendanceRow copyWithCompanion(AttendancesCompanion data) {
    return AttendanceRow(
      id: data.id.present ? data.id.value : this.id,
      storeId: data.storeId.present ? data.storeId.value : this.storeId,
      employeeId: data.employeeId.present
          ? data.employeeId.value
          : this.employeeId,
      date: data.date.present ? data.date.value : this.date,
      status: data.status.present ? data.status.value : this.status,
      clockInAt: data.clockInAt.present ? data.clockInAt.value : this.clockInAt,
      clockOutAt: data.clockOutAt.present
          ? data.clockOutAt.value
          : this.clockOutAt,
      payrollPeriodId: data.payrollPeriodId.present
          ? data.payrollPeriodId.value
          : this.payrollPeriodId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AttendanceRow(')
          ..write('id: $id, ')
          ..write('storeId: $storeId, ')
          ..write('employeeId: $employeeId, ')
          ..write('date: $date, ')
          ..write('status: $status, ')
          ..write('clockInAt: $clockInAt, ')
          ..write('clockOutAt: $clockOutAt, ')
          ..write('payrollPeriodId: $payrollPeriodId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    storeId,
    employeeId,
    date,
    status,
    clockInAt,
    clockOutAt,
    payrollPeriodId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AttendanceRow &&
          other.id == this.id &&
          other.storeId == this.storeId &&
          other.employeeId == this.employeeId &&
          other.date == this.date &&
          other.status == this.status &&
          other.clockInAt == this.clockInAt &&
          other.clockOutAt == this.clockOutAt &&
          other.payrollPeriodId == this.payrollPeriodId);
}

class AttendancesCompanion extends UpdateCompanion<AttendanceRow> {
  final Value<String> id;
  final Value<String> storeId;
  final Value<String> employeeId;
  final Value<DateTime> date;
  final Value<AttendanceStatus> status;
  final Value<DateTime?> clockInAt;
  final Value<DateTime?> clockOutAt;
  final Value<String?> payrollPeriodId;
  final Value<int> rowid;
  const AttendancesCompanion({
    this.id = const Value.absent(),
    this.storeId = const Value.absent(),
    this.employeeId = const Value.absent(),
    this.date = const Value.absent(),
    this.status = const Value.absent(),
    this.clockInAt = const Value.absent(),
    this.clockOutAt = const Value.absent(),
    this.payrollPeriodId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AttendancesCompanion.insert({
    required String id,
    required String storeId,
    required String employeeId,
    required DateTime date,
    required AttendanceStatus status,
    this.clockInAt = const Value.absent(),
    this.clockOutAt = const Value.absent(),
    this.payrollPeriodId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       storeId = Value(storeId),
       employeeId = Value(employeeId),
       date = Value(date),
       status = Value(status);
  static Insertable<AttendanceRow> custom({
    Expression<String>? id,
    Expression<String>? storeId,
    Expression<String>? employeeId,
    Expression<DateTime>? date,
    Expression<String>? status,
    Expression<DateTime>? clockInAt,
    Expression<DateTime>? clockOutAt,
    Expression<String>? payrollPeriodId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (storeId != null) 'store_id': storeId,
      if (employeeId != null) 'employee_id': employeeId,
      if (date != null) 'date': date,
      if (status != null) 'status': status,
      if (clockInAt != null) 'clock_in_at': clockInAt,
      if (clockOutAt != null) 'clock_out_at': clockOutAt,
      if (payrollPeriodId != null) 'payroll_period_id': payrollPeriodId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AttendancesCompanion copyWith({
    Value<String>? id,
    Value<String>? storeId,
    Value<String>? employeeId,
    Value<DateTime>? date,
    Value<AttendanceStatus>? status,
    Value<DateTime?>? clockInAt,
    Value<DateTime?>? clockOutAt,
    Value<String?>? payrollPeriodId,
    Value<int>? rowid,
  }) {
    return AttendancesCompanion(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      employeeId: employeeId ?? this.employeeId,
      date: date ?? this.date,
      status: status ?? this.status,
      clockInAt: clockInAt ?? this.clockInAt,
      clockOutAt: clockOutAt ?? this.clockOutAt,
      payrollPeriodId: payrollPeriodId ?? this.payrollPeriodId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (storeId.present) {
      map['store_id'] = Variable<String>(storeId.value);
    }
    if (employeeId.present) {
      map['employee_id'] = Variable<String>(employeeId.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $AttendancesTable.$converterstatus.toSql(status.value),
      );
    }
    if (clockInAt.present) {
      map['clock_in_at'] = Variable<DateTime>(clockInAt.value);
    }
    if (clockOutAt.present) {
      map['clock_out_at'] = Variable<DateTime>(clockOutAt.value);
    }
    if (payrollPeriodId.present) {
      map['payroll_period_id'] = Variable<String>(payrollPeriodId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AttendancesCompanion(')
          ..write('id: $id, ')
          ..write('storeId: $storeId, ')
          ..write('employeeId: $employeeId, ')
          ..write('date: $date, ')
          ..write('status: $status, ')
          ..write('clockInAt: $clockInAt, ')
          ..write('clockOutAt: $clockOutAt, ')
          ..write('payrollPeriodId: $payrollPeriodId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AttendancePausesTable extends AttendancePauses
    with TableInfo<$AttendancePausesTable, AttendancePauseRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AttendancePausesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 64,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attendanceIdMeta = const VerificationMeta(
    'attendanceId',
  );
  @override
  late final GeneratedColumn<String> attendanceId = GeneratedColumn<String>(
    'attendance_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES attendances (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startAtMeta = const VerificationMeta(
    'startAt',
  );
  @override
  late final GeneratedColumn<DateTime> startAt = GeneratedColumn<DateTime>(
    'start_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endAtMeta = const VerificationMeta('endAt');
  @override
  late final GeneratedColumn<DateTime> endAt = GeneratedColumn<DateTime>(
    'end_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    attendanceId,
    position,
    startAt,
    endAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'attendance_pauses';
  @override
  VerificationContext validateIntegrity(
    Insertable<AttendancePauseRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('attendance_id')) {
      context.handle(
        _attendanceIdMeta,
        attendanceId.isAcceptableOrUnknown(
          data['attendance_id']!,
          _attendanceIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_attendanceIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('start_at')) {
      context.handle(
        _startAtMeta,
        startAt.isAcceptableOrUnknown(data['start_at']!, _startAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startAtMeta);
    }
    if (data.containsKey('end_at')) {
      context.handle(
        _endAtMeta,
        endAt.isAcceptableOrUnknown(data['end_at']!, _endAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AttendancePauseRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AttendancePauseRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      attendanceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attendance_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      startAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_at'],
      )!,
      endAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}end_at'],
      ),
    );
  }

  @override
  $AttendancePausesTable createAlias(String alias) {
    return $AttendancePausesTable(attachedDatabase, alias);
  }
}

class AttendancePauseRow extends DataClass
    implements Insertable<AttendancePauseRow> {
  final String id;
  final String attendanceId;
  final int position;
  final DateTime startAt;
  final DateTime? endAt;
  const AttendancePauseRow({
    required this.id,
    required this.attendanceId,
    required this.position,
    required this.startAt,
    this.endAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['attendance_id'] = Variable<String>(attendanceId);
    map['position'] = Variable<int>(position);
    map['start_at'] = Variable<DateTime>(startAt);
    if (!nullToAbsent || endAt != null) {
      map['end_at'] = Variable<DateTime>(endAt);
    }
    return map;
  }

  AttendancePausesCompanion toCompanion(bool nullToAbsent) {
    return AttendancePausesCompanion(
      id: Value(id),
      attendanceId: Value(attendanceId),
      position: Value(position),
      startAt: Value(startAt),
      endAt: endAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endAt),
    );
  }

  factory AttendancePauseRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AttendancePauseRow(
      id: serializer.fromJson<String>(json['id']),
      attendanceId: serializer.fromJson<String>(json['attendanceId']),
      position: serializer.fromJson<int>(json['position']),
      startAt: serializer.fromJson<DateTime>(json['startAt']),
      endAt: serializer.fromJson<DateTime?>(json['endAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'attendanceId': serializer.toJson<String>(attendanceId),
      'position': serializer.toJson<int>(position),
      'startAt': serializer.toJson<DateTime>(startAt),
      'endAt': serializer.toJson<DateTime?>(endAt),
    };
  }

  AttendancePauseRow copyWith({
    String? id,
    String? attendanceId,
    int? position,
    DateTime? startAt,
    Value<DateTime?> endAt = const Value.absent(),
  }) => AttendancePauseRow(
    id: id ?? this.id,
    attendanceId: attendanceId ?? this.attendanceId,
    position: position ?? this.position,
    startAt: startAt ?? this.startAt,
    endAt: endAt.present ? endAt.value : this.endAt,
  );
  AttendancePauseRow copyWithCompanion(AttendancePausesCompanion data) {
    return AttendancePauseRow(
      id: data.id.present ? data.id.value : this.id,
      attendanceId: data.attendanceId.present
          ? data.attendanceId.value
          : this.attendanceId,
      position: data.position.present ? data.position.value : this.position,
      startAt: data.startAt.present ? data.startAt.value : this.startAt,
      endAt: data.endAt.present ? data.endAt.value : this.endAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AttendancePauseRow(')
          ..write('id: $id, ')
          ..write('attendanceId: $attendanceId, ')
          ..write('position: $position, ')
          ..write('startAt: $startAt, ')
          ..write('endAt: $endAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, attendanceId, position, startAt, endAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AttendancePauseRow &&
          other.id == this.id &&
          other.attendanceId == this.attendanceId &&
          other.position == this.position &&
          other.startAt == this.startAt &&
          other.endAt == this.endAt);
}

class AttendancePausesCompanion extends UpdateCompanion<AttendancePauseRow> {
  final Value<String> id;
  final Value<String> attendanceId;
  final Value<int> position;
  final Value<DateTime> startAt;
  final Value<DateTime?> endAt;
  final Value<int> rowid;
  const AttendancePausesCompanion({
    this.id = const Value.absent(),
    this.attendanceId = const Value.absent(),
    this.position = const Value.absent(),
    this.startAt = const Value.absent(),
    this.endAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AttendancePausesCompanion.insert({
    required String id,
    required String attendanceId,
    required int position,
    required DateTime startAt,
    this.endAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       attendanceId = Value(attendanceId),
       position = Value(position),
       startAt = Value(startAt);
  static Insertable<AttendancePauseRow> custom({
    Expression<String>? id,
    Expression<String>? attendanceId,
    Expression<int>? position,
    Expression<DateTime>? startAt,
    Expression<DateTime>? endAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (attendanceId != null) 'attendance_id': attendanceId,
      if (position != null) 'position': position,
      if (startAt != null) 'start_at': startAt,
      if (endAt != null) 'end_at': endAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AttendancePausesCompanion copyWith({
    Value<String>? id,
    Value<String>? attendanceId,
    Value<int>? position,
    Value<DateTime>? startAt,
    Value<DateTime?>? endAt,
    Value<int>? rowid,
  }) {
    return AttendancePausesCompanion(
      id: id ?? this.id,
      attendanceId: attendanceId ?? this.attendanceId,
      position: position ?? this.position,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (attendanceId.present) {
      map['attendance_id'] = Variable<String>(attendanceId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (startAt.present) {
      map['start_at'] = Variable<DateTime>(startAt.value);
    }
    if (endAt.present) {
      map['end_at'] = Variable<DateTime>(endAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AttendancePausesCompanion(')
          ..write('id: $id, ')
          ..write('attendanceId: $attendanceId, ')
          ..write('position: $position, ')
          ..write('startAt: $startAt, ')
          ..write('endAt: $endAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  late final $StoresTable stores = $StoresTable(this);
  late final $MetaTable meta = $MetaTable(this);
  late final $CategoriesTable categories = $CategoriesTable(this);
  late final $UnitsTable units = $UnitsTable(this);
  late final $ItemsTable items = $ItemsTable(this);
  late final $SuppliersTable suppliers = $SuppliersTable(this);
  late final $SupplierPricesTable supplierPrices = $SupplierPricesTable(this);
  late final $PriceHistoryTable priceHistory = $PriceHistoryTable(this);
  late final $StockMovementsTable stockMovements = $StockMovementsTable(this);
  late final $PurchaseOrdersTable purchaseOrders = $PurchaseOrdersTable(this);
  late final $PurchaseOrderLinesTable purchaseOrderLines =
      $PurchaseOrderLinesTable(this);
  late final $GoodsReceiptsTable goodsReceipts = $GoodsReceiptsTable(this);
  late final $GoodsReceiptLinesTable goodsReceiptLines =
      $GoodsReceiptLinesTable(this);
  late final $NotificationsTable notifications = $NotificationsTable(this);
  late final $EmployeesTable employees = $EmployeesTable(this);
  late final $EmployeeCredentialsTable employeeCredentials =
      $EmployeeCredentialsTable(this);
  late final $PayrollPeriodsTable payrollPeriods = $PayrollPeriodsTable(this);
  late final $AttendancesTable attendances = $AttendancesTable(this);
  late final $AttendancePausesTable attendancePauses = $AttendancePausesTable(
    this,
  );
  late final Index itemsStore = Index(
    'items_store',
    'CREATE INDEX items_store ON items (store_id)',
  );
  late final Index itemsStoreBarcode = Index(
    'items_store_barcode',
    'CREATE INDEX items_store_barcode ON items (store_id, barcode)',
  );
  late final Index itemsCategory = Index(
    'items_category',
    'CREATE INDEX items_category ON items (category_id)',
  );
  late final Index itemsUnit = Index(
    'items_unit',
    'CREATE INDEX items_unit ON items (unit_id)',
  );
  late final Index suppliersStore = Index(
    'suppliers_store',
    'CREATE INDEX suppliers_store ON suppliers (store_id)',
  );
  late final Index supplierPricesItem = Index(
    'supplier_prices_item',
    'CREATE INDEX supplier_prices_item ON supplier_prices (item_id)',
  );
  late final Index supplierPricesSupplier = Index(
    'supplier_prices_supplier',
    'CREATE INDEX supplier_prices_supplier ON supplier_prices (supplier_id)',
  );
  late final Index supplierPricesPair = Index(
    'supplier_prices_pair',
    'CREATE UNIQUE INDEX supplier_prices_pair ON supplier_prices (item_id, supplier_id)',
  );
  late final Index priceHistoryPairTime = Index(
    'price_history_pair_time',
    'CREATE INDEX price_history_pair_time ON price_history (item_id, supplier_id, changed_at DESC)',
  );
  late final Index stockMovementsItemTime = Index(
    'stock_movements_item_time',
    'CREATE INDEX stock_movements_item_time ON stock_movements (item_id, occurred_at DESC)',
  );
  late final Index stockMovementsStoreTime = Index(
    'stock_movements_store_time',
    'CREATE INDEX stock_movements_store_time ON stock_movements (store_id, occurred_at DESC)',
  );
  late final Index stockMovementsReceipt = Index(
    'stock_movements_receipt',
    'CREATE INDEX stock_movements_receipt ON stock_movements (receipt_id)',
  );
  late final Index purchaseOrdersStoreStatus = Index(
    'purchase_orders_store_status',
    'CREATE INDEX purchase_orders_store_status ON purchase_orders (store_id, status)',
  );
  late final Index purchaseOrdersSupplier = Index(
    'purchase_orders_supplier',
    'CREATE INDEX purchase_orders_supplier ON purchase_orders (supplier_id)',
  );
  late final Index purchaseOrderLinesOrder = Index(
    'purchase_order_lines_order',
    'CREATE INDEX purchase_order_lines_order ON purchase_order_lines (order_id)',
  );
  late final Index purchaseOrderLinesItem = Index(
    'purchase_order_lines_item',
    'CREATE INDEX purchase_order_lines_item ON purchase_order_lines (item_id)',
  );
  late final Index goodsReceiptsOrder = Index(
    'goods_receipts_order',
    'CREATE INDEX goods_receipts_order ON goods_receipts (order_id)',
  );
  late final Index goodsReceiptsStore = Index(
    'goods_receipts_store',
    'CREATE INDEX goods_receipts_store ON goods_receipts (store_id)',
  );
  late final Index goodsReceiptLinesReceipt = Index(
    'goods_receipt_lines_receipt',
    'CREATE INDEX goods_receipt_lines_receipt ON goods_receipt_lines (receipt_id)',
  );
  late final Index goodsReceiptLinesItem = Index(
    'goods_receipt_lines_item',
    'CREATE INDEX goods_receipt_lines_item ON goods_receipt_lines (item_id)',
  );
  late final Index notificationsStoreTime = Index(
    'notifications_store_time',
    'CREATE INDEX notifications_store_time ON notifications (store_id, created_at DESC)',
  );
  late final Index employeesStore = Index(
    'employees_store',
    'CREATE INDEX employees_store ON employees (store_id)',
  );
  late final Index employeesCin = Index(
    'employees_cin',
    'CREATE UNIQUE INDEX employees_cin ON employees (cin)',
  );
  late final Index employeesEmail = Index(
    'employees_email',
    'CREATE UNIQUE INDEX employees_email ON employees (email)',
  );
  late final Index employeeCredentialsEmployee = Index(
    'employee_credentials_employee',
    'CREATE UNIQUE INDEX employee_credentials_employee ON employee_credentials (employee_id)',
  );
  late final Index payrollPeriodsEmployee = Index(
    'payroll_periods_employee',
    'CREATE INDEX payroll_periods_employee ON payroll_periods (employee_id, paid_at)',
  );
  late final Index payrollPeriodsStore = Index(
    'payroll_periods_store',
    'CREATE INDEX payroll_periods_store ON payroll_periods (store_id, paid_at)',
  );
  late final Index attendancesEmployeeDate = Index(
    'attendances_employee_date',
    'CREATE UNIQUE INDEX attendances_employee_date ON attendances (employee_id, date)',
  );
  late final Index attendancesStoreDate = Index(
    'attendances_store_date',
    'CREATE INDEX attendances_store_date ON attendances (store_id, date)',
  );
  late final Index attendancePausesAttendance = Index(
    'attendance_pauses_attendance',
    'CREATE UNIQUE INDEX attendance_pauses_attendance ON attendance_pauses (attendance_id, position)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    stores,
    meta,
    categories,
    units,
    items,
    suppliers,
    supplierPrices,
    priceHistory,
    stockMovements,
    purchaseOrders,
    purchaseOrderLines,
    goodsReceipts,
    goodsReceiptLines,
    notifications,
    employees,
    employeeCredentials,
    payrollPeriods,
    attendances,
    attendancePauses,
    itemsStore,
    itemsStoreBarcode,
    itemsCategory,
    itemsUnit,
    suppliersStore,
    supplierPricesItem,
    supplierPricesSupplier,
    supplierPricesPair,
    priceHistoryPairTime,
    stockMovementsItemTime,
    stockMovementsStoreTime,
    stockMovementsReceipt,
    purchaseOrdersStoreStatus,
    purchaseOrdersSupplier,
    purchaseOrderLinesOrder,
    purchaseOrderLinesItem,
    goodsReceiptsOrder,
    goodsReceiptsStore,
    goodsReceiptLinesReceipt,
    goodsReceiptLinesItem,
    notificationsStoreTime,
    employeesStore,
    employeesCin,
    employeesEmail,
    employeeCredentialsEmployee,
    payrollPeriodsEmployee,
    payrollPeriodsStore,
    attendancesEmployeeDate,
    attendancesStoreDate,
    attendancePausesAttendance,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'stores',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('categories', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'stores',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('units', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'stores',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('items', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'stores',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('suppliers', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'items',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('supplier_prices', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'suppliers',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('supplier_prices', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'items',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('price_history', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'suppliers',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('price_history', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'stores',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('stock_movements', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'items',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('stock_movements', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'stores',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('purchase_orders', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'purchase_orders',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('purchase_order_lines', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'purchase_orders',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('goods_receipts', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'stores',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('goods_receipts', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'goods_receipts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('goods_receipt_lines', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'stores',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('notifications', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'employees',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('employee_credentials', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'employees',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('payroll_periods', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'stores',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('payroll_periods', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'stores',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('attendances', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'employees',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('attendances', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'attendances',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('attendance_pauses', kind: UpdateKind.delete)],
    ),
  ]);
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}
