import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../utils/metodos_pago_config.dart';
import '../utils/safe_area_padding.dart';
import '../widgets/ajuste_widgets.dart';

/// Métodos de pago que acepta el negocio, y la imagen de QR para los que la usan.
/// Cada cambio se guarda al momento.
class AjustesMetodosPagoScreen extends StatefulWidget {
  const AjustesMetodosPagoScreen({super.key});

  @override
  State<AjustesMetodosPagoScreen> createState() =>
      _AjustesMetodosPagoScreenState();
}

class _AjustesMetodosPagoScreenState extends State<AjustesMetodosPagoScreen> {
  List<String> _habilitados = List.from(MetodosPagoConfig.todos);
  String? _yapeQrPath;
  String? _plinQrPath;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final prefs = await SharedPreferences.getInstance();
    _habilitados = prefs.getStringList(MetodosPagoConfig.prefsKey) ??
        List.from(MetodosPagoConfig.todos);
    _yapeQrPath = prefs.getString('yape_qr_path');
    _plinQrPath = prefs.getString('plin_qr_path');
    if (mounted) setState(() => _loading = false);
  }

  void _aviso(String texto, {Color color = AppTheme.success}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto), backgroundColor: color),
    );
  }

  Future<void> _alternar(String metodo, bool activar) async {
    final nueva = List<String>.from(_habilitados);
    if (activar) {
      if (!nueva.contains(metodo)) nueva.add(metodo);
    } else if (nueva.length > 1) {
      nueva.remove(metodo);
    } else {
      _aviso('Debe haber al menos un método de pago activo',
          color: AppTheme.warning);
      return;
    }
    setState(() => _habilitados = nueva);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(MetodosPagoConfig.prefsKey, nueva);
  }

  String _claveQr(String metodo) => metodo == 'yape' ? 'yape_qr_path' : 'plin_qr_path';

  Future<void> _guardarQr(String metodo, String? ruta) async {
    final prefs = await SharedPreferences.getInstance();
    if (ruta == null) {
      await prefs.remove(_claveQr(metodo));
    } else {
      await prefs.setString(_claveQr(metodo), ruta);
    }
    if (!mounted) return;
    setState(() {
      if (metodo == 'yape') {
        _yapeQrPath = ruta;
      } else {
        _plinQrPath = ruta;
      }
    });
  }

  Future<void> _seleccionarQr(String metodo) async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1000,
      maxHeight: 1000,
      imageQuality: 90,
    );
    if (image == null || !mounted) return;
    await _guardarQr(metodo, image.path);
    if (mounted) {
      _aviso('✓ QR de ${MetodosPagoConfig.label(metodo)} cargado');
    }
  }

  Widget _filaMetodo(String metodo) {
    final activo = _habilitados.contains(metodo);
    final color = MetodosPagoConfig.colors[metodo] ?? AppTheme.primary;
    final tieneQr = MetodosPagoConfig.soportaQr(metodo);
    final ruta = metodo == 'yape' ? _yapeQrPath : _plinQrPath;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.bgWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
            secondary: IconoAjuste(
              icono: MetodosPagoConfig.icons[metodo] ?? Icons.payments_rounded,
              color: color,
              tamano: 40,
            ),
            title: Text(
              MetodosPagoConfig.label(metodo),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            value: activo,
            onChanged: (on) => _alternar(metodo, on),
          ),
          if (activo && tieneQr)
            ListTile(
              contentPadding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
              leading: Icon(Icons.qr_code_2_rounded, color: color),
              title: const Text(
                'Imagen de QR o datos de cuenta',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                ruta != null ? 'Imagen cargada' : 'Se muestra al cobrar',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (ruta != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: AppTheme.error),
                      onPressed: () => _guardarQr(metodo, null),
                      tooltip: 'Quitar imagen',
                    ),
                  const Icon(Icons.upload_file_rounded, color: AppTheme.primary),
                  const SizedBox(width: 4),
                ],
              ),
              onTap: () => _seleccionarQr(metodo),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Métodos de pago')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : ListView(
              padding: listBottomPadding(context, bottomExtra: 24),
              children: [
                const EncabezadoAjuste(
                  icono: Icons.account_balance_wallet_rounded,
                  titulo: 'Cómo te pagan',
                  descripcion:
                      'Activa solo los métodos que aceptas. Los cambios se guardan al momento.',
                ),
                const SizedBox(height: 16),
                for (final m in MetodosPagoConfig.todos) _filaMetodo(m),
              ],
            ),
    );
  }
}
