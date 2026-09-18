# DocScan Pro · RomEx (v1.4)

App Flutter de escaneo conectada al Sistema de Guías de Cacao.

## v1.4 — implementado en código

### Integración con base de datos local (SQLite)
- Tabla `documents` en `romex_docscan.db` (sqflite).
- Índices por `status` y `created_at`.
- Migración automática desde SharedPreferences.
- Cola offline y metadatos de guía persistidos en SQLite.

### Seguridad de tokens FCM / JWT
- JWT y FCM en **flutter_secure_storage** (EncryptedSharedPreferences en Android).
- Validación de token FCM plausible antes de enviarlo al backend.
- Logs solo con token **enmascarado** (`abc123…xyz9`).
- Limpieza de sesión al desconectar; no se imprime el secreto completo.

### Validación de red por pasos
Antes de escanear QR o subir guía se ejecuta:
1. Conectividad del dispositivo
2. Formato de URL (bloquea localhost en móvil)
3. Resolución DNS/IP del host
4. Ping a la API
5. Sesión QR (si aplica)

UI: bottom sheet con cada paso en vivo + reintentar.

## Cola offline + FCM
- Sin red → estado `queued` → reintento automático al recuperar conexión.
- FCM opcional (requiere `google-services.json`).

```bash
git pull
flutter pub get
flutter run
```

---
Exportadora Romex S.A.
