import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';

/// Soporte y mantenimiento — WhatsApp.
class SoporteConfig {
  // TODO: poner el número real (código de país 502 + 8 dígitos).
  static const whatsappNumero = '502XXXXXXXX';
  static const whatsappDisplay = '+502 XXXX XXXX';
  static const desarrollador = AppConfig.nombre;
  static const mensajePro = 'Hola, necesito soporte con ${AppConfig.nombre}';

  static Uri whatsappUri({String? mensaje}) {
    final base = 'https://wa.me/$whatsappNumero';
    if (mensaje == null || mensaje.isEmpty) return Uri.parse(base);
    return Uri.parse('$base?text=${Uri.encodeComponent(mensaje)}');
  }

  static Future<bool> abrirWhatsApp({String? mensaje}) async {
    return launchUrl(
      whatsappUri(mensaje: mensaje),
      mode: LaunchMode.externalApplication,
    );
  }
}
