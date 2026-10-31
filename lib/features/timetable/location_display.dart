// TODO: replace this heuristic parser with an on-device model-backed
// recognizer when the local model integration is available.
class ParsedLocation {
  const ParsedLocation({
    this.building = '',
    this.direction = '',
    this.room = '',
  });

  final String building;
  final String direction;
  final String room;

  bool get isStructured =>
      room.isNotEmpty && (building.isNotEmpty || direction.isNotEmpty);

  List<String> get parts => [
    if (building.isNotEmpty) building,
    if (direction.isNotEmpty) direction,
    if (room.isNotEmpty) room,
  ];
}

ParsedLocation parseLocation(String raw) {
  final value = raw.trim().replaceAll(RegExp(r'\s+'), '');
  if (value.isEmpty) return const ParsedLocation();

  final buildingMatch = RegExp(
    r'^(第?[0-9一二三四五六七八九十百]+(?:号)?(?:教研楼|教学楼|教楼|楼|教)|[A-Za-z]楼)(.*)$',
  ).firstMatch(value);
  final building = buildingMatch?.group(1) ?? '';
  final remainder = buildingMatch?.group(2) ?? value;

  final directionMatch = RegExp(r'^([东西南北中])(?:区)?[-\s]?(.+)$')
      .firstMatch(remainder);
  final direction = directionMatch?.group(1) ?? '';
  final room = directionMatch?.group(2) ?? remainder;

  if (room.isEmpty) return const ParsedLocation();
  return ParsedLocation(building: building, direction: direction, room: room);
}
