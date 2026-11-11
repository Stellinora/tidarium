/// 标签：多值，按课表 profile 隔离，跨 profile 可重名。
class Tag {
  const Tag({
    required this.id,
    required this.profileId,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.colorIndex,
    this.archived = false,
  });

  final String id;
  final String profileId;
  final String name;
  final int? colorIndex;
  final bool archived;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get nameNorm => normalizeTagName(name);

  Tag copyWith({
    String? id,
    String? profileId,
    String? name,
    int? colorIndex,
    bool? archived,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Tag(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      name: name ?? this.name,
      colorIndex: colorIndex ?? this.colorIndex,
      archived: archived ?? this.archived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'profileId': profileId,
      'name': name,
      'colorIndex': colorIndex,
      'archived': archived,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

var _tagIdSeed = 0;

String newTagId() {
  _tagIdSeed += 1;
  return 'tag_${DateTime.now().microsecondsSinceEpoch}_$_tagIdSeed';
}

/// 归一化：去首尾空白、内部连续空白折叠、全角转半角、转小写。
String normalizeTagName(String raw) {
  final buffer = StringBuffer();
  var lastWasSpace = false;
  for (final rune in raw.trim().runes) {
    var char = String.fromCharCode(rune);
    // 全角 ASCII（！到 ～）转半角
    final code = char.codeUnitAt(0);
    if (code >= 0xFF01 && code <= 0xFF5E) {
      char = String.fromCharCode(code - 0xFEE0);
    }
    if (char == '　') char = ' ';
    if (char.trim().isEmpty) {
      if (!lastWasSpace) buffer.write(' ');
      lastWasSpace = true;
      continue;
    }
    lastWasSpace = false;
    buffer.write(char);
  }
  return buffer.toString().toLowerCase();
}
