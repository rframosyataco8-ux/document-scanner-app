# DocScan Pro · RomEx (v1.5.4)

App Flutter de escaneo de documentos conectada al **Sistema de Guías de Cacao**.

- ML Kit Document Scanner (cámara nativa)
- Emparejamiento por **QR + JWT** (sin Firebase)
- Cola **offline** (SQLite)
- Splash animado + icono Romex

Va de la mano con: https://github.com/rframosyataco8-ux/sistema-guias-cacao

---

## Requisitos

- Flutter estable instalado (`flutter doctor`)
- Celular Android con **Depuración USB**
- Node.js 18+ (para el sistema de guías en la PC)
- Misma Wi‑Fi PC + celular (solo en pruebas locales)

---

## Guía rápida (Git Bash en Windows)

### 1. Clonar
```bash
cd ~
git clone https://github.com/rframosyataco8-ux/document-scanner-app.git
cd document-scanner-app
```

### 2. Dependencias
```bash
flutter pub get
```

### 3. Celular autorizado
```bash
export PATH="$PATH:/c/src/android-sdk/platform-tools"
adb devices
# Debe decir: XXXXXXXX    device  (no unauthorized)
```

### 4. Ejecutar
```bash
flutter run
```

### 5. Conectar al sistema de guías
En la app → **Ajustes** → URL:
```text
http://IP_DE_TU_PC:4000
```
(ejemplo: `http://192.168.0.112:4000`) → **Probar** → **Guardar**.

Luego en la web del sistema: **Conectar móvil** → generar QR → escanear en la app.

---

Exportadora Romex S.A.
