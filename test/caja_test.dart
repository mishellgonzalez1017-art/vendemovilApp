import 'package:flutter_test/flutter_test.dart';
import 'package:vendemas/models/caja.dart';

void main() {
  group('ResumenCaja', () {
    test('efectivo esperado = fondo + ventas en efectivo + ingresos - gastos', () {
      final r = ResumenCaja(
        fondoInicial: 200,
        ventasPorMetodo: {'efectivo': 150.50, 'tarjeta': 80, 'yape': 20},
        conteoPorMetodo: {'efectivo': 6, 'tarjeta': 2, 'yape': 1},
        ingresos: 10,
        gastos: 35.25,
      );
      // Solo las ventas en efectivo entran a la gaveta.
      expect(r.efectivoEsperado, 325.25);
      expect(r.totalVentas, 250.50);
      expect(r.numVentas, 9);
    });

    test('sin ventas en efectivo solo cuenta el fondo', () {
      final r = ResumenCaja(
        fondoInicial: 100,
        ventasPorMetodo: {'tarjeta': 500},
        conteoPorMetodo: {'tarjeta': 3},
        ingresos: 0,
        gastos: 0,
      );
      expect(r.efectivoEsperado, 100);
    });

    test('redondear2 evita errores de decimales', () {
      expect(redondear2(0.1 + 0.2), 0.3);
      expect(redondear2(12.3456), 12.35);
    });
  });

  group('Caja', () {
    test('toMap / fromMap conserva el detalle por método', () {
      final c = Caja(
        id: 'abc',
        fechaApertura: DateTime(2026, 10, 15, 8, 0),
        fondoInicial: 200,
        fechaCierre: DateTime(2026, 10, 15, 18, 30),
        efectivoContado: 340,
        efectivoEsperado: 325.25,
        diferencia: 14.75,
        totalVentas: 250.5,
        numVentas: 9,
        totalIngresos: 10,
        totalGastos: 35.25,
        detalleMetodos: {
          'efectivo': {'n': 6, 'total': 150.5},
        },
        nota: 'Turno de la tarde',
      );
      final copia = Caja.fromMap(c.toMap());
      expect(copia.abierta, false);
      expect(copia.diferencia, 14.75);
      expect(copia.detalleMetodos['efectivo']!['n'], 6);
      expect(copia.detalleMetodos['efectivo']!['total'], 150.5);
      expect(copia.nota, 'Turno de la tarde');
    });

    test('una caja sin fecha de cierre está abierta', () {
      final c = Caja(
        id: 'x',
        fechaApertura: DateTime(2026, 10, 15),
        fondoInicial: 0,
      );
      expect(c.abierta, true);
      expect(Caja.fromMap(c.toMap()).abierta, true);
    });
  });
}
