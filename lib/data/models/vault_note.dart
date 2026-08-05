/// Represents a secure, AES-encrypted text note stored inside the vault.
class VaultNote {
  /// Unique identifier generated when the note is created.
  final String id;

  /// Title of the secure note.
  final String title;

  /// Plaintext content of the secure note (encrypted on disk).
  final String content;

  /// Timestamp when the note was originally created.
  final DateTime dateCreated;

  /// Timestamp when the note was last modified.
  final DateTime dateModified;

  VaultNote({
    required this.id,
    required this.title,
    required this.content,
    required this.dateCreated,
    required this.dateModified,
  });

  /// Serializes [VaultNote] to JSON map format.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'dateCreated': dateCreated.toIso8601String(),
      'dateModified': dateModified.toIso8601String(),
    };
  }

  /// Constructs [VaultNote] instance from a JSON map.
  factory VaultNote.fromJson(Map<String, dynamic> json) {
    return VaultNote(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      dateCreated: DateTime.parse(json['dateCreated'] as String),
      dateModified: DateTime.parse(json['dateModified'] as String),
    );
  }

  /// Creates a copy of [VaultNote] with optional modified fields.
  VaultNote copyWith({
    String? title,
    String? content,
    DateTime? dateModified,
  }) {
    return VaultNote(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      dateCreated: dateCreated,
      dateModified: dateModified ?? this.dateModified,
    );
  }
}
