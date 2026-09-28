# DocScan Pro · RomEx (v1.5.1)

App Flutter de escaneo conectada al **Sistema de Guías de Cacao**.

- ML Kit Document Scanner
- QR + JWT (sin Firebase)
- Cola offline SQLite
- Splash animado + icono Romex

## Prueba local (misma Wi‑Fi)

### 1. Backend
```bash
cd sistema-guias-cacao/backend
cp .env.example .env   # si aún no tienes .env
npm install && npm run seed && npm run dev
```
Al arrancar verás algo como:
```text
Desde el celular: http://192.168.x.x:4000
```

### 2. Frontend (QR)
```bash
cd sistema-guias-cacao/frontend
npm install && npm run dev
```
En **Conectar móvil**, escribe la base API LAN (`http://IP:4000`) y genera el QR.

### 3. App
```bash
cd document-scanner-app
git pull
flutter clean && flutter pub get
# Celular autorizado: adb devices → device
flutter run
```
Ajustes → misma URL `http://IP:4000` → Probar → Guardar → escanear QR.

## Producción (más adelante)
URL `https://tu-dominio.com` · Nginx · Let’s Encrypt · JWT_SECRET fuerte.

---
Exportadora Romex S.A.
