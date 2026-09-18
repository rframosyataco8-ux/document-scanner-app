# DocScan Pro · RomEx

App Flutter de escaneo de documentos **conectada al Sistema de Guías de Cacao**.

Al escanear el **QR de “Conectar móvil”** generado en la PC, la app obtiene un JWT del usuario y puede subir guías (PDF + metadatos) al backend real.

## Flujo de conexión QR

1. En la PC (sistema-guias-cacao) abre **Conectar móvil** y pulsa **Generar código QR**.
2. En el celular abre DocScan Pro → **Conectar al sistema** (o el icono QR).
3. Escanea el QR (o escribe el código manualmente, ej. `SKV6MR4T`).
4. La app llama a `POST /api/pair/claim` y guarda el token.
5. Escanea la guía (ML Kit genera PDF) → **Subir al sistema** → completa número, zona, fecha, sacos/kilos.
6. Se envía a `POST /api/guias` con el PDF y el Bearer token.

El código es de un solo uso y expira en 15 minutos (igual que en el backend).

## Configurar URL del servidor

Desde el celular **no uses `localhost`**. En **Ajustes** pon la IP de la PC en la red local, por ejemplo:

```
http://192.168.1.20:3000
```

Si el QR contiene una URL con host real (no localhost), la app intenta guardar esa base automáticamente.

Para emulador Android, el valor por defecto `http://10.0.2.2:3000` apunta al host de la máquina.

## Arquitectura

```
lib/
├── main.dart
├── models/
│   └── scanned_document.dart
├── services/
│   ├── api_config.dart       ← URL base + token de sesión QR
│   ├── pairing_service.dart  ← extractCode + claim
│   └── document_service.dart ← local + upload real a /api/guias
└── screens/
    ├── home_screen.dart
    ├── qr_pair_screen.dart   ← cámara QR (mobile_scanner)
    ├── preview_screen.dart   ← formulario de guía + subida
    └── settings_screen.dart
```

## Dependencias principales

- `google_mlkit_document_scanner` — escaneo profesional PDF/JPEG
- `mobile_scanner` — lectura del QR de emparejamiento
- `http` — pair/claim y multipart a /api/guias
- `shared_preferences` — documentos locales + sesión

## Cómo actualizar y correr

```bash
git pull
flutter pub get
flutter run   # dispositivo Android físico recomendado (cámara)
```

Permisos: cámara e internet (AndroidManifest). `usesCleartextTraffic` habilitado para HTTP en red local.

## Backend esperado

Compatible con el repo **sistema-guias-cacao**:

- `POST /api/pair/claim` `{ "code": "XXXX" }` → `{ token, user }`
- `POST /api/guias` (multipart: `archivo` PDF + `numero_guia`, `zona`, `fecha_recepcion`, opc. `cantidad_sacos`, `kilos`) con header `Authorization: Bearer <token>`

---

Diseñado para el flujo real de acopio de guías en Exportadora Romex S.A.
