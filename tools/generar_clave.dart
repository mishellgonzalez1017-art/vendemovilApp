// Generador de claves de licencia (solo para ti, el dueño de la app).
//
// Uso (desde la carpeta del proyecto):
//   dart run tools/generar_clave.dart --dias 30
//   dart run tools/generar_clave.dart --hasta 2026-11-05
//
// El secreto se lee de la variable de entorno LICENSE_SECRET y debe ser el
// MISMO que usaste al compilar la app (--dart-define=LICENSE_SECRET=...).
// Mira LICENCIAS.md para los pasos completos.
import 'dart:io';
import '../lib/services/licencia_clave.dart';

void main(List<String> args) {
  final secreto = Platform.environment['LICENSE_SECRET'] ?? '';
  if (secreto.isEmpty) {
    stderr.writeln('Falta la variable de entorno LICENSE_SECRET.');
    stderr.writeln('Ejemplo (Windows PowerShell):');
    stderr.writeln('  \$env:LICENSE_SECRET = "tu-secreto"');
    stderr.writeln('Ejemplo (Mac/Linux):');
    stderr.writeln('  export LICENSE_SECRET="tu-secreto"');
    exit(64);
  }

  var dias = 30;
  DateTime? hasta;
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--dias' && i + 1 < args.length) {
      final n = int.tryParse(args[++i]);
      if (n == null || n < 1) {
        stderr.writeln('--dias debe ser un número mayor que 0.');
        exit(64);
      }
      dias = n;
    } else if (args[i] == '--hasta' && i + 1 < args.length) {
      hasta = DateTime.tryParse(args[++i]);
      if (hasta == null) {
        stderr.writeln('--hasta debe tener el formato AAAA-MM-DD.');
        exit(64);
      }
    } else {
      stderr.writeln('Argumento no reconocido: ${args[i]}');
      exit(64);
    }
  }

  final hoy = DateTime.now();
  final vence = hasta ?? DateTime(hoy.year, hoy.month, hoy.day + dias);
  final clave = LicenciaClave.generar(vence, secreto);

  final f = '${vence.year}-'
      '${vence.month.toString().padLeft(2, '0')}-'
      '${vence.day.toString().padLeft(2, '0')}';
  stdout.writeln('');
  stdout.writeln('Clave:  $clave');
  stdout.writeln('Vale hasta el final del día $f');
  stdout.writeln('');
}
