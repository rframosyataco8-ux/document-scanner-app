# DocScan Pro · RomEx (v1.5.0)

App Flutter de escaneo de documentos conectada al **Sistema de Guías de Cacao**.

- **ML Kit Document Scanner** (cámara nativa)
- Emparejamiento por **QR** con la PC
- Cola **offline** (SQLite)
- **Sin Firebase** / sin notificaciones push
- Splash animado + icono de marca

Va de la mano con el repo `sistema-guias-cacao` (backend puerto **4000**).

---

## Arranque rápido

```bash
git pull origin main
flutter clean
flutter pub get
flutter run
```

### Celular (importante)

1. Depuración USB autorizada (`adb devices` → `device`, no `unauthorized`).
2. En **Ajustes** de la app, URL del backend:
   ```
   http://IP_DE_LA_PC:4000
   ```
3. En la PC: Sistema de Guías → **Conectar móvil** → escanear QR.

### Backend (sistema-guias-cacao)

```bash
cd backend && npm run dev   # http://localhost:4000
cd frontend && npm run dev  # http://localhost:5173
```

---

Exportadora Romex S.A.
