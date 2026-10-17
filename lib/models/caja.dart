import 'dart:convert';

/// Redondea a centavos para evitar diferencias raras de decimales.
double redondear2(double v) => (v * 100).round() / 100;

/// Periodos del cuadre de caja y cómo se calculan sus fechas.
class PeriodoCaja {
  static const dia = 'dia';
  static const semana = 'semana';
  static const mes = 'mes';
  static const todos = [dia, semana, mes];

  static String nombre(String periodo) {
    if (periodo == semana) return 'Semana';
    if (periodo == mes) return 'Mes';
    return 'Día';
  }

  /// Rango completo (inicio y fin) del periodo que contiene [ref].
  /// La semana empieza el lunes.
  static ({DateTime desde, DateTime hasta}) rango(String periodo, DateTime ref) {
    if (periodo == semana) {
      final lunes = DateTime(ref.year, ref.month, ref.day - (ref.weekday - 1));
      return (
        desde: lunes,
        hasta: DateTime(lunes.year, lunes.month, lunes.day + 6, 23, 59, 59, 999),
      );
    }
    if (periodo == mes) {
      return (
        desde: DateTime(ref.year, ref.month, 1),
        hasta: DateTime(ref.year, ref.month + 1, 0, 23, 59, 59, 999),
      );
    }
    return (
      desde: DateTime(ref.year, ref.month, ref.day),
      hasta: DateTime(ref.year, ref.month, ref.day, 23, 59, 59, 999),
    );
  }

  /// Mueve la fecha de referencia [pasos] periodos (negativo = hacia atrás).
  static DateTime mover(String periodo, DateTime ref, int pasos) {
    if (periodo == semana) {
      return DateTime(ref.year, ref.month, ref.day + 7 * pasos);
    }
    if (periodo == mes) return DateTime(ref.year, ref.month + pasos, 1);
    return DateTime(ref.year, ref.month, ref.day + pasos);
  }
}

/// Números de las ventas de un periodo (se calculan, no se guardan).
class ResumenCuadre {
  final Map<String, double> ventasPorMetodo;
  final Map<String, int> conteoPorMetodo;

  /// Ganancia del periodo; null si los productos no tienen precio de compra.
  final double? ganancia;

  ResumenCuadre({
    required this.ventasPorMetodo,
    required this.conteoPorMetodo,
    this.ganancia,
  });

  double get totalVendido =>
      redondear2(ventasPorMetodo.values.fold(0.0, (s, v) => s + v));

  int get numVentas => conteoPorMetodo.values.fold(0, (s, v) => s + v);

  /// Solo las ventas en efectivo entran al cajón.
  double get efectivoPeriodo => ventasPorMetodo['efectivo'] ?? 0;

  /// Efectivo que debería haber: fondo inicial + ventas en efectivo.
  double esperado(double fondoInicial) =>
      redondear2(fondoInicial + efectivoPeriodo);

  /// Positivo = sobra, negativo = falta.
  double diferencia(double fondoInicial, double contado) =>
      redondear2(contado - esperado(fondoInicial));

  Map<String, Map<String, num>> get detalleMetodos => {
        for (final k in ventasPorMetodo.keys)
          k: {'n': conteoPorMetodo[k] ?? 0, 'total': ventasPorMetodo[k] ?? 0},
      };
}

/// Un cuadre. Cuando está guardado es un "cierre". Mientras se está llenando
/// en pantalla puede tener [efectivoContado] y [diferencia] en null.
class CierreCaja {
  final String id;
  final String periodo;
  final DateTime desde;
  final DateTime hasta;
  final DateTime fechaCierre;
  final double fondoInicial;
  final double efectivoPeriodo;
  final double efectivoEsperado;
  final double? efectivoContado;
  final double? diferencia;
  final double totalVendido;
  final int numVentas;
  final double? ganancia;
  final Map<String, Map<String, num>> detalleMetodos;
  final String? nota;

  CierreCaja({
    required this.id,
    required this.periodo,
    required this.desde,
    required this.hasta,
    required this.fechaCierre,
    required this.fondoInicial,
    required this.efectivoPeriodo,
    required this.efectivoEsperado,
    this.efectivoContado,
    this.diferencia,
    required this.totalVendido,
    required this.numVentas,
    this.ganancia,
    this.detalleMetodos = const {},
    this.nota,
  });

  /// Arma el cuadre a partir de un resumen y lo que escribió el usuario.
  factory CierreCaja.desdeResumen({
    required String id,
    required String periodo,
    required DateTime desde,
    required DateTime hasta,
    required ResumenCuadre resumen,
    required double fondoInicial,
    double? efectivoContado,
    String? nota,
  }) {
    final fondo = redondear2(fondoInicial);
    final contado =
        efectivoContado == null ? null : redondear2(efectivoContado);
    return CierreCaja(
      id: id,
      periodo: periodo,
      desde: desde,
      hasta: hasta,
      fechaCierre: DateTime.now(),
      fondoInicial: fondo,
      efectivoPeriodo: resumen.efectivoPeriodo,
      efectivoEsperado: resumen.esperado(fondo),
      efectivoContado: contado,
      diferencia: contado == null ? null : resumen.diferencia(fondo, contado),
      totalVendido: resumen.totalVendido,
      numVentas: resumen.numVentas,
      ganancia: resumen.ganancia,
      detalleMetodos: resumen.detalleMetodos,
      nota: (nota == null || nota.trim().isEmpty) ? null : nota.trim(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'periodo': periodo,
        'desde': desde.toIso8601String(),
        'hasta': hasta.toIso8601String(),
        'fecha_cierre': fechaCierre.toIso8601String(),
        'fondo_inicial': fondoInicial,
        'efectivo_periodo': efectivoPeriodo,
        'efectivo_esperado': efectivoEsperado,
        'efectivo_contado': efectivoContado,
        'diferencia': diferencia,
        'total_vendido': totalVendido,
        'num_ventas': numVentas,
        'ganancia': ganancia,
        'detalle_metodos':
            detalleMetodos.isEmpty ? null : jsonEncode(detalleMetodos),
        'nota': nota,
      };

  factory CierreCaja.fromMap(Map<String, dynamic> m) {
    final Map<String, Map<String, num>> detalle = {};
    final raw = m['detalle_metodos'] as String?;
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      decoded.forEach((k, v) {
        final inner = v as Map<String, dynamic>;
        detalle[k] = {
          'n': (inner['n'] as num?) ?? 0,
          'total': (inner['total'] as num?) ?? 0,
        };
      });
    }
    return CierreCaja(
      id: m['id'] as String,
      periodo: m['periodo'] as String,
      desde: DateTime.parse(m['desde'] as String),
      hasta: DateTime.parse(m['hasta'] as String),
      fechaCierre: DateTime.parse(m['fecha_cierre'] as String),
      fondoInicial: (m['fondo_inicial'] as num).toDouble(),
      efectivoPeriodo: (m['efectivo_periodo'] as num).toDouble(),
      efectivoEsperado: (m['efectivo_esperado'] as num).toDouble(),
      efectivoContado: (m['efectivo_contado'] as num?)?.toDouble(),
      diferencia: (m['diferencia'] as num?)?.toDouble(),
      totalVendido: (m['total_vendido'] as num).toDouble(),
      numVentas: (m['num_ventas'] as num).toInt(),
      ganancia: (m['ganancia'] as num?)?.toDouble(),
      detalleMetodos: detalle,
      nota: m['nota'] as String?,
    );
  }
}
