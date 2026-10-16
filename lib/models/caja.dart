import 'dart:convert';

/// Redondea a centavos para evitar diferencias raras de decimales.
double redondear2(double v) => (v * 100).round() / 100;

/// Un turno de caja: se abre con un fondo inicial y se cierra contando el efectivo.
class Caja {
  final String id;
  final DateTime fechaApertura;
  final double fondoInicial;

  // Datos del cierre (null mientras la caja está abierta).
  final DateTime? fechaCierre;
  final double? efectivoContado;
  final double? efectivoEsperado;
  final double? diferencia;
  final double? totalVentas;
  final int? numVentas;
  final double? totalIngresos;
  final double? totalGastos;

  /// Ventas por método de pago al momento del cierre: {metodo: {'n': cantidad, 'total': monto}}
  final Map<String, Map<String, num>> detalleMetodos;
  final String? nota;

  Caja({
    required this.id,
    required this.fechaApertura,
    required this.fondoInicial,
    this.fechaCierre,
    this.efectivoContado,
    this.efectivoEsperado,
    this.diferencia,
    this.totalVentas,
    this.numVentas,
    this.totalIngresos,
    this.totalGastos,
    this.detalleMetodos = const {},
    this.nota,
  });

  bool get abierta => fechaCierre == null;

  Map<String, dynamic> toMap() => {
        'id': id,
        'fecha_apertura': fechaApertura.toIso8601String(),
        'fondo_inicial': fondoInicial,
        'fecha_cierre': fechaCierre?.toIso8601String(),
        'efectivo_contado': efectivoContado,
        'efectivo_esperado': efectivoEsperado,
        'diferencia': diferencia,
        'total_ventas': totalVentas,
        'num_ventas': numVentas,
        'total_ingresos': totalIngresos,
        'total_gastos': totalGastos,
        'detalle_metodos': detalleMetodos.isEmpty ? null : jsonEncode(detalleMetodos),
        'nota': nota,
      };

  factory Caja.fromMap(Map<String, dynamic> m) {
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
    return Caja(
      id: m['id'] as String,
      fechaApertura: DateTime.parse(m['fecha_apertura'] as String),
      fondoInicial: (m['fondo_inicial'] as num).toDouble(),
      fechaCierre: m['fecha_cierre'] == null
          ? null
          : DateTime.parse(m['fecha_cierre'] as String),
      efectivoContado: (m['efectivo_contado'] as num?)?.toDouble(),
      efectivoEsperado: (m['efectivo_esperado'] as num?)?.toDouble(),
      diferencia: (m['diferencia'] as num?)?.toDouble(),
      totalVentas: (m['total_ventas'] as num?)?.toDouble(),
      numVentas: (m['num_ventas'] as num?)?.toInt(),
      totalIngresos: (m['total_ingresos'] as num?)?.toDouble(),
      totalGastos: (m['total_gastos'] as num?)?.toDouble(),
      detalleMetodos: detalle,
      nota: m['nota'] as String?,
    );
  }
}

/// Entrada o salida de efectivo de la gaveta que no es una venta
/// (ej. pago a proveedor, retiro, o dinero que se agrega).
class MovimientoCaja {
  static const ingreso = 'ingreso';
  static const gasto = 'gasto';

  final String id;
  final String cajaId;
  final String tipo; // 'ingreso' | 'gasto'
  final double monto;
  final String concepto;
  final DateTime fecha;

  MovimientoCaja({
    required this.id,
    required this.cajaId,
    required this.tipo,
    required this.monto,
    required this.concepto,
    DateTime? fecha,
  }) : fecha = fecha ?? DateTime.now();

  bool get esGasto => tipo == gasto;

  Map<String, dynamic> toMap() => {
        'id': id,
        'caja_id': cajaId,
        'tipo': tipo,
        'monto': monto,
        'concepto': concepto,
        'fecha': fecha.toIso8601String(),
      };

  factory MovimientoCaja.fromMap(Map<String, dynamic> m) => MovimientoCaja(
        id: m['id'] as String,
        cajaId: m['caja_id'] as String,
        tipo: m['tipo'] as String,
        monto: (m['monto'] as num).toDouble(),
        concepto: m['concepto'] as String? ?? '',
        fecha: DateTime.parse(m['fecha'] as String),
      );
}

/// Números calculados de una caja abierta (en vivo).
class ResumenCaja {
  final double fondoInicial;
  final Map<String, double> ventasPorMetodo;
  final Map<String, int> conteoPorMetodo;
  final double ingresos;
  final double gastos;

  ResumenCaja({
    required this.fondoInicial,
    required this.ventasPorMetodo,
    required this.conteoPorMetodo,
    required this.ingresos,
    required this.gastos,
  });

  double get totalVentas =>
      ventasPorMetodo.values.fold(0.0, (s, v) => s + v);

  int get numVentas => conteoPorMetodo.values.fold(0, (s, v) => s + v);

  double get ventasEfectivo => ventasPorMetodo['efectivo'] ?? 0;

  /// Efectivo que debería haber en la gaveta:
  /// fondo + ventas en efectivo + ingresos - gastos.
  double get efectivoEsperado =>
      redondear2(fondoInicial + ventasEfectivo + ingresos - gastos);

  Map<String, Map<String, num>> get detalleMetodos => {
        for (final k in ventasPorMetodo.keys)
          k: {'n': conteoPorMetodo[k] ?? 0, 'total': ventasPorMetodo[k] ?? 0},
      };
}
