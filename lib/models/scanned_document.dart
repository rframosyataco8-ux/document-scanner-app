class ScannedDocument {
  final String id;
  final String title;
  final List<String> imagePaths;
  final String? pdfPath;
  final DateTime createdAt;
  final DocumentStatus status;
  final String? remoteId; // ID que devolverá el sistema cuando se suba
  final String? uploadedAt;

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
    String? uploadedAt,
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
        'uploadedAt': uploadedAt,
      };

  factory ScannedDocument.fromJson(Map<String, dynamic> json) {
    return ScannedDocument(
      id: json['id'],
      title: json['title'],
      imagePaths: List<String>.from(json['imagePaths'] ?? []),
      pdfPath: json['pdfPath'],
      createdAt: DateTime.parse(json['createdAt']),
      status: DocumentStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => DocumentStatus.local,
      ),
      remoteId: json['remoteId'],
      uploadedAt: json['uploadedAt'],
    );
  }
}

enum DocumentStatus {
  local, // Solo en el celular
  uploading, // Subiendo al sistema
  uploaded, // Ya está en el sistema
  error, // Falló la subida
}
