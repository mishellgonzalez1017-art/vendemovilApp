import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Formato y verificación de las claves de licencia.
///
/// Es Dart puro (sin Flutter) para que lo use tanto la app como el generador
/// `tools/generar_clave.dart`.
///
/// Una clave se ve así:  VM-261105-7K2Q9XWM
///   - "VM"      prefijo fijo
///   - 261105    fecha de vencimiento (aammdd): vale hasta el final de ese día
///   - 7K2Q9XWM  firma (HMAC-SHA256 de la fecha con el secreto, 40 bits)
///
/// Sin el secreto no se puede fabricar una clave que la app acepte.
class LicenciaClave {
  static const _alfabeto = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

  /// Crea la clave que vence al final del día [vence].
  static String generar(DateTime vence, String secreto) {
    final fecha = _aammdd(vence);
    return 'VM-$fecha-${_firma(fecha, secreto)}';
  }

  /// Devuelve el instante de vencimiento (23:59:59 del día indicado) si la
  /// clave es auténtica, o null si el formato o la firma no son válidos.
  static DateTime? vencimientoDe(String clave, String secreto) {
    final limpio = clave.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (limpio.length != 16 || !limpio.startsWith('VM')) return null;

    final fecha = limpio.substring(2, 8);
    if (!RegExp(r'^[0-9]{6}$').hasMatch(fecha)) return null;

    // Tolera confusiones típicas al copiar a mano (O/0, I/L/1).
    final firma = limpio
        .substring(8)
        .replaceAll('O', '0')
        .replaceAll('I', '1')
        .replaceAll('L', '1');
    if (firma != _firma(fecha, secreto)) return null;

    final anio = 2000 + int.parse(fecha.substring(0, 2));
    final mes = int.parse(fecha.substring(2, 4));
    final dia = int.parse(fecha.substring(4, 6));
    final vence = DateTime(anio, mes, dia, 23, 59, 59);
    if (vence.month != mes || vence.day != dia) return null; // fecha imposible
    return vence;
  }

  static String _aammdd(DateTime d) {
    final a = (d.year % 100).toString().padLeft(2, '0');
    final m = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$a$m$dd';
  }

  static String _firma(String fecha, String secreto) {
    final mac = Hmac(sha256, utf8.encode(secreto)).convert(
      utf8.encode('VM1|$fecha'),
    );
    return _base32(mac.bytes.sublist(0, 5));
  }

  /// 5 bytes (40 bits) -> 8 caracteres en base32 (sin I, L, O, U).
  static String _base32(List<int> bytes) {
    final out = StringBuffer();
    var buffer = 0;
    var bits = 0;
    for (final b in bytes) {
      buffer = (buffer << 8) | b;
      bits += 8;
      while (bits >= 5) {
        out.write(_alfabeto[(buffer >> (bits - 5)) & 31]);
        bits -= 5;
        buffer &= (1 << bits) - 1;
      }
    }
    if (bits > 0) {
      out.write(_alfabeto[(buffer << (5 - bits)) & 31]);
    }
    return out.toString();
  }
}
