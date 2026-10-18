import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../services/printer_service.dart';
import '../theme/app_theme.dart';
import '../utils/safe_area_padding.dart';
import '../widgets/ajuste_widgets.dart';
import '../widgets/safe_bottom_bar.dart';

/// Datos que salen en el ticket y en los reportes.
class AjustesNegocioScreen extends StatefulWidget {
  const AjustesNegocioScreen({super.key});

  @override
  State<AjustesNegocioScreen> createState() => _AjustesNegocioScreenState();
}

class _AjustesNegocioScreenState extends State<AjustesNegocioScreen> {
  final _nombreCtrl = TextEditingController();
  final _nitCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _monedaCtrl = TextEditingController(text: 'Q');
  final _mensajeCtrl = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _nitCtrl.dispose();
    _direccionCtrl.dispose();
    _telefonoCtrl.dispose();
    _monedaCtrl.dispose();
    _mensajeCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final prefs = await SharedPreferences.getInstance();
    _nombreCtrl.text = prefs.getString('negocio_nombre') ?? AppConfig.nombreMayus;
    _nitCtrl.text = prefs.getString('negocio_ruc') ?? '';
    _direccionCtrl.text = prefs.getString('negocio_direccion') ?? '';
    _telefonoCtrl.text = prefs.getString('negocio_telefono') ?? '';
    _monedaCtrl.text = prefs.getString('moneda_simbolo') ?? 'Q';
    _mensajeCtrl.text =
        prefs.getString('negocio_mensaje') ?? '¡Gracias por su compra!';
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _guardar() async {
    final moneda = _monedaCtrl.text.trim().isEmpty ? 'Q' : _monedaCtrl.text.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('negocio_nombre', _nombreCtrl.text.trim());
    await prefs.setString('negocio_ruc', _nitCtrl.text.trim());
    await prefs.setString('negocio_direccion', _direccionCtrl.text.trim());
    await prefs.setString('negocio_telefono', _telefonoCtrl.text.trim());
    await prefs.setString('moneda_simbolo', moneda);
    await prefs.setString('negocio_mensaje', _mensajeCtrl.text.trim());

    PrinterService.instance.configurar(
      nombre: _nombreCtrl.text.trim(),
      direccion: _direccionCtrl.text.trim(),
      telefono: _telefonoCtrl.text.trim(),
      ruc: _nitCtrl.text.trim(),
      mensaje: _mensajeCtrl.text.trim(),
      moneda: moneda,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✓ Datos guardados'),
        backgroundColor: AppTheme.success,
      ),
    );
    Navigator.pop(context);
  }

  Widget _campo(
    String label,
    TextEditingController ctrl,
    IconData icono, {
    TextInputType? teclado,
    String? ayuda,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        keyboardType: teclado,
        decoration: InputDecoration(
          labelText: label,
          helperText: ayuda,
          prefixIcon: Icon(icono, size: 20),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Datos del negocio')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: listBottomPadding(context, bottomExtra: 24),
              children: [
                const EncabezadoAjuste(
                  icono: Icons.store_rounded,
                  titulo: 'Tu negocio',
                  descripcion:
                      'Estos datos salen en el ticket, el cuadre de caja y los reportes.',
                ),
                const SizedBox(height: 16),
                BloqueAjuste(
                  child: Column(
                    children: [
                      _campo('Nombre del negocio', _nombreCtrl, Icons.business),
                      _campo('NIT (opcional)', _nitCtrl, Icons.badge_outlined),
                      _campo('Dirección', _direccionCtrl, Icons.location_on_outlined),
                      _campo(
                        'Teléfono',
                        _telefonoCtrl,
                        Icons.phone_outlined,
                        teclado: TextInputType.phone,
                      ),
                      _campo(
                        'Símbolo de moneda',
                        _monedaCtrl,
                        Icons.attach_money_rounded,
                        ayuda: 'Por defecto Q (quetzales)',
                      ),
                      _campo(
                        'Mensaje al pie del ticket',
                        _mensajeCtrl,
                        Icons.message_outlined,
                      ),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: SafeBottomBar(
        decoration: const BoxDecoration(
          color: AppTheme.bgWhite,
          border: Border(top: BorderSide(color: AppTheme.border)),
        ),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _loading ? null : _guardar,
            icon: const Icon(Icons.save_rounded),
            label: const Text('Guardar'),
          ),
        ),
      ),
    );
  }
}
