# DocScan Pro

App profesional de escaneo de documentos.
Lista para conectarse a **PostgreSQL + API**.

## Arquitectura actual

```
lib/
├── main.dart
├── models/
│   └── scanned_document.dart
├── services/
│   └── document_service.dart   ← aquí se conectará la API real
└── screens/
    ├── home_screen.dart
    └── preview_screen.dart
```

## Características

- Escaneo profesional (ML Kit Document Scanner)
- Multi-página + PDF + JPEG
- Vista previa con zoom
- Compartir documentos
- Persistencia local (los documentos no se pierden)
- Botón **"Subir al sistema"** (simulado, listo para API real)
- Estados: Local → Subiendo → En el sistema

## Cómo actualizar

```bash
git pull
flutter pub get
flutter run          # en celular Android
```

## Próximo paso

Cuando quieras conectar PostgreSQL:
1. Creamos el backend (Node/Nest o Laravel)
2. Creamos las tablas en PostgreSQL
3. Reemplazamos `LocalDocumentService` por `ApiDocumentService`

La app Flutter casi no cambia.

---

Diseñado para escalar.
