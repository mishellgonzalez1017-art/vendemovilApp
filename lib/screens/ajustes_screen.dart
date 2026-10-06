import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/safe_area_padding.dart';
import '../theme/app_theme.dart';
import '../services/printer_service.dart';
import '../services/database_service.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/metodos_pago_config.dart';
import '../widgets/soporte_dialog.dart';

class AjustesScreen extends StatefulWidget {
  const AjustesScreen({super.key});
  @override
  State<AjustesScreen> createState() => _AjustesScreenState();
}

class _AjustesScreenState extends State<AjustesScreen> {
  final _nombreCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _rucCtrl = TextEditingController();
  final _mensajeCtrl = TextEditingController();
  final _monedaSimboloCtrl = TextEditingController(text: 'S/');
  double _anchoPapel = 58.0;
  String? _impresoraNombre;
  String? _impresoraMac;
  String? _yapeQrPath;
  String? _plinQrPath;
  List<String> _metodosHabilitados = List.from(MetodosPagoConfig.todos);
  List<String> _vendedores = [];
  String? _vendedorActivo;
  List<String> _categorias = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final prefs = await SharedPreferences.getInstance();
    _nombreCtrl.text = prefs.getString('negocio_nombre') ?? 'VENDE MÓVIL';
    _direccionCtrl.text = prefs.getString('negocio_direccion') ?? '';
    _telefonoCtrl.text = prefs.getString('negocio_telefono') ?? '';
    _rucCtrl.text = prefs.getString('negocio_ruc') ?? '';
    _mensajeCtrl.text =
        prefs.getString('negocio_mensaje') ?? '¡Gracias por su compra!';
    _monedaSimboloCtrl.text = prefs.getString('moneda_simbolo') ?? 'S/';
    _anchoPapel = prefs.getDouble('impresora_ancho') ?? 58.0;
    _impresoraNombre = prefs.getString('impresora_nombre');
    _impresoraMac = prefs.getString('impresora_mac');
    _yapeQrPath = prefs.getString('yape_qr_path');
    _plinQrPath = prefs.getString('plin_qr_path');
    _metodosHabilitados = prefs.getStringList(MetodosPagoConfig.prefsKey) ??
        List.from(MetodosPagoConfig.todos);
    _vendedores = prefs.getStringList('vendedores') ?? [];
    _vendedorActivo = prefs.getString('vendedor_activo');

    _categorias = await DatabaseService.instance.obtenerCategorias();

    PrinterService.instance.configurar(
      nombre: _nombreCtrl.text,
      direccion: _direccionCtrl.text,
      telefono: _telefonoCtrl.text,
      ruc: _rucCtrl.text,
      mensaje: _mensajeCtrl.text,
      anchoPapel: _anchoPapel,
      mac: _impresoraMac,
      printerName: _impresoraNombre,
      moneda: _monedaSimboloCtrl.text,
      vendedor: _vendedorActivo,
    );

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _guardar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('negocio_nombre', _nombreCtrl.text);
    await prefs.setString('negocio_direccion', _direccionCtrl.text);
    await prefs.setString('negocio_telefono', _telefonoCtrl.text);
    await prefs.setString('negocio_ruc', _rucCtrl.text);
    await prefs.setString('negocio_mensaje', _mensajeCtrl.text);
    await prefs.setString('moneda_simbolo', _monedaSimboloCtrl.text);
    await prefs.setDouble('impresora_ancho', _anchoPapel);
    if (_impresoraNombre != null)
      await prefs.setString('impresora_nombre', _impresoraNombre!);
    if (_impresoraMac != null)
      await prefs.setString('impresora_mac', _impresoraMac!);
    await prefs.setStringList(
      MetodosPagoConfig.prefsKey,
      _metodosHabilitados,
    );
    if (_yapeQrPath != null) {
      await prefs.setString('yape_qr_path', _yapeQrPath!);
    } else {
      await prefs.remove('yape_qr_path');
    }
    if (_plinQrPath != null) {
      await prefs.setString('plin_qr_path', _plinQrPath!);
    } else {
      await prefs.remove('plin_qr_path');
    }

