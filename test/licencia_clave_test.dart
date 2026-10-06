import 'package:flutter_test/flutter_test.dart';
import 'package:vendemas/services/licencia_clave.dart';

// Las claves esperadas se calcularon con tools/generar_clave.py, así que este
// test comprueba que la app y el generador producen exactamente lo mismo.
void main() {
  const secreto = 'secreto-de-prueba';

  test('genera las claves esperadas', () {
    expect(
      LicenciaClave.generar(DateTime(2026, 11, 5), secreto),
      'VM-261105-549KV7CG',
    );
    expect(
      LicenciaClave.generar(DateTime(2027, 1, 31), secreto),
      'VM-270131-GA35MXTR',
    );
  });

  test('acepta una clave válida y devuelve el fin del día de vencimiento', () {
    expect(
      LicenciaClave.vencimientoDe('VM-261105-549KV7CG', secreto),
      DateTime(2026, 11, 5, 23, 59, 59),
    );
  });

  test('tolera minúsculas, espacios y guiones al copiar a mano', () {
    expect(
      LicenciaClave.vencimientoDe(' vm 261105 549kv7cg ', secreto),
      DateTime(2026, 11, 5, 23, 59, 59),
    );
  });

  test('rechaza otro secreto', () {
    expect(
      LicenciaClave.vencimientoDe('VM-261105-549KV7CG', 'otro-secreto'),
      isNull,
    );
  });

  test('rechaza claves alteradas o incompletas', () {
    expect(LicenciaClave.vencimientoDe('VM-261105-549KV7CA', secreto), isNull);
    expect(LicenciaClave.vencimientoDe('VM-261205-549KV7CG', secreto), isNull);
    expect(LicenciaClave.vencimientoDe('VM-261105', secreto), isNull);
    expect(LicenciaClave.vencimientoDe('', secreto), isNull);
  });

  test('ida y vuelta para cualquier fecha', () {
    final fecha = DateTime(2028, 2, 29);
    final clave = LicenciaClave.generar(fecha, secreto);
    expect(
      LicenciaClave.vencimientoDe(clave, secreto),
      DateTime(2028, 2, 29, 23, 59, 59),
    );
  });
}
