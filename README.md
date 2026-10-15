# Vende GT

POS Flutter (Android + iOS) para tiendas de Guatemala: venta por unidad o kilos, escáner, tickets térmicos y WhatsApp. Moneda: quetzales (Q). Colores: corinto.

**Versión:** 2.0.0+2  
**Bundle / applicationId:** `com.vendemovil` (se deja igual a propósito: cambiarlo haría que Android lo trate como otra app y se perderían los datos instalados).

App 100% local en el dispositivo. Sin Firebase ni servidor.

## Instalar en tu iPhone (sin App Store)

Sí se puede. No sube a la tienda: se genera un **IPA Ad Hoc** y lo instalas solo en **tu** iPhone.

Necesitas cuenta **Apple Developer** (99 USD/año). Con cuenta gratis de Apple no se puede firmar un IPA en Codemagic para instalarlo estable.

### 1. Registrar tu iPhone

1. En el iPhone: **Ajustes → General → Información**. Copia el **UDID** (o conéctalo a un Mac / usa [udid.tech](https://udid.tech) / Finder).
2. En [developer.apple.com](https://developer.apple.com) → **Certificates, Identifiers & Profiles** → **Devices** → agrega el iPhone (nombre + UDID).
3. Crea el App ID **com.vendemovil** si no existe.

### 2. Codemagic

1. Conecta el repo [mishellgonzalez1017-art/vendemovilApp](https://github.com/mishellgonzalez1017-art/vendemovilApp).
2. **Teams → Code signing identities**: inicia sesión con Apple Developer.
3. Distribution: **Ad Hoc** (no App Store). Bundle ID: `com.vendemovil`.
4. Lanza el workflow **iOS IPA para mi iPhone (Ad Hoc)**.
5. Al terminar, descarga el archivo `.ipa`.

### 3. Instalar el IPA

- **Windows:** [Sideloadly](https://sideloadly.io) o 3uTools, iPhone con cable, elige el `.ipa`.
- **Mac:** Finder (iPhone conectado) o Apple Configurator 2 → arrastra el `.ipa`.
- Primera vez en el iPhone: **Ajustes → General → Administración de VPN y dispositivos** → confiar en el certificado del desarrollador.

El IPA solo funciona en iPhones cuyo UDID registraste. Si cambias de teléfono, hay que registrar el nuevo y volver a compilar.

### Workflows

- **iOS Compile (sin firmar):** solo prueba que compile.
- **iOS IPA para mi iPhone (Ad Hoc):** IPA para instalar directo.

## Local

```bash
flutter pub get
flutter run
```

Android release (con `android/key.properties` y el `.jks` locales, no van al repo):

```bash
flutter build apk --release
```

## Permisos iOS

Cámara (escáner), fotos (QR de transferencia/Tigo Money), Bluetooth (impresora) y ubicación para BLE.

## Secretos

No se suben: `key.properties`, keystores, `.env`, `google-services.json`.

## Marca

- Nombre, en un solo lugar: `lib/config/app_config.dart`. El nombre bajo el ícono está en
  `android/app/src/main/AndroidManifest.xml` y `ios/Runner/Info.plist`.
- Colores: `lib/theme/app_theme.dart` (corinto `#7A1F3D`).
- Ícono: `assets/icon/logo.png`. Si lo cambias, regenera los íconos con
  `dart run flutter_launcher_icons`.
