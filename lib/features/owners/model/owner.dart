/// 归属的大类。一个任务只属于一个归属，归属按课表 profile 隔离。
enum OwnerKind {
  course,
  onlineCourse,
  studentUnion,
  club,
  personal,
  other;

  String get label {
    return switch (this) {
      OwnerKind.course => '课程',
      OwnerKind.onlineCourse => '网课',
      OwnerKind.studentUnion => '学生会',
      OwnerKind.club => '社团',
      OwnerKind.personal => '自有任务',
      OwnerKind.other => '其他',
    };
  }

  static OwnerKind parse(String? raw) {
    for (final value in OwnerKind.values) {
      if (value.name == raw) return value;
    }
    return OwnerKind.other;
  }
}

/// 网课平台。仅 [OwnerKind.onlineCourse] 使用，其他类型必须为空。
enum OnlinePlatform {
  chaoxing,
  mooc,
  zhihuishu,
  xuetangx,
  other;

  String get label {
    return switch (this) {
      OnlinePlatform.chaoxing => '学习通 / 超星',
      OnlinePlatform.mooc => '中国大学 MOOC',
      OnlinePlatform.zhihuishu => '智慧树',
      OnlinePlatform.xuetangx => '学堂在线',
      OnlinePlatform.other => '其他平台',
    };
  }

  static OnlinePlatform? parse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final value in OnlinePlatform.values) {
      if (value.name == raw) return value;
    }
    return OnlinePlatform.other;
  }
}

/// 归属的来源，用于区分自动生成与用户创建。
enum OwnerOrigin {
  seed,
  manual,
  timetable,
  import;

  static OwnerOrigin parse(String? raw) {
    for (final value in OwnerOrigin.values) {
      if (value.name == raw) return value;
    }
    return OwnerOrigin.manual;
  }
}

class Owner {
  const Owner({
    required this.id,
    required this.profileId,
    required this.kind,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.platform,
    this.origin = OwnerOrigin.manual,
    this.nameCustom = false,
    this.colorIndex,
    this.isDefault = false,
    this.archived = false,
  });

  factory Owner.fromJson(Map<String, Object?> json) {
    return Owner(
      id: json['id']?.toString() ?? '',
      profileId: json['profileId']?.toString() ?? '',
      kind: OwnerKind.parse(json['kind']?.toString()),
      name: json['name']?.toString() ?? '',
      platform: OnlinePlatform.parse(json['platform']?.toString()),
      origin: OwnerOrigin.parse(json['origin']?.toString()),
      nameCustom: json['nameCustom'] == true,
      colorIndex: (json['colorIndex'] as num?)?.toInt(),
      isDefault: json['isDefault'] == true,
      archived: json['archived'] == true,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  final String id;
  final String profileId;
  final OwnerKind kind;
  final String name;
  final OnlinePlatform? platform;
  final OwnerOrigin origin;

  /// 用户改过名后为 true，课表同步不再覆盖名称。
  final bool nameCustom;
  final int? colorIndex;

  /// 每个 profile 有且只有一个默认组。
  final bool isDefault;
  final bool archived;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isOnlineCourse => kind == OwnerKind.onlineCourse;

  Owner copyWith({
    String? id,
    String? profileId,
    OwnerKind? kind,
    String? name,
    OnlinePlatform? platform,
    bool clearPlatform = false,
    OwnerOrigin? origin,
    bool? nameCustom,
    int? colorIndex,
    bool? isDefault,
    bool? archived,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Owner(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      kind: kind ?? this.kind,
      name: name ?? this.name,
      platform: clearPlatform ? null : (platform ?? this.platform),
      origin: origin ?? this.origin,
      nameCustom: nameCustom ?? this.nameCustom,
      colorIndex: colorIndex ?? this.colorIndex,
      isDefault: isDefault ?? this.isDefault,
      archived: archived ?? this.archived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'profileId': profileId,
      'kind': kind.name,
      'name': name,
      'platform': platform?.name,
      'origin': origin.name,
      'nameCustom': nameCustom,
      'colorIndex': colorIndex,
      'isDefault': isDefault,
      'archived': archived,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

/// 课程绑定：一个归属可以绑定多个 course.id（理论课 + 实验课合并后）。
var _ownerIdSeed = 0;

String newOwnerId() {
  _ownerIdSeed += 1;
  return 'owner_${DateTime.now().microsecondsSinceEpoch}_$_ownerIdSeed';
}

class OwnerRef {
  const OwnerRef({
    required this.ownerId,
    required this.profileId,
    required this.refType,
    required this.refId,
  });

  final String ownerId;
  final String profileId;
  final String refType;
  final String refId;

  static const String courseRefType = 'course';
}

class OwnerValidationError implements Exception {
  OwnerValidationError(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 写入前的领域校验：网课必须有平台，其他类型必须没有。
void validateOwnerPlatform(OwnerKind kind, OnlinePlatform? platform) {
  if (kind == OwnerKind.onlineCourse && platform == null) {
    throw OwnerValidationError('网课归属必须指定平台');
  }
  if (kind != OwnerKind.onlineCourse && platform != null) {
    throw OwnerValidationError('只有网课归属可以设置平台');
  }
}

