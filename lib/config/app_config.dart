/// Datos de marca de la app en un solo lugar.
///
/// Si algún día cambias el nombre, hazlo aquí. Las pantallas, el ticket
/// y los textos legales lo leen de este archivo.
///
/// Los nombres que ve el teléfono bajo el ícono están en archivos nativos y se
/// cambian aparte:
///  - Android: `android/app/src/main/AndroidManifest.xml` (android:label)
///  - iOS: `ios/Runner/Info.plist` (CFBundleDisplayName y CFBundleName)
class AppConfig {
  /// Nombre de la app.
  static const nombre = 'Vende GT';

  /// Mismo nombre en mayúsculas (nombre del negocio por defecto en el ticket).
  static const nombreMayus = 'VENDE GT';

  /// Sin acentos, para la impresora térmica (no imprime tildes).
  static const nombreSinAcentos = 'Vende GT';
  static const nombreSinAcentosMayus = 'VENDE GT';

  /// Versión que se muestra en el pie del ticket.
  static const version = '2.0';
}
