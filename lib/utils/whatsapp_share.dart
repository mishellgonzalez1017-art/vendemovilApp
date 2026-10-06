import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Abre WhatsApp con el ticket en texto (nunca PDF ni archivo).
class WhatsAppShare {
  /// Normaliza a dígitos internacionales. 9XXXXXXXX (Perú) → 519XXXXXXXX.
  static String? normalizarNumero(String input) {
    var d = input.replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('00')) d = d.substring(2);
    if (d.startsWith('0')) d = d.substring(1);
    if (d.length == 9 && d.startsWith('9')) d = '51$d';
    if (d.length < 10 || d.length > 15) return null;
    return d;
  }

  static Future<bool> enviar({
    required String texto,
    String? numero,
  }) async {
    if (numero != null && numero.isNotEmpty) {
      final encoded = Uri.encodeComponent(texto);
      final uris = [
        Uri.parse('whatsapp://send?phone=$numero&text=$encoded'),
        Uri.parse('https://wa.me/$numero?text=$encoded'),
      ];
      for (final uri in uris) {
        try {
          if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
            return true;
          }
        } catch (_) {}
      }
      return false;
    }

    await SharePlus.instance.share(ShareParams(text: texto));
    return true;
  }
}
