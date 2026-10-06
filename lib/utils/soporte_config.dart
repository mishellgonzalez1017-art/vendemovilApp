import 'package:url_launcher/url_launcher.dart';

/// Soporte Edax Agency — WhatsApp.
class SoporteConfig {
  static const whatsappNumero = '51973282798';
  static const whatsappDisplay = '+51 973 282 798';
  static const desarrollador = 'Edax Agency';
  static const mensajePro = 'quiero la version pro+';

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
