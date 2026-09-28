# DocScan Pro · RomEx (v1.4.1)

App Flutter de escaneo de documentos conectada al **Sistema de Guías de Cacao** (Exportadora Romex S.A.).

Usa **Google ML Kit Document Scanner** (interfaz nativa tipo escáner del celular), emparejamiento por **QR**, cola **offline**, SQLite local y FCM opcional.

---

## Qué ya está listo (v1.4.1)

| Área | Estado |
|------|--------|
| Escaneo multi-página JPEG + PDF (ML Kit) | ✅ |
| Vista previa, compartir, eliminar | ✅ |
| Subida de guía (número, zona, fecha, sacos, kilos) | ✅ |
| Emparejamiento QR / código manual | ✅ |
| SQLite local + migración desde SharedPreferences | ✅ |
| Cola offline + reintento al recuperar red | ✅ |
| Validación de red por pasos (UI bottom sheet) | ✅ |
| Tokens JWT/FCM en almacenamiento seguro | ✅ |
| Barra de estado de red en tiempo real | ✅ |
| Scaffold Android completo (compila e instala) | ✅ |
| FCM (push) | ⚪ Opcional — requiere `google-services.json` |

---

## Requisitos en tu PC

1. **Flutter SDK** ≥ 3.16 (`flutter doctor` sin errores críticos de Android).
2. **Android Studio** (SDK Platform 34+, build-tools, platform-tools).
3. Extensión **Flutter** + **Dart** en **VS Code**.
4. Celular Android con **Depuración USB** activada (Ajustes → Opciones de desarrollador).

---

## Pasos para ejecutar en el celular desde VS Code

### 1. Clonar / actualizar el proyecto

```bash
cd ~/proyectos   # o la carpeta que uses
git clone https://github.com/rframosyataco8-ux/document-scanner-app.git
cd document-scanner-app
# Si ya lo tenías:
git pull origin main
```

### 2. Dependencias

```bash
flutter pub get
```

### 3. Conectar el celular

**Opción A — USB**
1. Cable USB al PC.
2. En el teléfono: permite **Depuración USB** cuando aparezca el diálogo.
3. Verifica:

```bash
flutter devices
```

Debe listar tu dispositivo (ej. `SM-A5xx · android-arm64`).

**Opción B — Wi‑Fi (Android 11+)**
```bash
adb tcpip 5555
adb connect IP_DEL_CELULAR:5555
flutter devices
```

### 4. Abrir en VS Code y correr

1. Abre la carpeta del proyecto en VS Code (`File → Open Folder`).
2. Abre la paleta: `Ctrl+Shift+P` (Windows/Linux) o `Cmd+Shift+P` (Mac).
3. Elige **Flutter: Select Device** → tu celular.
4. Pulsa **F5** o el botón ▶ **Run** (modo Debug).

O desde la terminal integrada de VS Code:

```bash
flutter run
```

La primera compilación puede tardar 1–3 minutos. Luego la app se instala sola en el teléfono.

### 5. Configurar la URL del servidor (importante)

En el **celular no uses** `localhost` ni `10.0.2.2` (eso es solo para emulador).

1. En la app: **Ajustes** (engranaje).
2. URL base API, ejemplo en la misma Wi‑Fi:

```text
http://192.168.1.45:3000
```

(Sustituye por la IP de la PC donde corre el backend del Sistema de Guías.)

3. **Probar** → debe responder OK.
4. **Guardar**.

### 6. Emparejar con el sistema

1. En la PC, en el Sistema de Guías, abre **Conectar móvil** y muestra el QR.
2. En la app: icono de QR o el banner "Escanea el QR…".
3. Escanea (o ingresa el código manual).
4. Verás "Conectado como …".

### 7. Probar el flujo completo

1. Toca el botón circular **Escanear**.
2. Usa la cámara ML Kit (recorta, multi-página, genera PDF).
3. En la vista previa → **Subir guía**.
4. Completa número de guía, zona, fecha → **Subir**.
5. Si no hay red, queda en cola offline y se sube sola al recuperar conexión.

---

## FCM (notificaciones) — opcional

Sin `google-services.json` la app **arranca igual**; solo se desactivan los push.

1. Crea proyecto en [Firebase Console](https://console.firebase.google.com).
2. Añade app Android con package `com.romex.docscanpro`.
3. Descarga `google-services.json` → colócalo en `android/app/`.
4. En `android/settings.gradle` y `android/app/build.gradle` descomenta las líneas de `com.google.gms.google-services`.
5. `flutter clean && flutter pub get && flutter run`.

---

## Comandos útiles

```bash
flutter doctor -v          # diagnóstico
flutter devices            # dispositivos
flutter run                # debug en dispositivo seleccionado
flutter run --release      # más rápido, sin hot reload
flutter clean              # si hay errores raros de build
flutter logs               # logs en vivo del dispositivo
```

Hot reload: en la terminal de `flutter run` pulsa `r`. Hot restart: `R`.

---

## Estructura del código

```text
lib/
  main.dart
  models/scanned_document.dart
  screens/   home, preview, upload, qr_pair, settings
  services/  document, local_db, upload_queue, pairing, api_*, fcm, network_*
  theme/
  widgets/
android/                 # scaffold completo listo para build
```

---

Exportadora Romex S.A. · DocScan Pro
