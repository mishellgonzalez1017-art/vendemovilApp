import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../services/license_service.dart';
import '../services/printer_service.dart';
import '../theme/app_theme.dart';
import '../utils/safe_area_padding.dart';
import '../widgets/ajuste_widgets.dart';
import '../widgets/soporte_dialog.dart';
import 'ajustes_metodos_pago_screen.dart';
import 'ajustes_negocio_screen.dart';
import 'ajustes_vendedores_screen.dart';
import 'caja_screen.dart';
import 'categorias_screen.dart';
import 'licencia_screen.dart';

/// Centro de configuración: la impresora arriba y una tarjeta por cada ajuste.
class AjustesScreen extends StatefulWidget {
  const AjustesScreen({super.key});

  @override
  State<AjustesScreen> createState() => _AjustesScreenState();
}

class _AjustesScreenState extends State<AjustesScreen> {
  double _anchoPapel = 58.0;
  String? _impresoraNombre;
  String? _impresoraMac;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final prefs = await SharedPreferences.getInstance();
    _anchoPapel = prefs.getDouble('impresora_ancho') ?? 58.0;
    _impresoraNombre = prefs.getString('impresora_nombre');
    _impresoraMac = prefs.getString('impresora_mac');
    await PrinterService.instance.cargarDesdePrefs();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _abrir(Widget pantalla) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => pantalla));
    if (mounted) _cargar();
  }

  void _aviso(String texto, {Color color = AppTheme.success}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto), backgroundColor: color),
    );
  }

  // ---------------- IMPRESORA ----------------

  Future<void> _guardarAncho(double ancho) async {
    setState(() => _anchoPapel = ancho);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('impresora_ancho', ancho);
    PrinterService.instance.configurar(anchoPapel: ancho);
  }

  Future<void> _guardarImpresora(String nombre, String mac) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('impresora_nombre', nombre);
    await prefs.setString('impresora_mac', mac);
    PrinterService.instance.configurar(mac: mac, printerName: nombre);
    if (!mounted) return;
    setState(() {
      _impresoraNombre = nombre;
      _impresoraMac = mac;
    });
  }

  Future<void> _probarImpresion() async {
    final mac = _impresoraMac;
    if (mac == null) return;
    try {
      final conectado = await PrintBluetoothThermal.connectionStatus;
      if (!conectado) {
        await PrintBluetoothThermal.connect(macPrinterAddress: mac);
      }
      final bytes = <int>[
        0x1B, 0x40, // iniciar
        0x1B, 0x61, 0x01, // centrar
        ...'==========================\n'.codeUnits,
        ...'     ${AppConfig.nombreSinAcentosMayus} POS      \n'.codeUnits,
        ...'    PRUEBA DE CONEXION    \n'.codeUnits,
        ...'==========================\n\n\n\n'.codeUnits,
      ];
      await PrintBluetoothThermal.writeBytes(bytes);
      _aviso('✓ Prueba de impresión enviada');
    } catch (e) {
      _aviso('❌ Error: $e', color: AppTheme.error);
    }
  }

  Future<void> _buscarImpresoras() async {
    // Permisos necesarios para Bluetooth en Android 12 o más.
    await [
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.location,
    ].request();
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Impresoras Bluetooth'),
        content: FutureBuilder<List<BluetoothInfo>>(
          future: PrinterService.instance.obtenerImpresoras(),
          builder: (_, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 100,
                child: Center(
                  child: CircularProgressIndicator(color: AppTheme.primary),
                ),
              );
            }
            final printers = snap.data ?? [];
            if (printers.isEmpty) {
              return const SizedBox(
                height: 100,
                child: Center(
                  child: Text(
                    'No hay dispositivos vinculados.\nVincula la impresora en los ajustes Bluetooth del teléfono.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
              );
            }
            return SizedBox(
              height: 220,
              width: double.maxFinite,
              child: ListView.builder(
                itemCount: printers.length,
                itemBuilder: (_, i) {
                  final p = printers[i];
                  return ListTile(
                    leading: const Icon(Icons.print, color: AppTheme.primary),
                    title: Text(p.name),
                    subtitle: Text(
                      p.macAdress,
                      style: const TextStyle(fontSize: 11),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _conectar(p.name, p.macAdress);
                    },
                  );
                },
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _conectar(String nombre, String mac) async {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(color: AppTheme.primary),
            SizedBox(width: 20),
            Text('Conectando...'),
          ],
        ),
      ),
    );

    bool conectado = false;
    String? error;
    try {
      conectado = await PrintBluetoothThermal.connect(macPrinterAddress: mac);
    } catch (e) {
      error = '$e';
    }
    if (!mounted) return;
    Navigator.pop(context); // quita el aviso "Conectando..."

    if (error != null) {
      _aviso('❌ Error: $error', color: AppTheme.error);
    } else if (conectado) {
      await _guardarImpresora(nombre, mac);
      _aviso('✅ Conectado a $nombre');
    } else {
      _aviso('❌ No se pudo conectar', color: AppTheme.error);
    }
  }

  // ---------------- PANTALLA ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : ListView(
              padding: listBottomPadding(context, bottomExtra: 24),
              children: [
                _tarjetaImpresora(),
                const SizedBox(height: 16),
                FilasDeTarjetas(
                  tarjetas: [
                    TarjetaAjuste(
                      icono: Icons.store_rounded,
                      titulo: 'Datos del negocio',
                      subtitulo: 'Nombre, NIT y ticket',
                      onTap: () => _abrir(const AjustesNegocioScreen()),
                    ),
                    TarjetaAjuste(
                      icono: Icons.account_balance_wallet_rounded,
                      titulo: 'Métodos de pago',
                      subtitulo: 'Qué aceptas y QR',
                      onTap: () => _abrir(const AjustesMetodosPagoScreen()),
                    ),
                    TarjetaAjuste(
                      icono: Icons.person_rounded,
                      titulo: 'Vendedores',
                      subtitulo: 'Quién atiende',
                      onTap: () => _abrir(const AjustesVendedoresScreen()),
                    ),
                    TarjetaAjuste(
                      icono: Icons.point_of_sale_rounded,
                      titulo: 'Cuadre de caja',
                      subtitulo: 'Cierre y diferencia',
                      onTap: () => _abrir(const CajaScreen()),
                    ),
                    TarjetaAjuste(
                      icono: Icons.category_rounded,
                      titulo: 'Categorías',
                      subtitulo: 'Agrupa tus productos',
                      onTap: () => _abrir(const CategoriasScreen()),
                    ),
                    ListenableBuilder(
                      listenable: LicenseService.instance,
                      builder: (context, _) => TarjetaAjuste(
                        icono: Icons.key_rounded,
                        titulo: 'Licencia',
                        subtitulo: LicenseService.instance.resumen,
                        onTap: () => _abrir(const LicenciaScreen()),
                      ),
                    ),
                    TarjetaAjuste(
                      icono: Icons.support_agent_rounded,
                      titulo: 'Soporte',
                      subtitulo: 'WhatsApp y mensualidad',
                      color: const Color(0xFF25D366),
                      onTap: () => showSoporteDialog(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    '${AppConfig.nombre} v${AppConfig.version}',
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _tarjetaImpresora() {
    return BloqueAjuste(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconoAjuste(icono: Icons.print_rounded, color: AppTheme.info),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Impresora Bluetooth',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _impresoraNombre ?? 'Sin impresora conectada',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Tamaño del papel',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _chipPapel(58.0, '58 mm', 'Pequeño')),
              const SizedBox(width: 10),
              Expanded(child: _chipPapel(80.0, '80 mm', 'Grande')),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _buscarImpresoras,
                  icon: const Icon(Icons.bluetooth_searching_rounded, size: 20),
                  label: const Text('Buscar impresoras'),
                ),
              ),
              if (_impresoraMac != null) ...[
                const SizedBox(width: 10),
                IconButton.outlined(
                  onPressed: _probarImpresion,
                  icon: const Icon(Icons.receipt_long_rounded),
                  tooltip: 'Imprimir prueba',
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _chipPapel(double valor, String titulo, String detalle) {
    final sel = _anchoPapel == valor;
    return GestureDetector(
      onTap: () => _guardarAncho(valor),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: sel ? AppTheme.primary : AppTheme.bgWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: sel ? AppTheme.primary : AppTheme.border),
        ),
        child: Column(
          children: [
            Text(
              titulo,
              style: TextStyle(
                color: sel ? Colors.white : AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              detalle,
              style: TextStyle(
                color: sel ? Colors.white70 : AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
