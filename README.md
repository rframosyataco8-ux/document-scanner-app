# DocScan Pro · RomEx (v1.2)

App Flutter de escaneo de documentos conectada al **Sistema de Guias de Cacao**.

Al escanear el QR de **Conectar movil** generado en la PC, la app obtiene un JWT y sube guias (PDF + metadatos) al backend real.

## Novedades v1.2

- Tema visual RomEx (verde institucional)
- Formulario dedicado de guia (numero, zona con chips, fecha, sacos, kilos)
- Reintento de subida con metadatos persistidos
- Health-check del servidor en Ajustes
- Carga de zonas desde `/api/guias/estructura`
- Manejo de sesion expirada (401/403)
- Mensajes de error por documento

## Flujo

1. PC: Conectar movil → Generar QR
2. App: Conectar al sistema → escanear QR (o codigo manual)
3. Ajustes: URL del servidor = IP de la PC (ej. `http://192.168.1.20:3000`)
4. Escanear guia (ML Kit PDF) → Subir guia → completar datos → listo

## Arquitectura

```
lib/
├── main.dart
├── theme/app_theme.dart
├── models/scanned_document.dart
├── services/
│   ├── api_config.dart
│   ├── api_client.dart
│   ├── pairing_service.dart
│   └── document_service.dart
└── screens/
    ├── home_screen.dart
    ├── qr_pair_screen.dart
    ├── upload_guia_screen.dart
    ├── preview_screen.dart
    └── settings_screen.dart
```

## Correr

```bash
git pull
flutter pub get
flutter run
```

Celular fisico recomendado. Misma Wi-Fi que la PC. No uses `localhost` en el telefono.

## Backend

Compatible con **sistema-guias-cacao**:

- `POST /api/pair/claim` `{ code }` → `{ token, user }`
- `POST /api/guias` multipart + Bearer token
- `GET /api/guias/estructura` (opcional, zonas)

---

Exportadora Romex S.A.
