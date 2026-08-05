/// Represents an encrypted media asset (photo or video) stored within the vault.
class VaultItem {
  /// Unique identifier generated upon import.
  final String id;

  /// Original filename of the imported media asset.
  final String originalName;

  /// File extension (e.g., .jpg, .mp4).
  final String fileExtension;

  /// Type of media: 'photo' or 'video'.
  final String type;

  /// Date and time when the asset was encrypted and added to the vault.
  final DateTime dateAdded;

  /// Duration in seconds if the asset is a video, null for photos.
  final int? duration;

  /// File size in bytes before encryption.
  final int size;

  VaultItem({
    required this.id,
    required this.originalName,
    required this.fileExtension,
    required this.type,
    required this.dateAdded,
    this.duration,
    required this.size,
  });

  /// Serializes [VaultItem] to JSON map format.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'originalName': originalName,
      'fileExtension': fileExtension,
      'type': type,
      'dateAdded': dateAdded.toIso8601String(),
      'duration': duration,
      'size': size,
    };
  }

  /// Constructs [VaultItem] instance from a JSON map.
  factory VaultItem.fromJson(Map<String, dynamic> json) {
    return VaultItem(
      id: json['id'] as String,
      originalName: json['originalName'] as String,
      fileExtension: json['fileExtension'] as String,
      type: json['type'] as String,
      dateAdded: DateTime.parse(json['dateAdded'] as String),
      duration: json['duration'] as int?,
      size: json['size'] as int,
    );
  }
}
