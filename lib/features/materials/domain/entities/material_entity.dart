import 'package:equatable/equatable.dart';

/// Domain entity — Cell material (lesson, video, document)
class MaterialEntity extends Equatable {
  const MaterialEntity({
    required this.id,
    required this.title,
    required this.fileUrl,
    required this.fileType,
    required this.uploadedAt,
    required this.uploadedBy,
    this.description,
    this.fileSizeBytes,
  });

  final String id;
  final String title;
  final String fileUrl;
  final MaterialFileType fileType;
  final DateTime uploadedAt;
  final String uploadedBy;
  final String? description;
  final int? fileSizeBytes;

  String get formattedSize {
    if (fileSizeBytes == null) return '';
    final kb = fileSizeBytes! / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    return '${(kb / 1024).toStringAsFixed(1)} MB';
  }

  @override
  List<Object?> get props => [id];
}

enum MaterialFileType {
  pdf,
  docx,
  ppt,
  video,
  other;

  static MaterialFileType fromExtension(String ext) =>
      switch (ext.toLowerCase()) {
        'pdf' => pdf,
        'docx' || 'doc' => docx,
        'ppt' || 'pptx' => ppt,
        'mp4' || 'mov' || 'avi' => video,
        _ => other,
      };

  String get icon => switch (this) {
    MaterialFileType.pdf => '📄',
    MaterialFileType.docx => '📝',
    MaterialFileType.ppt => '📊',
    MaterialFileType.video => '🎥',
    MaterialFileType.other => '📎',
  };
}
