class ScannedDocument {
  final String id;
  final String title;
  final List<String> imagePaths;
  final String? pdfPath;
  final DateTime createdAt;
  final DocumentStatus status;
  final String? remoteId; // ID del sistema (PostgreSQL) cuando se suba
  final DateTime? uploadedAt;

  ScannedDocument({
    required this.id,
    required this.title,
    required this.imagePaths,
    this.pdfPath,
    required this.createdAt,
    this.status = DocumentStatus.local,
    this.remoteId,
    this.uploadedAt,
  });

  ScannedDocument copyWith({
    String? title,
    List<String>? imagePaths,
    String? pdfPath,
    DocumentStatus? status,
    String? remoteId,
    DateTime? uploadedAt,
  }) {
    return ScannedDocument(
      id: id,
      title: title ?? this.title,
      imagePaths: imagePaths ?? this.imagePaths,
      pdfPath: pdfPath ?? this.pdfPath,
      createdAt: createdAt,
      status: status ?? this.status,
      remoteId: remoteId ?? this.remoteId,
      uploadedAt: uploadedAt ?? this.uploadedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'imagePaths': imagePaths,
        'pdfPath': pdfPath,
        'createdAt': createdAt.toIso8601String(),
        'status': status.name,
        'remoteId': remoteId,
        'uploadedAt': uploadedAt?.toIso8601String(),
      };

  factory ScannedDocument.fromJson(Map<String, dynamic> json) {
    return ScannedDocument(
      id: json['id'] as String,
      title: json['title'] as String,
      imagePaths: List<String>.from(json['imagePaths'] ?? []),
      pdfPath: json['pdfPath'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      status: DocumentStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => DocumentStatus.local,
      ),
      remoteId: json['remoteId'] as String?,
      uploadedAt: json['uploadedAt'] != null
          ? DateTime.parse(json['uploadedAt'] as String)
          : null,
    );
  }
}

enum DocumentStatus {
  local, // Solo en el celular
  uploading, // Subiendo al sistema
  uploaded, // Ya está en PostgreSQL
  error, // Falló la subida
}
