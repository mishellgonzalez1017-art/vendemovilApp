import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/printer_service.dart';
import '../theme/app_theme.dart';
import '../utils/safe_area_padding.dart';
import '../widgets/ajuste_widgets.dart';
import '../widgets/texto_dialog.dart';

/// Lista de vendedores y cuál está atendiendo. Su nombre sale en el ticket.
/// Cada cambio se guarda al momento.
class AjustesVendedoresScreen extends StatefulWidget {
  const AjustesVendedoresScreen({super.key});

  @override
  State<AjustesVendedoresScreen> createState() => _AjustesVendedoresScreenState();
}

class _AjustesVendedoresScreenState extends State<AjustesVendedoresScreen> {
  List<String> _vendedores = [];
  String? _activo;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final prefs = await SharedPreferences.getInstance();
    _vendedores = prefs.getStringList('vendedores') ?? [];
    final activo = prefs.getString('vendedor_activo');
    _activo = _vendedores.contains(activo) ? activo : null;
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _guardar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('vendedores', _vendedores);
    if (_activo == null) {
      await prefs.remove('vendedor_activo');
    } else {
      await prefs.setString('vendedor_activo', _activo!);
    }
    // Sin vendedor activo el ticket no muestra "Atendido por".
    PrinterService.instance.configurar(vendedor: _activo ?? '');
  }

  Future<void> _agregar() async {
    final nombre = await pedirTexto(
      context,
      titulo: 'Nuevo vendedor',
      hint: 'Nombre del vendedor',
    );
    if (nombre == null || !mounted) return;
    if (_vendedores.contains(nombre)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ese vendedor ya existe'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }
    setState(() {
      _vendedores = [..._vendedores, nombre];
      _activo ??= nombre;
    });
    await _guardar();
  }

  Future<void> _eliminar(String nombre) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar vendedor'),
        content: Text('¿Eliminar a "$nombre"? Sus ventas anteriores no se borran.'),
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
    if (ok != true || !mounted) return;
    setState(() {
      _vendedores = _vendedores.where((v) => v != nombre).toList();
      if (_activo == nombre) _activo = null;
    });
    await _guardar();
  }

  Future<void> _elegirActivo(String nombre) async {
    setState(() => _activo = nombre);
    await _guardar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vendedores')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : ListView(
              padding: listBottomPadding(context, bottomExtra: 24),
              children: [
                const EncabezadoAjuste(
                  icono: Icons.person_rounded,
                  titulo: 'Quién atiende',
                  descripcion:
                      'El vendedor activo sale en el ticket como "Atendido por". '
                      'Toca un nombre para activarlo.',
                ),
                const SizedBox(height: 16),
                BloqueAjuste(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: [
                      if (_vendedores.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(18),
                          child: Text(
                            'Aún no hay vendedores',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        ),
                      for (final v in _vendedores)
                        ListTile(
                          onTap: () => _elegirActivo(v),
                          leading: Icon(
                            v == _activo
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_unchecked_rounded,
                            color: v == _activo
                                ? AppTheme.primary
                                : AppTheme.textMuted,
                          ),
                          title: Text(
                            v,
                            style: TextStyle(
                              fontWeight:
                                  v == _activo ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                          subtitle: v == _activo ? const Text('Activo') : null,
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: AppTheme.error,
                            ),
                            onPressed: () => _eliminar(v),
                            tooltip: 'Eliminar',
                          ),
                        ),
                      ListTile(
                        leading: const Icon(Icons.add, color: AppTheme.primary),
                        title: const Text(
                          'Agregar vendedor',
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
