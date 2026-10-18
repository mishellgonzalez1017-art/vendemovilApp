import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../utils/safe_area_padding.dart';
import '../widgets/ajuste_widgets.dart';
import '../widgets/texto_dialog.dart';

/// Nombres para agrupar los productos.
class CategoriasScreen extends StatefulWidget {
  const CategoriasScreen({super.key});

  @override
  State<CategoriasScreen> createState() => _CategoriasScreenState();
}

class _CategoriasScreenState extends State<CategoriasScreen> {
  final _db = DatabaseService.instance;
  List<String> _categorias = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final cats = await _db.obtenerCategorias();
    if (!mounted) return;
    setState(() {
      _categorias = cats;
      _loading = false;
    });
  }

  Future<void> _agregar() async {
    final nombre = await pedirTexto(
      context,
      titulo: 'Nueva categoría',
      hint: 'Nombre de la categoría',
    );
    if (nombre == null || !mounted) return;
    if (_categorias.contains(nombre)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esa categoría ya existe'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }
    await _db.agregarCategoria(nombre);
    await _cargar();
  }

  Future<void> _eliminar(String nombre) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar categoría'),
        content: Text('¿Eliminar la categoría "$nombre"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _db.eliminarCategoria(nombre);
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Categorías')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : ListView(
              padding: listBottomPadding(context, bottomExtra: 24),
              children: [
                BloqueAjuste(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: [
                      for (final c in _categorias)
                        ListTile(
                          leading: const Icon(Icons.folder_outlined),
                          title: Text(c),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete_rounded,
                              color: AppTheme.error,
                            ),
                            onPressed: () => _eliminar(c),
                            tooltip: 'Eliminar',
                          ),
                        ),
                      ListTile(
                        leading: const Icon(Icons.add, color: AppTheme.primary),
                        title: const Text(
                          'Agregar categoría',
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onTap: _agregar,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
