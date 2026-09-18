# DocScan Pro · RomEx (v1.3)

App Flutter de escaneo conectada al **Sistema de Guías de Cacao**.

## Novedades v1.3

### Cola offline automática
- Si falla la subida por red, el documento pasa a estado **queued**.
- Al recuperar Wi‑Fi/datos, `UploadQueue` reintenta sola (hasta 8 veces).
- Banner naranja en home + filtro **En cola** + botón en Ajustes «Procesar cola ahora».

### Notificaciones push FCM
- Tras emparejar QR, registra el token en `POST /api/devices/register`.
- Compatible con el backend (`device_tokens` + `notifyGuiaUploaded`).
- Si Firebase no está configurado, la app **sigue funcionando** (FCM opcional).

## Activar FCM (opcional)

1. Crea un proyecto en [Firebase Console](https://console.firebase.google.com).
2. Añade app Android con package `com.example.document_scanner_app` (o cambia el applicationId).
3. Descarga `google-services.json` → colócalo en `android/app/`.
4. En `android/settings.gradle` (o el root build) asegúrate de tener el plugin Google Services.
5. En `android/app/build.gradle` descomenta:
   ```gradle
   id "com.google.gms.google-services"
   ```
6. En el backend define `FIREBASE_SERVICE_ACCOUNT` (JSON de cuenta de servicio).
7. `flutter clean && flutter pub get && flutter run`

## Flujo de campo

1. Ajustes → URL del servidor (IP de la PC).
2. Escanear QR de Conectar móvil.
3. Escanear guía → Subir → si no hay red, queda en cola y se envía sola después.

## Correr

```bash
git pull
flutter pub get
flutter run
```

---
Exportadora Romex S.A.
