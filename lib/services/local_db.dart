import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/scanned_document.dart';

/// Base de datos SQLite local para documentos y cola offline.
/// Sustituye SharedPreferences como fuente de verdad.
class LocalDb {
  LocalDb._();
  static final LocalDb instance = LocalDb._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'romex_docscan.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE documents (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            image_paths TEXT NOT NULL,
            pdf_path TEXT,
            created_at TEXT NOT NULL,
            status TEXT NOT NULL,
            remote_id TEXT,
            uploaded_at TEXT,
            last_error TEXT,
            retry_count INTEGER NOT NULL DEFAULT 0,
            numero_guia TEXT,
            zona TEXT,
            fecha_recepcion TEXT,
            cantidad_sacos TEXT,
            kilos TEXT
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_documents_status ON documents(status)',
        );
        await db.execute(
          'CREATE INDEX idx_documents_created ON documents(created_at DESC)',
        );
      },
    );
  }

  Future<List<ScannedDocument>> getAll() async {
    final db = await database;
    final rows = await db.query('documents', orderBy: 'created_at DESC');
    return rows.map(_fromRow).toList();
  }

  Future<ScannedDocument?> getById(String id) async {
    final db = await database;
    final rows = await db.query('documents', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  Future<void> upsert(ScannedDocument doc) async {
    final db = await database;
    await db.insert(
      'documents',
      _toRow(doc),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> delete(String id) async {
    final db = await database;
    await db.delete('documents', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<ScannedDocument>> getByStatus(DocumentStatus status) async {
    final db = await database;
    final rows = await db.query(
      'documents',
      where: 'status = ?',
      whereArgs: [status.name],
      orderBy: 'created_at DESC',
    );
    return rows.map(_fromRow).toList();
  }

  Future<int> countQueued() async {
    final db = await database;
    final r = await db.rawQuery(
      "SELECT COUNT(*) AS c FROM documents WHERE status = 'queued'",
    );
    return (r.first['c'] as int?) ?? 0;
  }

  /// Migra datos legacy de SharedPreferences una sola vez.
  Future<void> migrateFromPrefsIfNeeded(
    Future<List<String>?> Function() loadLegacyJsonList,
  ) async {
    final db = await database;
    final count = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM documents'),
        ) ??
        0;
    if (count > 0) return;

    final legacy = await loadLegacyJsonList();
    if (legacy == null || legacy.isEmpty) return;

    final batch = db.batch();
    for (final raw in legacy) {
      try {
        final doc = ScannedDocument.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
        batch.insert('documents', _toRow(doc),
            conflictAlgorithm: ConflictAlgorithm.replace);
      } catch (_) {}
    }
    await batch.commit(noResult: true);
  }

  Map<String, Object?> _toRow(ScannedDocument d) => {
        'id': d.id,
        'title': d.title,
        'image_paths': jsonEncode(d.imagePaths),
        'pdf_path': d.pdfPath,
        'created_at': d.createdAt.toIso8601String(),
        'status': d.status.name,
        'remote_id': d.remoteId,
        'uploaded_at': d.uploadedAt?.toIso8601String(),
        'last_error': d.lastError,
        'retry_count': d.retryCount,
        'numero_guia': d.numeroGuia,
        'zona': d.zona,
        'fecha_recepcion': d.fechaRecepcion,
        'cantidad_sacos': d.cantidadSacos,
        'kilos': d.kilos,
      };

  ScannedDocument _fromRow(Map<String, Object?> row) {
    List<String> paths = [];
    try {
      paths = List<String>.from(jsonDecode(row['image_paths'] as String? ?? '[]'));
    } catch (_) {}

    return ScannedDocument(
      id: row['id'] as String,
      title: row['title'] as String,
      imagePaths: paths,
      pdfPath: row['pdf_path'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
      status: DocumentStatus.values.firstWhere(
        (e) => e.name == row['status'],
        orElse: () => DocumentStatus.local,
      ),
      remoteId: row['remote_id'] as String?,
      uploadedAt: row['uploaded_at'] != null
          ? DateTime.tryParse(row['uploaded_at'] as String)
          : null,
      lastError: row['last_error'] as String?,
      retryCount: (row['retry_count'] as int?) ?? 0,
      numeroGuia: row['numero_guia'] as String?,
      zona: row['zona'] as String?,
      fechaRecepcion: row['fecha_recepcion'] as String?,
      cantidadSacos: row['cantidad_sacos'] as String?,
      kilos: row['kilos'] as String?,
    );
  }
}