    if (_vendedorActivo != null)
      await prefs.setString('vendedor_activo', _vendedorActivo!);
    await prefs.setStringList('vendedores', _vendedores);

    PrinterService.instance.configurar(
      nombre: _nombreCtrl.text,
      direccion: _direccionCtrl.text,
      telefono: _telefonoCtrl.text,
      ruc: _rucCtrl.text,
      mensaje: _mensajeCtrl.text,
      anchoPapel: _anchoPapel,
      mac: _impresoraMac,
      printerName: _impresoraNombre,
      moneda: _monedaSimboloCtrl.text,
      vendedor: _vendedorActivo,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Configuración guardada'),
          backgroundColor: AppTheme.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: listBottomPadding(context, bottomExtra: 24),
        children: [
          _buildSection('Datos del Negocio', Icons.store_rounded, [
            _buildField('Nombre del negocio', _nombreCtrl, Icons.business),
            _buildField('RUC', _rucCtrl, Icons.badge_outlined),
            _buildField(
              'Dirección',
              _direccionCtrl,
              Icons.location_on_outlined,
            ),
            _buildField('Teléfono', _telefonoCtrl, Icons.phone_outlined),
            _buildField(
              'Símbolo de Moneda (ej. S/ , \$ , €)',
              _monedaSimboloCtrl,
              Icons.attach_money_rounded,
            ),
            const Divider(height: 32),
            _buildField(
              'Mensaje de pie de ticket',
              _mensajeCtrl,
              Icons.message_outlined,
            ),
          ]),
          const SizedBox(height: 16),

          _buildSection(
            'Métodos de Pago',
            Icons.account_balance_wallet_rounded,
            [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'Activa solo los métodos que aceptas en tu negocio',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary.withValues(alpha: 0.9),
                  ),
                ),
              ),
              for (final metodo in MetodosPagoConfig.todos)
                SwitchListTile(
                  secondary: Icon(
                    MetodosPagoConfig.icons[metodo],
                    color: MetodosPagoConfig.colors[metodo],
                  ),
                  title: Text(
                    MetodosPagoConfig.label(metodo),
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  value: _metodosHabilitados.contains(metodo),
                  onChanged: (on) {
                    setState(() {
                      if (on) {
                        if (!_metodosHabilitados.contains(metodo)) {
                          _metodosHabilitados.add(metodo);
                        }
                      } else if (_metodosHabilitados.length > 1) {
                        _metodosHabilitados.remove(metodo);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Debe haber al menos un método de pago activo',
                            ),
                            backgroundColor: AppTheme.warning,
                          ),
                        );
                      }
                    });
                  },
                ),
              if (_metodosHabilitados.contains('yape'))
                _buildQrTile(
                  metodo: 'yape',
                  path: _yapeQrPath,
                  onSelect: () => _seleccionarQr('yape'),
                  onDelete: () => setState(() => _yapeQrPath = null),
                ),
              if (_metodosHabilitados.contains('plin'))
                _buildQrTile(
                  metodo: 'plin',
                  path: _plinQrPath,
                  onSelect: () => _seleccionarQr('plin'),
                  onDelete: () => setState(() => _plinQrPath = null),
                ),
            ],
          ),
          const SizedBox(height: 16),

          _buildSection('Vendedores', Icons.person_rounded, [
            if (_vendedores.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: DropdownButtonFormField<String>(
                  initialValue: _vendedores.contains(_vendedorActivo)
                      ? _vendedorActivo
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Vendedor Activo',
                    prefixIcon: Icon(Icons.person, size: 20),
                    filled: true,
                    fillColor: AppTheme.bgGrey,
                  ),
                  hint: const Text('Seleccionar vendedor'),
                  items: _vendedores
                      .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                      .toList(),
                  onChanged: (v) => setState(() => _vendedorActivo = v),
                ),
              ),
            ..._vendedores.map(
              (v) => ListTile(
                title: Text(v),
                leading: const Icon(Icons.person_outline),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: AppTheme.error),
                  onPressed: () {
                    setState(() {
                      _vendedores.remove(v);
                      if (_vendedorActivo == v) _vendedorActivo = null;
                    });
                  },
                ),
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
              onTap: _agregarVendedor,
            ),
          ]),
          const SizedBox(height: 16),

          _buildSection('Categorías', Icons.category_rounded, [
            ..._categorias.map(
              (c) => ListTile(
                title: Text(c),
                leading: const Icon(Icons.folder_outlined),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: AppTheme.error),
                  onPressed: () => _eliminarCategoria(c),
                ),
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
              onTap: _agregarCategoria,
            ),
          ]),
          const SizedBox(height: 16),

          _buildSection('Impresora Bluetooth', Icons.print_rounded, [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: DropdownButtonFormField<double>(
                initialValue: _anchoPapel,
                decoration: const InputDecoration(
                  labelText: 'Tamaño del Papel',
                  prefixIcon: Icon(Icons.aspect_ratio_rounded, size: 20),
                  filled: true,
                  fillColor: AppTheme.bgGrey,
                ),
                items: const [
                  DropdownMenuItem(value: 58.0, child: Text('58 mm (Pequeño)')),
                  DropdownMenuItem(value: 80.0, child: Text('80 mm (Grande)')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _anchoPapel = v);
                },
              ),
            ),
            ListTile(
              leading: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.bluetooth,
                  color: AppTheme.info,
                  size: 20,
                ),
              ),
              title: Text(
                _impresoraNombre ?? 'Buscar impresoras',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                _impresoraMac ?? 'Conectar impresora térmica',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_impresoraMac != null)
                    IconButton(
                      icon: const Icon(Icons.print, color: AppTheme.primary),
                      onPressed: _probarImpresion,
                      tooltip: 'Imprimir prueba',
                    ),
                  const Icon(Icons.chevron_right, color: AppTheme.textMuted),
                ],
              ),
              onTap: _buscarImpresoras,
            ),
          ], collapsible: false),
          const SizedBox(height: 16),

          _buildSection('Soporte', Icons.support_agent_rounded, [
            ListTile(
              leading: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.chat_rounded,
                  color: Color(0xFF25D366),
                  size: 20,
                ),
              ),
              title: const Text(
                'Edax Agency',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'WhatsApp +51 973 282 798 · Versión Pro+',
                style: TextStyle(fontSize: 12),
              ),
              trailing: const Icon(
                Icons.chevron_right,
                color: AppTheme.textMuted,
              ),
              onTap: () => showSoporteDialog(context),
            ),
          ]),
          const SizedBox(height: 24),

          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _guardar,
              icon: const Icon(Icons.save_rounded),
              label: const Text(
                'Guardar Configuración',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    String title,
    IconData icon,
    List<Widget> children, {
    bool collapsible = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: collapsible
          ? Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: false,
                title: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                leading: Icon(icon, color: AppTheme.primary, size: 20),
                children: [...children, const SizedBox(height: 8)],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Icon(icon, color: AppTheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
                ...children,
                const SizedBox(height: 8),
              ],
            ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: TextField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          filled: true,
          fillColor: AppTheme.bgGrey,
        ),
      ),
    );
  }

  Widget _buildQrTile({
    required String metodo,
    required String? path,
    required VoidCallback onSelect,
    required VoidCallback onDelete,
  }) {
    final color = MetodosPagoConfig.colors[metodo]!;
    final label = MetodosPagoConfig.label(metodo);
    return ListTile(
      leading: Icon(Icons.qr_code_scanner_rounded, color: color),
      title: Text(
        'QR de $label',
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        path != null ? 'Imagen cargada' : 'Subir imagen del QR',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (path != null)
            IconButton(
              icon: const Icon(Icons.delete, color: AppTheme.error),
              onPressed: onDelete,
            ),
          const Icon(Icons.upload_file_rounded, color: AppTheme.primary),
        ],
      ),
      onTap: onSelect,
    );
  }

  Future<void> _seleccionarQr(String metodo) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null || !mounted) return;

    setState(() {
      if (metodo == 'yape') {
        _yapeQrPath = image.path;
      } else if (metodo == 'plin') {
        _plinQrPath = image.path;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '✓ QR de ${MetodosPagoConfig.label(metodo)} cargado correctamente',
        ),
        backgroundColor: AppTheme.success,
      ),
    );
  }

  Future<void> _agregarVendedor() async {
    final ctrl = TextEditingController();
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuevo Vendedor'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: 'Nombre del vendedor',
            filled: true,
            fillColor: AppTheme.bgGrey,
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
    if (res != null && res.isNotEmpty && !_vendedores.contains(res)) {
      setState(() => _vendedores.add(res));
    }
  }

  Future<void> _agregarCategoria() async {
    final ctrl = TextEditingController();
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nueva Categoría'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: 'Nombre de la categoría',
            filled: true,
            fillColor: AppTheme.bgGrey,
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
    if (res != null && res.isNotEmpty && !_categorias.contains(res)) {
      await DatabaseService.instance.agregarCategoria(res);
      final cats = await DatabaseService.instance.obtenerCategorias();
      setState(() => _categorias = cats);
    }
  }

  Future<void> _eliminarCategoria(String nombre) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Categoría'),
        content: Text('¿Estás seguro de eliminar la categoría "$nombre"?'),
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
    if (confirm == true) {
      await DatabaseService.instance.eliminarCategoria(nombre);
      final cats = await DatabaseService.instance.obtenerCategorias();
      setState(() => _categorias = cats);
    }
  }

  Future<void> _probarImpresion() async {
    if (_impresoraMac == null) return;
    try {
      final conectado = await PrintBluetoothThermal.connectionStatus;
      if (!conectado) {
        await PrintBluetoothThermal.connect(macPrinterAddress: _impresoraMac!);
      }

      // Basic text print test
      List<int> bytes = [];
      bytes.addAll([0x1B, 0x40]); // Init
      bytes.addAll([0x1B, 0x61, 0x01]); // Align center
      bytes.addAll("==========================\n".codeUnits);
      bytes.addAll("     VENDE MOVIL POS      \n".codeUnits);
      bytes.addAll("    PRUEBA DE CONEXION    \n".codeUnits);
      bytes.addAll("==========================\n\n\n\n".codeUnits);
      await PrintBluetoothThermal.writeBytes(bytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Prueba de impresión enviada'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _buscarImpresoras() async {
    // Solicitar permisos necesarios para Android 12+
    await [
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.location,
    ].request();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Impresoras Bluetooth'),
        content: FutureBuilder(
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
                    'No hay disp. vinculados',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
              );
            }
            return SizedBox(
              height: 200,
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
                    onTap: () async {
                      Navigator.pop(ctx); // Cerrar diálogo de lista

                      // Mostrar cargando
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => const AlertDialog(
                          content: Row(
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(width: 20),
                              Text("Conectando..."),
                            ],
                          ),
                        ),
                      );

                      try {
                        final conectado = await PrintBluetoothThermal.connect(
                          macPrinterAddress: p.macAdress,
                        );
                        Navigator.pop(context); // Quitar cargando

                        if (conectado) {
                          setState(() {
                            _impresoraNombre = p.name;
                            _impresoraMac = p.macAdress;
                          });
                          PrinterService.instance.configurar(
                            mac: p.macAdress,
                            printerName: p.name,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('✅ Conectado a ${p.name}'),
                              backgroundColor: AppTheme.success,
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('❌ Error al conectar'),
                              backgroundColor: AppTheme.error,
                            ),
                          );
                        }
                      } catch (e) {
                        Navigator.pop(context); // Quitar cargando
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('❌ Error: $e'),
                            backgroundColor: AppTheme.error,
                          ),
                        );
                      }
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

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _direccionCtrl.dispose();
    _telefonoCtrl.dispose();
    _rucCtrl.dispose();
    _mensajeCtrl.dispose();
    _monedaSimboloCtrl.dispose();
    super.dispose();
  }
}
