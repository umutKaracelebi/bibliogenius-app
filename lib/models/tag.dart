class Tag {
  final int id;
  final String name;
  final int? parentId;
  final String path;
  final int count;
  final List<Tag> children;

  Tag({
    required this.id,
    required this.name,
    this.parentId,
    this.path = '',
    required this.count,
    this.children = const [],
  });

  factory Tag.fromJson(Map<String, dynamic> json) {
    return Tag(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String,
      parentId: json['parent_id'] as int?,
      path: json['path'] as String? ?? '',
      count: json['count'] as int? ?? 0,
      children:
          (json['children'] as List<dynamic>?)
              ?.map((e) => Tag.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'parent_id': parentId,
      'path': path,
      'count': count,
    };
  }

  /// Get the full display path including this tag's name
  String get fullPath => path.isEmpty ? name : '$path > $name';

  /// Check if this is a root tag (no parent)
  bool get isRoot => parentId == null;

  /// Create a copy with updated children (for tree building)
  Tag copyWithChildren(List<Tag> newChildren) {
    return Tag(
      id: id,
      name: name,
      parentId: parentId,
      path: path,
      count: count,
      children: newChildren,
    );
  }
}
