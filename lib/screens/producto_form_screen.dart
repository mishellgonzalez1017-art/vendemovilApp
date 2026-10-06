import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../theme/app_theme.dart';
import '../utils/safe_area_padding.dart';
import '../models/producto.dart';
import '../services/database_service.dart';
import '../utils/peso_formatter.dart';
import 'scanner_screen.dart';

class ProductoFormScreen extends StatefulWidget {
  final Producto? producto;
  final String? codigoBarras;
  const ProductoFormScreen({super.key, this.producto, this.codigoBarras});
  @override
  State<ProductoFormScreen> createState() => _ProductoFormScreenState();
}

class _ProductoFormScreenState extends State<ProductoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _db = DatabaseService.instance;
  late final TextEditingController _codigoCtrl;
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _descripcionCtrl;
  late final TextEditingController _precioCompraCtrl;
  late final TextEditingController _precioVentaCtrl;
  late final TextEditingController _stockCtrl;
  late final TextEditingController _stockMinimoCtrl;
  String? _categoriaSeleccionada;
  List<String> _categorias = [];
  String? _imagenUrl;
  bool _isEditing = false;
  bool _saving = false;
  String _tipoVenta = TipoVenta.unidad;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.producto != null;
    final p = widget.producto;
    _codigoCtrl = TextEditingController(text: p?.codigoBarras ?? widget.codigoBarras ?? '');
    _nombreCtrl = TextEditingController(text: p?.nombre ?? '');
    _descripcionCtrl = TextEditingController(text: p?.descripcion ?? '');
    _precioCompraCtrl = TextEditingController(text: p != null ? p.precioCompra.toStringAsFixed(2) : '');
    _precioVentaCtrl = TextEditingController(text: p != null ? p.precioVenta.toStringAsFixed(2) : '');
    _tipoVenta = p?.tipoVenta ?? TipoVenta.unidad;
    _stockCtrl = TextEditingController(
      text: p == null
          ? ''
          : p.esPeso
              ? PesoFormatter.kgInputFromGrams(p.stock)
              : '${p.stock}',
    );
    _stockMinimoCtrl = TextEditingController(
      text: p == null
          ? '5'
          : p.esPeso
              ? PesoFormatter.kgInputFromGrams(p.stockMinimo)
              : '${p.stockMinimo}',
    );
    _categoriaSeleccionada = p?.categoria;
    _imagenUrl = p?.imagenUrl;
    _cargarCategorias();
  }

  Future<void> _cargarCategorias() async {
    final cats = await _db.obtenerCategorias();
    if (mounted) setState(() => _categorias = cats);
  }

  Future<void> _escanear() async {
    final codigo = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScannerScreen(titulo: 'Escanear Código')),
    );
    if (codigo != null) {
      if (_codigoCtrl.text.trim().isEmpty) {
        _codigoCtrl.text = codigo;
      } else {
        if (!_codigoCtrl.text.contains(codigo)) {
          _codigoCtrl.text = '${_codigoCtrl.text.trim()}, $codigo';
        }
      }
    }
  }

  Future<void> _seleccionarImagen() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _imagenUrl = image.path);
    }
  }

  void _cambiarTipo(String tipo) {
    if (tipo == _tipoVenta) return;
    setState(() {
      _tipoVenta = tipo;
      if (!_isEditing) {
        _stockCtrl.clear();
        _stockMinimoCtrl.text = tipo == TipoVenta.peso ? '1' : '5';
      }
    });
  }

  int _parseStock(String text) {
    if (_tipoVenta == TipoVenta.peso) {
      return PesoFormatter.parseToGrams(text, enKg: true);
    }
    return int.tryParse(text.trim()) ?? 0;
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final producto = Producto(
        id: widget.producto?.id ?? const Uuid().v4(),
        codigoBarras: _codigoCtrl.text.trim(),
        nombre: _nombreCtrl.text.trim(),
        descripcion: _descripcionCtrl.text.trim().isEmpty ? null : _descripcionCtrl.text.trim(),
        categoria: _categoriaSeleccionada,
        precioCompra: double.tryParse(_precioCompraCtrl.text) ?? 0,
        precioVenta: double.parse(_precioVentaCtrl.text),
        stock: _parseStock(_stockCtrl.text),
        stockMinimo: _tipoVenta == TipoVenta.peso
            ? PesoFormatter.parseToGrams(
                _stockMinimoCtrl.text.isEmpty ? '0' : _stockMinimoCtrl.text,
                enKg: true,
              )
            : int.tryParse(_stockMinimoCtrl.text) ?? 5,
        tipoVenta: _tipoVenta,
        imagenUrl: _imagenUrl,
        fechaCreacion: widget.producto?.fechaCreacion,
      );
      if (_isEditing) {
        await _db.actualizarProducto(producto);
      } else {
        await _db.insertarProducto(producto);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isEditing ? '✓ Producto actualizado' : '✓ Producto guardado'),
          backgroundColor: AppTheme.success,
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _eliminar() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Producto'),
        content: Text('¿Eliminar "${widget.producto!.nombre}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _db.eliminarProducto(widget.producto!.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Producto eliminado'), backgroundColor: AppTheme.error),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _asociarAProductoExistente() async {
    final productos = await _db.obtenerProductos();
    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgWhite,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setStateModal) {
            final filtrados = productos.where((p) => 
              p.nombre.toLowerCase().contains(searchQuery.toLowerCase()) || 
              p.codigoBarras.contains(searchQuery)
            ).toList();
            
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2)),
                  ),
                  const Text('Vincular a producto existente', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Busca y selecciona el producto al que quieres añadir este nuevo código.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  const SizedBox(height: 16),
                  TextField(
                    onChanged: (v) => setStateModal(() => searchQuery = v),
                    decoration: const InputDecoration(
                      hintText: 'Buscar producto...',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filtrados.isEmpty
                        ? const Center(child: Text('No hay productos que coincidan.'))
                        : ListView.builder(
                            itemCount: filtrados.length,
                            itemBuilder: (_, i) {
                              final p = filtrados[i];
                          return ListTile(
                            leading: Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.inventory_2_outlined, color: AppTheme.primary, size: 20),
                            ),
                            title: Text(p.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              '${p.formatoStock} | Cód: ${p.codigoBarras.split(',').first}..',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: const Icon(Icons.link, color: AppTheme.primary),
                            onTap: () async {
                              Navigator.pop(ctx);
                              if (!p.codigoBarras.contains(widget.codigoBarras!)) {
                                final pActualizado = p.copyWith(
                                  codigoBarras: '${p.codigoBarras}, ${widget.codigoBarras!}',
                                );
                                await _db.actualizarProducto(pActualizado);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Código vinculado a ${p.nombre}'), backgroundColor: AppTheme.success),
                                  );
                                  Navigator.pop(context); // Cierra el formulario de "Nuevo producto"
                                }
                              } else {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Este código ya estaba vinculado a este producto.')),
                                  );
                                  Navigator.pop(context);
                                }
                              }
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
      );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Producto' : 'Nuevo Producto'),
        actions: [
          if (_isEditing)
            IconButton(icon: const Icon(Icons.delete_outline, color: AppTheme.error), onPressed: _eliminar),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: listBottomPadding(context, bottomExtra: 20),
          children: [
            Center(
              child: GestureDetector(
                onTap: _seleccionarImagen,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppTheme.bgGrey,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                    image: _imagenUrl != null
                        ? DecorationImage(image: FileImage(File(_imagenUrl!)), fit: BoxFit.cover)
                        : null,
                  ),
                  child: _imagenUrl == null
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo, color: AppTheme.textSecondary, size: 32),
                            SizedBox(height: 8),
                            Text('Añadir foto', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                          ],
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            _buildLabel('Código de Barras'),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _codigoCtrl,
                    decoration: InputDecoration(
                      hintText: _tipoVenta == TipoVenta.peso
                          ? 'Opcional (no se vende con escáner)'
                          : 'Ej: 7750... o varios separados por coma',
                      prefixIcon: const Icon(Icons.qr_code),
                    ),
                    validator: (v) {
                      if (_tipoVenta == TipoVenta.peso) return null;
                      return v == null || v.isEmpty ? 'Ingresa el código' : null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(12)),
                  child: IconButton(
                    icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white),
                    onPressed: _escanear,
                  ),
                ),
              ],
            ),
            if (!_isEditing && widget.codigoBarras != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _asociarAProductoExistente,
                  icon: const Icon(Icons.link_rounded),
                  label: const Text('Vincular a producto existente'),
                  style: TextButton.styleFrom(foregroundColor: AppTheme.primary),
                ),
              ),
            ],
            const SizedBox(height: 16),

            _buildLabel('Nombre del Producto'),
            TextFormField(
              controller: _nombreCtrl,
              decoration: const InputDecoration(hintText: 'Ej: Inca Kola 500ml', prefixIcon: Icon(Icons.inventory_2_outlined)),
              validator: (v) => v == null || v.isEmpty ? 'Ingresa el nombre' : null,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),

            _buildLabel('Descripción (opcional)'),
            TextFormField(
              controller: _descripcionCtrl,
              decoration: const InputDecoration(hintText: 'Descripción breve...'),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            _buildLabel('Categoría'),
            DropdownButtonFormField<String>(
              initialValue: _categoriaSeleccionada,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.category_outlined)),
              hint: const Text('Seleccionar categoría'),
              items: _categorias.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _categoriaSeleccionada = v),
            ),
            const SizedBox(height: 20),

            _buildLabel('Se vende por'),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: TipoVenta.unidad,
                  label: Text('Unidad'),
                  icon: Icon(Icons.inventory_2_outlined, size: 18),
                ),
                ButtonSegment(
                  value: TipoVenta.peso,
                  label: Text('Kilos'),
                  icon: Icon(Icons.scale_outlined, size: 18),
                ),
              ],
              selected: {_tipoVenta},
              onSelectionChanged: (s) => _cambiarTipo(s.first),
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel(_tipoVenta == TipoVenta.peso
                          ? 'Precio Compra (S/ por kg)'
                          : 'Precio Compra (S/)'),
                      TextFormField(
                        controller: _precioCompraCtrl,
                        decoration: const InputDecoration(hintText: '0.00', prefixIcon: Icon(Icons.money_off_outlined)),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel(_tipoVenta == TipoVenta.peso
                          ? 'Precio Venta (S/ por kg)'
                          : 'Precio Venta (S/)'),
                      TextFormField(
                        controller: _precioVentaCtrl,
                        decoration: const InputDecoration(hintText: '0.00', prefixIcon: Icon(Icons.attach_money)),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) => v == null || v.isEmpty || (double.tryParse(v) ?? 0) <= 0 ? 'Precio inválido' : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel(_tipoVenta == TipoVenta.peso
                          ? 'Stock Actual (kg)'
                          : 'Stock Actual'),
                      TextFormField(
                        controller: _stockCtrl,
                        decoration: InputDecoration(
                          hintText: _tipoVenta == TipoVenta.peso ? '0.000' : '0',
                          prefixIcon: const Icon(Icons.numbers),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Requerido';
                          if (_tipoVenta == TipoVenta.peso) {
                            final n = double.tryParse(v.replaceAll(',', '.'));
                            if (n == null || n < 0) return 'Kg inválido';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel(_tipoVenta == TipoVenta.peso
                          ? 'Stock Mínimo (kg)'
                          : 'Stock Mínimo'),
                      TextFormField(
                        controller: _stockMinimoCtrl,
                        decoration: InputDecoration(
                          hintText: _tipoVenta == TipoVenta.peso ? '1' : '5',
                          prefixIcon: const Icon(Icons.warning_amber),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _guardar,
                icon: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded),
                label: Text(_saving ? 'Guardando...' : (_isEditing ? 'Actualizar Producto' : 'Guardar Producto')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textSecondary)),
    );
  }

  @override
  void dispose() {
    _codigoCtrl.dispose();
    _nombreCtrl.dispose();
    _descripcionCtrl.dispose();
    _precioCompraCtrl.dispose();
    _precioVentaCtrl.dispose();
    _stockCtrl.dispose();
    _stockMinimoCtrl.dispose();
    super.dispose();
  }
}
