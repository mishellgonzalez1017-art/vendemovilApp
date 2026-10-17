import 'package:flutter_test/flutter_test.dart';
import 'package:vendemas/models/caja.dart';

void main() {
  group('ResumenCuadre', () {
    final resumen = ResumenCuadre(
      ventasPorMetodo: {'efectivo': 150.50, 'tarjeta': 80, 'yape': 20},
      conteoPorMetodo: {'efectivo': 6, 'tarjeta': 2, 'yape': 1},
      ganancia: 60,
    );

    test('totales del periodo', () {
      expect(resumen.totalVendido, 250.50);
      expect(resumen.numVentas, 9);
      // Solo las ventas en efectivo entran al cajón.
      expect(resumen.efectivoPeriodo, 150.50);
    });

    test('esperado = fondo inicial + efectivo del periodo', () {
      expect(resumen.esperado(200), 350.50);
      expect(resumen.esperado(0), 150.50);
    });

    test('diferencia: positiva sobra, negativa falta, cero cuadra', () {
      expect(resumen.diferencia(200, 340.50), -10); // faltan 10
      expect(resumen.diferencia(200, 360.50), 10); // sobran 10
      expect(resumen.diferencia(200, 350.50), 0); // cuadra
    });

    test('sin ventas en efectivo solo cuenta el fondo', () {
      final r = ResumenCuadre(
        ventasPorMetodo: {'tarjeta': 500},
        conteoPorMetodo: {'tarjeta': 3},
      );
      expect(r.esperado(100), 100);
      expect(r.ganancia, isNull);
    });

    test('redondear2 evita errores de decimales', () {
      expect(redondear2(0.1 + 0.2), 0.3);
      expect(redondear2(12.3456), 12.35);
    });
  });

  group('PeriodoCaja', () {
    // 2026-10-15 es jueves.
    final jueves = DateTime(2026, 10, 15, 13, 30);

    test('día', () {
      final r = PeriodoCaja.rango(PeriodoCaja.dia, jueves);
      expect(r.desde, DateTime(2026, 10, 15));
      expect(r.hasta, DateTime(2026, 10, 15, 23, 59, 59, 999));
    });

    test('semana empieza el lunes y termina el domingo', () {
      final r = PeriodoCaja.rango(PeriodoCaja.semana, jueves);
      expect(r.desde, DateTime(2026, 10, 12));
      expect(r.hasta, DateTime(2026, 10, 18, 23, 59, 59, 999));
    });

    test('mes cubre del 1 al último día', () {
      final r = PeriodoCaja.rango(PeriodoCaja.mes, jueves);
      expect(r.desde, DateTime(2026, 10, 1));
      expect(r.hasta, DateTime(2026, 10, 31, 23, 59, 59, 999));
      final feb = PeriodoCaja.rango(PeriodoCaja.mes, DateTime(2028, 2, 10));
      expect(feb.hasta.day, 29); // año bisiesto
    });

    test('mover cambia de periodo sin desbordar meses', () {
      expect(PeriodoCaja.mover(PeriodoCaja.dia, jueves, -1).day, 14);
      expect(PeriodoCaja.mover(PeriodoCaja.semana, jueves, 1).day, 22);
      final ene = PeriodoCaja.mover(PeriodoCaja.mes, DateTime(2026, 3, 31), -1);
      expect(ene.month, 2);
      final prox = PeriodoCaja.mover(PeriodoCaja.mes, DateTime(2026, 12, 15), 1);
      expect(prox.year, 2027);
      expect(prox.month, 1);
    });
  });

  group('CierreCaja', () {
    test('desdeResumen calcula esperado y diferencia', () {
      final resumen = ResumenCuadre(
        ventasPorMetodo: {'efectivo': 100},
        conteoPorMetodo: {'efectivo': 4},
      );
      final c = CierreCaja.desdeResumen(
        id: 'x',
        periodo: PeriodoCaja.dia,
        desde: DateTime(2026, 10, 15),
        hasta: DateTime(2026, 10, 15, 23, 59, 59),
        resumen: resumen,
        fondoInicial: 50,
        efectivoContado: 140,
        nota: '  turno de la tarde ',
      );
      expect(c.efectivoEsperado, 150);
      expect(c.diferencia, -10);
      expect(c.nota, 'turno de la tarde');
    });

    test('sin efectivo contado no hay diferencia (no se muestra falta)', () {
      final c = CierreCaja.desdeResumen(
        id: '',
        periodo: PeriodoCaja.dia,
        desde: DateTime(2026, 10, 15),
        hasta: DateTime(2026, 10, 15, 23, 59, 59),
        resumen: ResumenCuadre(ventasPorMetodo: {}, conteoPorMetodo: {}),
        fondoInicial: 50,
      );
      expect(c.efectivoContado, isNull);
      expect(c.diferencia, isNull);
    });

    test('toMap / fromMap conserva todo', () {
      final c = CierreCaja.desdeResumen(
        id: 'abc',
        periodo: PeriodoCaja.semana,
        desde: DateTime(2026, 10, 12),
        hasta: DateTime(2026, 10, 18, 23, 59, 59, 999),
        resumen: ResumenCuadre(
          ventasPorMetodo: {'efectivo': 150.5, 'tarjeta': 80},
          conteoPorMetodo: {'efectivo': 6, 'tarjeta': 2},
          ganancia: 55.25,
        ),
        fondoInicial: 200,
        efectivoContado: 340,
        nota: 'ok',
      );
      final copia = CierreCaja.fromMap(c.toMap());
      expect(copia.periodo, PeriodoCaja.semana);
      expect(copia.desde, c.desde);
      expect(copia.efectivoEsperado, 350.5);
      expect(copia.diferencia, -10.5);
      expect(copia.ganancia, 55.25);
      expect(copia.numVentas, 8);
      expect(copia.detalleMetodos['efectivo']!['n'], 6);
      expect(copia.detalleMetodos['tarjeta']!['total'], 80);
      expect(copia.nota, 'ok');
    });
  });
}
