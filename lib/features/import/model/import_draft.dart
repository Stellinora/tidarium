import '../../owners/model/owner.dart';

/// 抽取出来的一条草稿。默认不会被写入，必须由用户勾选确认。
class ImportDraft {
  ImportDraft({
    required this.id,
    required this.title,
    this.dueAt,
    this.dueText = '',
    this.kind = OwnerKind.personal,
    this.ownerId,
    this.materials = const [],
    this.source = '',
    this.confidence = 0.5,
    this.warnings = const [],
  });

  factory ImportDraft.fromJson(Map<String, Object?> json, {required String id}) {
    final rawDue = json['dueAt']?.toString();
    DateTime? dueAt;
    if (rawDue != null && rawDue.isNotEmpty && rawDue != 'null') {
      dueAt = DateTime.tryParse(rawDue);
    }

    final rawMaterials = json['materials'];
    final materials = <String>[];
    if (rawMaterials is List) {
      for (final item in rawMaterials) {
        final text = item?.toString().trim() ?? '';
        if (text.isNotEmpty) materials.add(text);
      }
    }

    final warnings = <String>[];
    if (dueAt == null) warnings.add('时间待补');

    final rawConfidence = json['confidence'];
    final confidence = rawConfidence is num
        ? rawConfidence.toDouble().clamp(0.0, 1.0)
        : 0.5;

    return ImportDraft(
      id: id,
      title: (json['title']?.toString() ?? '').trim(),
      dueAt: dueAt,
      dueText: rawDue ?? '',
      kind: OwnerKind.parse(json['type']?.toString()),
      ownerId: (json['ownerId']?.toString().trim().isEmpty ?? true)
          ? null
          : json['ownerId'].toString().trim(),
      materials: List.unmodifiable(materials),
      source: json['source']?.toString() ?? '',
      confidence: confidence,
      warnings: List.unmodifiable(warnings),
    );
  }

  final String id;
  final String title;
  final DateTime? dueAt;
  final String dueText;
  final OwnerKind kind;

  /// 模型从归属清单里选出的归属 id；为空表示需要回退或人工选择。
  final String? ownerId;
  final List<String> materials;
  final String source;
  final double confidence;
  final List<String> warnings;

  bool get needsTime => dueAt == null;

  bool get isLowConfidence => confidence < 0.6;

  ImportDraft copyWith({
    String? title,
    DateTime? dueAt,
    bool clearDueAt = false,
    String? dueText,
    OwnerKind? kind,
    String? ownerId,
    bool clearOwnerId = false,
    List<String>? materials,
    String? source,
    double? confidence,
    List<String>? warnings,
  }) {
    return ImportDraft(
      id: id,
      title: title ?? this.title,
      dueAt: clearDueAt ? null : (dueAt ?? this.dueAt),
      dueText: dueText ?? this.dueText,
      kind: kind ?? this.kind,
      ownerId: clearOwnerId ? null : (ownerId ?? this.ownerId),
      materials: materials ?? this.materials,
      source: source ?? this.source,
      confidence: confidence ?? this.confidence,
      warnings: warnings ?? this.warnings,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'title': title,
      'dueAt': dueAt?.toIso8601String(),
      'type': kind.name,
      'ownerId': ownerId,
      'materials': materials,
      'source': source,
      'confidence': confidence,
    };
  }
}

var _draftIdSeed = 0;

String newDraftId() {
  _draftIdSeed += 1;
  return 'draft_${DateTime.now().microsecondsSinceEpoch}_$_draftIdSeed';
}

