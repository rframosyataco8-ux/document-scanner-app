class ScannedDocument {
  final String id;
  final String title;
  final List<String> imagePaths;
  final String? pdfPath;
  final DateTime createdAt;
  final DocumentStatus status;
  final String? remoteId;
  final DateTime? uploadedAt;
  final String? lastError;
  final int retryCount;

  final String? numeroGuia;
  final String? zona;
  final String? fechaRecepcion;
  final String? cantidadSacos;
  final String? kilos;

  ScannedDocument({
    required this.id,
    required this.title,
    required this.imagePaths,
    this.pdfPath,
    required this.createdAt,
    this.status = DocumentStatus.local,
    this.remoteId,
    this.uploadedAt,
    this.lastError,
    this.retryCount = 0,
    this.numeroGuia,
    this.zona,
    this.fechaRecepcion,
    this.cantidadSacos,
    this.kilos,
  });

  bool get hasGuiaMeta =>
      (numeroGuia?.isNotEmpty == true) &&
      (zona?.isNotEmpty == true) &&
      (fechaRecepcion?.isNotEmpty == true);

  bool get isPendingUpload =>
      status == DocumentStatus.queued || status == DocumentStatus.error;

  ScannedDocument copyWith({
    String? title,
    List<String>? imagePaths,
    String? pdfPath,
    DocumentStatus? status,
    String? remoteId,
    DateTime? uploadedAt,
    String? lastError,
    bool clearError = false,
    int? retryCount,
    String? numeroGuia,
    String? zona,
    String? fechaRecepcion,
    String? cantidadSacos,
    String? kilos,
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
      lastError: clearError ? null : (lastError ?? this.lastError),
      retryCount: retryCount ?? this.retryCount,
      numeroGuia: numeroGuia ?? this.numeroGuia,
      zona: zona ?? this.zona,
      fechaRecepcion: fechaRecepcion ?? this.fechaRecepcion,
      cantidadSacos: cantidadSacos ?? this.cantidadSacos,
      kilos: kilos ?? this.kilos,
    );
  }

  Map<String, String> get metaMap => {
        'numero_guia': numeroGuia ?? '',
        'zona': zona ?? '',
        'fecha_recepcion': fechaRecepcion ?? '',
        'cantidad_sacos': cantidadSacos ?? '',
        'kilos': kilos ?? '',
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'imagePaths': imagePaths,
        'pdfPath': pdfPath,
        'createdAt': createdAt.toIso8601String(),
        'status': status.name,
        'remoteId': remoteId,
        'uploadedAt': uploadedAt?.toIso8601String(),
        'lastError': lastError,
        'retryCount': retryCount,
        'numeroGuia': numeroGuia,
        'zona': zona,
        'fechaRecepcion': fechaRecepcion,
        'cantidadSacos': cantidadSacos,
        'kilos': kilos,
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
      lastError: json['lastError'] as String?,
      retryCount: (json['retryCount'] as num?)?.toInt() ?? 0,
      numeroGuia: json['numeroGuia'] as String?,
      zona: json['zona'] as String?,
      fechaRecepcion: json['fechaRecepcion'] as String?,
      cantidadSacos: json['cantidadSacos'] as String?,
      kilos: json['kilos'] as String?,
    );
  }
}

enum DocumentStatus {
  local,
  uploading,
  uploaded,
  error,
  queued, // En cola offline — se sube al recuperar red
}
