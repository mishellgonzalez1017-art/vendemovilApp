import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/producto.dart';
import '../models/venta.dart';
import '../services/database_service.dart';
import '../utils/peso_formatter.dart';

/// Provider central del carrito de ventas
class CarritoProvider extends ChangeNotifier {
  final List<ItemVenta> _items = [];
  double _descuento = 0;
  final _uuid = const Uuid();

  List<ItemVenta> get items => List.unmodifiable(_items);
  int get totalItems =>
      _items.fold(0, (s, i) => s + (i.esPeso ? 1 : i.cantidad));
  bool get isEmpty => _items.isEmpty;

  double get subtotal => _items.fold(0.0, (s, i) => s + i.subtotal);
  double get descuento => _descuento;
  double get total => (subtotal - _descuento).clamp(0, double.infinity);

  int cantidadEnCarrito(String productoId) {
    final idx = _items.indexWhere((i) => i.productoId == productoId);
    if (idx < 0) return 0;
    return _items[idx].cantidad;
  }

  double _subtotalItem(Producto producto, int cantidad) {
    if (producto.esPeso) {
      return PesoFormatter.subtotal(
        gramos: cantidad,
        precioPorKg: producto.precioVenta,
      );
    }
    return producto.precioVenta * cantidad;
  }

  double _subtotalDesdeItem(ItemVenta item, int cantidad) {
    if (item.esPeso) {
      return PesoFormatter.subtotal(
        gramos: cantidad,
        precioPorKg: item.precioUnitario,
      );
    }
    return item.precioUnitario * cantidad;
  }

  void agregarProducto(Producto producto, {int cantidad = 1}) {
    final idx = _items.indexWhere((i) => i.productoId == producto.id);
    if (idx >= 0) {
      final item = _items[idx];
      final nuevaCant = item.cantidad + cantidad;
      _items[idx] = item.copyWith(
        cantidad: nuevaCant,
        subtotal: _subtotalItem(producto, nuevaCant),
      );
    } else {
      _items.add(ItemVenta(
        id: _uuid.v4(),
        ventaId: '',
        productoId: producto.id,
        productoNombre: producto.nombre,
        codigoBarras: producto.codigoBarras,
        precioUnitario: producto.precioVenta,
        precioCompra: producto.precioCompra,
        cantidad: cantidad,
        subtotal: _subtotalItem(producto, cantidad),
        tipoVenta: producto.tipoVenta,
        imagenUrl: producto.imagenUrl,
      ));
    }
    notifyListeners();
  }

  void actualizarCantidad(int index, int cantidad) {
    if (index < 0 || index >= _items.length || cantidad < 1) return;
    final item = _items[index];
    _items[index] = item.copyWith(
      cantidad: cantidad,
      subtotal: _subtotalDesdeItem(item, cantidad),
    );
    notifyListeners();
  }

  void eliminarItem(int index) {
    if (index < 0 || index >= _items.length) return;
    _items.removeAt(index);
    notifyListeners();
  }

  void setDescuento(double desc) {
    _descuento = desc.clamp(0, subtotal);
    notifyListeners();
  }

  void limpiar() {
    _items.clear();
    _descuento = 0;
    notifyListeners();
  }

  Future<Venta> finalizarVenta({
    required String metodoPago,
    double? montoPagado,
  }) async {
    final ventaId = _uuid.v4();
    final itemsConVentaId = _items
        .map(
          (i) => ItemVenta(
            id: i.id,
            ventaId: ventaId,
            productoId: i.productoId,
            productoNombre: i.productoNombre,
            codigoBarras: i.codigoBarras,
            precioUnitario: i.precioUnitario,
            precioCompra: i.precioCompra,
            cantidad: i.cantidad,
            subtotal: i.subtotal,
            tipoVenta: i.tipoVenta,
            imagenUrl: i.imagenUrl,
          ),
        )
        .toList();

    double? vuelto;
    if (metodoPago == 'efectivo' && montoPagado != null) {
      vuelto = montoPagado - total;
    }

    final venta = Venta(
      id: ventaId,
      items: itemsConVentaId,
      subtotal: subtotal,
      descuento: _descuento,
      total: total,
      metodoPago: metodoPago,
      montoPagado: montoPagado,
      vuelto: vuelto,
    );

    await DatabaseService.instance.registrarVenta(venta);
    limpiar();
    return venta;
  }
}
