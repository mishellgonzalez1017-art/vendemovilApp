import '../utils/peso_formatter.dart';

class TipoVenta {
  static const unidad = 'unidad';
  static const peso = 'peso';
}

/// Modelo de Producto para inventario
class Producto {
  final String id;
  final String codigoBarras;
  final String nombre;
  final String? descripcion;
  final String? categoria;
  final double precioCompra;
  final double precioVenta;
  /// Unidades enteras, o gramos si [esPeso].
  final int stock;
  final int stockMinimo;
  final String tipoVenta;
  final String? imagenUrl;
  final DateTime fechaCreacion;
  final DateTime fechaActualizacion;

  Producto({
    required this.id,
    required this.codigoBarras,
    required this.nombre,
    this.descripcion,
    this.categoria,
    required this.precioCompra,
    required this.precioVenta,
    required this.stock,
    this.stockMinimo = 5,
    this.tipoVenta = TipoVenta.unidad,
    this.imagenUrl,
    DateTime? fechaCreacion,
    DateTime? fechaActualizacion,
  })  : fechaCreacion = fechaCreacion ?? DateTime.now(),
        fechaActualizacion = fechaActualizacion ?? DateTime.now();

  bool get esPeso => tipoVenta == TipoVenta.peso;

  double get ganancia => precioVenta - precioCompra;

  double get margenGanancia =>
      precioCompra > 0 ? ((ganancia / precioCompra) * 100) : 0;

  bool get stockBajo => stock <= stockMinimo;

  bool get agotado => stock <= 0;

  String get formatoStock =>
      esPeso ? PesoFormatter.formatGrams(stock) : '$stock und';

  String precioLabel(String Function(double) formatMoney) {
    final precio = formatMoney(precioVenta);
    return esPeso ? '$precio/kg' : precio;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'codigo_barras': codigoBarras,
      'nombre': nombre,
      'descripcion': descripcion,
      'categoria': categoria,
      'precio_compra': precioCompra,
      'precio_venta': precioVenta,
      'stock': stock,
      'stock_minimo': stockMinimo,
      'tipo_venta': tipoVenta,
      'imagen_url': imagenUrl,
      'fecha_creacion': fechaCreacion.toIso8601String(),
      'fecha_actualizacion': fechaActualizacion.toIso8601String(),
    };
  }

  factory Producto.fromMap(Map<String, dynamic> map) {
    return Producto(
      id: map['id'] as String,
      codigoBarras: map['codigo_barras'] as String? ?? '',
      nombre: map['nombre'] as String,
      descripcion: map['descripcion'] as String?,
      categoria: map['categoria'] as String?,
      precioCompra: (map['precio_compra'] as num).toDouble(),
      precioVenta: (map['precio_venta'] as num).toDouble(),
      stock: (map['stock'] as num).toInt(),
      stockMinimo: (map['stock_minimo'] as num?)?.toInt() ?? 5,
      tipoVenta: map['tipo_venta'] as String? ?? TipoVenta.unidad,
      imagenUrl: map['imagen_url'] as String?,
      fechaCreacion: DateTime.parse(map['fecha_creacion'] as String),
      fechaActualizacion: DateTime.parse(map['fecha_actualizacion'] as String),
    );
  }

  Producto copyWith({
    String? id,
    String? codigoBarras,
    String? nombre,
    String? descripcion,
    String? categoria,
    double? precioCompra,
    double? precioVenta,
    int? stock,
    int? stockMinimo,
    String? tipoVenta,
    String? imagenUrl,
    DateTime? fechaCreacion,
    DateTime? fechaActualizacion,
  }) {
    return Producto(
      id: id ?? this.id,
      codigoBarras: codigoBarras ?? this.codigoBarras,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      categoria: categoria ?? this.categoria,
      precioCompra: precioCompra ?? this.precioCompra,
      precioVenta: precioVenta ?? this.precioVenta,
      stock: stock ?? this.stock,
      stockMinimo: stockMinimo ?? this.stockMinimo,
      tipoVenta: tipoVenta ?? this.tipoVenta,
      imagenUrl: imagenUrl ?? this.imagenUrl,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      fechaActualizacion: fechaActualizacion ?? this.fechaActualizacion,
    );
  }
}
