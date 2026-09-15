# DocScan Pro

App profesional de escaneo de documentos · Lista para integrarse con cualquier sistema.

## Arquitectura

```
lib/
├── main.dart
├── models/
│   └── scanned_document.dart     # Modelo del documento + estados
├── services/
│   └── document_service.dart     # Capa de servicio (fácil de conectar a API)
└── screens/
    ├── home_screen.dart
    └── preview_screen.dart
```

## Características

- Escaneo profesional (ML Kit Document Scanner)
- Multi-página + PDF + JPEG
- Vista previa con zoom
- Compartir documentos
- **Botón "Subir al sistema"** (simulado, listo para API real)
- Estados del documento: Local → Subiendo → En el sistema
- Arquitectura limpia y escalable

## Cómo actualizar y probar

```bash
git pull
flutter pub get
flutter run          # en celular Android
```

## Próximo paso: Conectar con el sistema

Solo hay que crear una clase `ApiDocumentService` que implemente `DocumentService` y haga las llamadas HTTP reales. El resto de la app no cambia.

---

Diseñado para escalar.
