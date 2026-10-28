class SchoolEntry {
  const SchoolEntry({
    required this.id,
    required this.name,
    required this.initial,
    required this.resourceFolder,
  });

  final String id;
  final String name;
  final String initial;
  final String resourceFolder;
}

class SchoolAdapter {
  const SchoolAdapter({
    required this.adapterId,
    required this.adapterName,
    required this.category,
    required this.assetJsPath,
    required this.importUrl,
    required this.maintainer,
    required this.description,
  });

  final String adapterId;
  final String adapterName;
  final String category;
  final String assetJsPath;
  final String importUrl;
  final String maintainer;
  final String description;
}
