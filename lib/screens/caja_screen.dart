import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../models/caja.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';
import '../utils/metodos_pago_config.dart';
import '../utils/safe_area_padding.dart';
import '../utils/whatsapp_share.dart';
import '../widgets/safe_bottom_bar.dart';

/// Convierte lo que escribe el usuario ("12.50" o "12,50") en número.
double? parseMonto(String texto) {
  final v = double.tryParse(texto.trim().replaceAll(',', '.'));
  if (v == null || v.isNaN || v.isInfinite) return null;
  return v;
}

final _fechaFmt = DateFormat('dd/MM/yyyy HH:mm', 'es');

List<String> _ordenarMetodos(Iterable<String> claves) {
  final lista = claves.toList();
  int pos(String k) {
    final i = MetodosPagoConfig.todos.indexOf(k);
    return i < 0 ? 99 : i;
  }

  lista.sort((a, b) => pos(a).compareTo(pos(b)));
  return lista;
}

// ============================================================
// PANTALLA PRINCIPAL DE CAJA
// ============================================================
class CajaScreen extends StatefulWidget {
  const CajaScreen({super.key});

  @override
  State<CajaScreen> createState() => _CajaScreenState();
}

class _CajaScreenState extends State<CajaScreen> {
  final _db = DatabaseService.instance;
  final _fondoCtrl = TextEditingController();

  bool _loading = true;
  String _simbolo = 'Q';
  Caja? _caja;
  ResumenCaja? _resumen;
  List<MovimientoCaja> _movs = [];
  List<Caja> _cierres = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _fondoCtrl.dispose();
    super.dispose();
  }

  String _q(double v) => CurrencyFormatter.format(v, _simbolo);

  Future<void> _cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final simbolo = prefs.getString('moneda_simbolo') ?? 'Q';
    final caja = await _db.obtenerCajaAbierta();
    ResumenCaja? resumen;
    var movs = <MovimientoCaja>[];
    if (caja != null) {
      resumen = await _db.calcularResumenCaja(caja);
      movs = await _db.obtenerMovimientosCaja(caja.id);
    }
    final cierres = await _db.obtenerCajasCerradas();
    if (!mounted) return;
    setState(() {
      _simbolo = simbolo;
      _caja = caja;
      _resumen = resumen;
      _movs = movs;
      _cierres = cierres;
      _loading = false;
    });
  }

  void _aviso(String texto, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texto),
        backgroundColor: error ? AppTheme.error : AppTheme.success,
      ),
    );
  }

  Future<void> _abrirCaja() async {
    final texto = _fondoCtrl.text.trim();
    final fondo = texto.isEmpty ? 0.0 : parseMonto(texto);
    if (fondo == null || fondo < 0) {
      _aviso('Escribe un monto válido', error: true);
      return;
    }
    FocusScope.of(context).unfocus();
    await _db.abrirCaja(fondo);
    _fondoCtrl.clear();
    await _cargar();
    if (mounted) _aviso('Caja abierta');
  }

  Future<void> _agregarMovimiento(String tipo) async {
    final caja = _caja;
    if (caja == null) return;
    final res = await showDialog<_MovimientoInput>(
      context: context,
      builder: (_) => _MovimientoDialog(tipo: tipo),
    );
    if (res == null) return;
    await _db.agregarMovimientoCaja(
      MovimientoCaja(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        cajaId: caja.id,
        tipo: tipo,
        monto: redondear2(res.monto),
        concepto: res.concepto,
      ),
    );
    await _cargar();
  }

  Future<void> _eliminarMovimiento(MovimientoCaja m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar movimiento'),
        content: Text('¿Eliminar "${m.concepto}" por ${_q(m.monto)}?'),
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
    await _db.eliminarMovimientoCaja(m.id);
    await _cargar();
  }

  Future<void> _cerrarCaja() async {
    final caja = _caja;
    if (caja == null) return;
    final resumen = await _db.calcularResumenCaja(caja);
    if (!mounted) return;
    final input = await showDialog<_CierreInput>(
      context: context,
      builder: (_) => _CierreDialog(
        esperado: resumen.efectivoEsperado,
        simbolo: _simbolo,
      ),
    );
    if (input == null) return;
    final cerrada = await _db.cerrarCaja(caja, input.contado, nota: input.nota);
    await _cargar();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetalleCajaScreen(caja: cerrada, simbolo: _simbolo),
      ),
    );
  }

  // ---------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final abierta = _caja != null && !_loading;
    return Scaffold(
      appBar: AppBar(title: const Text('Caja')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : RefreshIndicator(
              color: AppTheme.primary,
              onRefresh: _cargar,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: listBottomPadding(context, top: 8),
                children: _caja == null ? _sinCaja() : _conCaja(),
              ),
            ),
      bottomNavigationBar: abierta
          ? SafeBottomBar(
              decoration: const BoxDecoration(
                color: AppTheme.bgWhite,
                border: Border(top: BorderSide(color: AppTheme.border)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _cerrarCaja,
                  icon: const Icon(Icons.lock_outline_rounded),
                  label: const Text('Cerrar caja'),
                ),
              ),
            )
          : null,
    );
  }

  List<Widget> _sinCaja() {
    return [
      _tarjeta(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.point_of_sale_rounded,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Abrir caja',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              '¿Con cuánto efectivo empiezas el turno? Por ejemplo, el cambio '
              'que dejas en la gaveta. Al cerrar, la app te dirá cuánto debería '
              'haber y si sobra o falta dinero.',
              style: TextStyle(color: AppTheme.textSecondary, height: 1.35),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _fondoCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: InputDecoration(
                labelText: 'Fondo inicial',
                prefixText: '$_simbolo ',
                hintText: '0.00',
              ),
              onSubmitted: (_) => _abrirCaja(),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _abrirCaja,
                icon: const Icon(Icons.lock_open_rounded),
                label: const Text('Abrir caja'),
              ),
            ),
          ],
        ),
      ),
      ..._seccionCierres(),
    ];
  }

  List<Widget> _conCaja() {
    final caja = _caja!;
    final r = _resumen!;
    return [
      // Encabezado: efectivo esperado
      Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            const Text(
              'Efectivo que debería haber',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Text(
              _q(r.efectivoEsperado),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Caja abierta el ${_fechaFmt.format(caja.fechaApertura)}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
      _tarjeta(
        child: Column(
          children: [
            _FilaMonto('Fondo inicial', _q(r.fondoInicial)),
            _FilaMonto('+ Ventas en efectivo', _q(r.ventasEfectivo)),
            _FilaMonto('+ Ingresos', _q(r.ingresos)),
            _FilaMonto('− Gastos', _q(r.gastos), color: AppTheme.error),
            const Divider(height: 20),
            _FilaMonto(
              'Efectivo esperado',
              _q(r.efectivoEsperado),
              bold: true,
            ),
          ],
        ),
      ),
      _tarjeta(
        child: _MetodosResumen(
          totales: r.ventasPorMetodo,
          conteos: r.conteoPorMetodo,
          simbolo: _simbolo,
        ),
      ),
      _tarjeta(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Movimientos de efectivo',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Anota aquí el dinero que entra o sale de la gaveta y no es una '
              'venta (pago a un proveedor, retiro, cambio que agregas).',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _agregarMovimiento(MovimientoCaja.ingreso),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Ingreso'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _agregarMovimiento(MovimientoCaja.gasto),
                    icon: const Icon(Icons.remove_rounded, size: 18),
                    label: const Text('Gasto'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.error,
                      side: const BorderSide(color: AppTheme.error, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
            if (_movs.isNotEmpty) const SizedBox(height: 8),
            for (final m in _movs)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  m.concepto.isEmpty
                      ? (m.esGasto ? 'Gasto' : 'Ingreso')
                      : m.concepto,
                ),
                subtitle: Text(_fechaFmt.format(m.fecha)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${m.esGasto ? '−' : '+'} ${_q(m.monto)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: m.esGasto ? AppTheme.error : AppTheme.success,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        size: 20,
                        color: AppTheme.textMuted,
                      ),
                      onPressed: () => _eliminarMovimiento(m),
                      tooltip: 'Eliminar',
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      ..._seccionCierres(),
    ];
  }

  List<Widget> _seccionCierres() {
    if (_cierres.isEmpty) return const [];
    return [
      const Padding(
        padding: EdgeInsets.fromLTRB(4, 18, 4, 6),
        child: Text(
          'Cierres anteriores',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ),
      for (final c in _cierres)
        Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.bgWhite,
            borderRadius: BorderRadius.circular(14),
          ),
          child: ListTile(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DetalleCajaScreen(caja: c, simbolo: _simbolo),
              ),
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: Text(
              _fechaFmt.format(c.fechaCierre!),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            subtitle: Text(
              '${c.numVentas ?? 0} ventas · ${_q(c.totalVentas ?? 0)}',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: _EtiquetaDiferencia(
              diferencia: c.diferencia ?? 0,
              simbolo: _simbolo,
            ),
          ),
        ),
    ];
  }

  Widget _tarjeta({required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgWhite,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

// ============================================================
// DIÁLOGOS (con sus propios controladores)
// ============================================================
class _MovimientoInput {
  final String concepto;
  final double monto;
  _MovimientoInput(this.concepto, this.monto);
}

class _MovimientoDialog extends StatefulWidget {
  const _MovimientoDialog({required this.tipo});
  final String tipo;

  @override
  State<_MovimientoDialog> createState() => _MovimientoDialogState();
}

class _MovimientoDialogState extends State<_MovimientoDialog> {
  final _conceptoCtrl = TextEditingController();
  final _montoCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _conceptoCtrl.dispose();
    _montoCtrl.dispose();
    super.dispose();
  }

  void _guardar() {
    final monto = parseMonto(_montoCtrl.text);
    if (monto == null || monto <= 0) {
      setState(() => _error = 'Escribe un monto mayor que cero');
      return;
    }
    Navigator.pop(context, _MovimientoInput(_conceptoCtrl.text.trim(), monto));
  }

  @override
  Widget build(BuildContext context) {
    final esGasto = widget.tipo == MovimientoCaja.gasto;
    return AlertDialog(
      title: Text(esGasto ? 'Registrar gasto' : 'Registrar ingreso'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _montoCtrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: InputDecoration(labelText: 'Monto', errorText: _error),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _conceptoCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Concepto',
                hintText: esGasto ? 'Ej. Pago a proveedor' : 'Ej. Cambio agregado',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(onPressed: _guardar, child: const Text('Guardar')),
      ],
    );
  }
}

class _CierreInput {
  final double contado;
  final String nota;
  _CierreInput(this.contado, this.nota);
}

class _CierreDialog extends StatefulWidget {
  const _CierreDialog({required this.esperado, required this.simbolo});
  final double esperado;
  final String simbolo;

  @override
  State<_CierreDialog> createState() => _CierreDialogState();
}

class _CierreDialogState extends State<_CierreDialog> {
  final _contadoCtrl = TextEditingController();
  final _notaCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _contadoCtrl.dispose();
    _notaCtrl.dispose();
    super.dispose();
  }

  double? get _contado => parseMonto(_contadoCtrl.text);

  void _cerrar() {
    final c = _contado;
    if (c == null || c < 0) {
      setState(() => _error = 'Escribe cuánto efectivo contaste');
      return;
    }
    Navigator.pop(context, _CierreInput(c, _notaCtrl.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final c = _contado;
    final dif = c == null ? null : redondear2(c - widget.esperado);
    return AlertDialog(
      title: const Text('Cerrar caja'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Debería haber ${CurrencyFormatter.format(widget.esperado, widget.simbolo)}. '
              'Cuenta el efectivo de la gaveta y escríbelo aquí.',
              style: const TextStyle(color: AppTheme.textSecondary, height: 1.35),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _contadoCtrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              onChanged: (_) => setState(() => _error = null),
              decoration: InputDecoration(
                labelText: 'Efectivo contado',
                prefixText: '${widget.simbolo} ',
                errorText: _error,
              ),
            ),
            if (dif != null) ...[
              const SizedBox(height: 10),
              _EtiquetaDiferencia(
                diferencia: dif,
                simbolo: widget.simbolo,
                largo: true,
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _notaCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nota (opcional)',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(onPressed: _cerrar, child: const Text('Cerrar caja')),
      ],
    );
  }
}

// ============================================================
// WIDGETS DE APOYO
// ============================================================
class _FilaMonto extends StatelessWidget {
  const _FilaMonto(this.etiqueta, this.valor, {this.bold = false, this.color});
  final String etiqueta;
  final String valor;
  final bool bold;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final estilo = TextStyle(
      fontWeight: bold ? FontWeight.bold : FontWeight.w500,
      fontSize: bold ? 15 : 14,
      color: color,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(child: Text(etiqueta, style: estilo)),
          const SizedBox(width: 12),
          Text(valor, style: estilo),
        ],
      ),
    );
  }
}

class _EtiquetaDiferencia extends StatelessWidget {
  const _EtiquetaDiferencia({
    required this.diferencia,
    required this.simbolo,
    this.largo = false,
  });
  final double diferencia;
  final String simbolo;
  final bool largo;

  @override
  Widget build(BuildContext context) {
    final String texto;
    final Color color;
    if (diferencia.abs() < 0.005) {
      texto = largo ? 'La caja cuadra' : 'Cuadra';
      color = AppTheme.success;
    } else if (diferencia > 0) {
      final m = CurrencyFormatter.format(diferencia, simbolo);
      texto = largo ? 'Sobran $m' : '+$m';
      color = AppTheme.warning;
    } else {
      final m = CurrencyFormatter.format(-diferencia, simbolo);
      texto = largo ? 'Faltan $m' : '−$m';
      color = AppTheme.error;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        texto,
        style: TextStyle(
          color: color == AppTheme.warning ? const Color(0xFF9A6B00) : color,
          fontWeight: FontWeight.bold,
          fontSize: largo ? 14 : 12,
        ),
      ),
    );
  }
}

class _MetodosResumen extends StatelessWidget {
  const _MetodosResumen({
    required this.totales,
    required this.conteos,
    required this.simbolo,
  });
  final Map<String, double> totales;
  final Map<String, int> conteos;
  final String simbolo;

  @override
  Widget build(BuildContext context) {
    final claves = _ordenarMetodos(totales.keys);
    final total = totales.values.fold(0.0, (s, v) => s + v);
    final n = conteos.values.fold(0, (s, v) => s + v);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ventas por método de pago',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (claves.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Todavía no hay ventas en este turno',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
        for (final k in claves)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Icon(
                  MetodosPagoConfig.icons[k] ?? Icons.payments_rounded,
                  size: 20,
                  color: MetodosPagoConfig.colors[k] ?? AppTheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${MetodosPagoConfig.label(k)} (${conteos[k] ?? 0})',
                  ),
                ),
                Text(
                  CurrencyFormatter.format(totales[k] ?? 0, simbolo),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        if (claves.isNotEmpty) ...[
          const Divider(height: 20),
          _FilaMonto(
            'Total vendido ($n)',
            CurrencyFormatter.format(total, simbolo),
            bold: true,
          ),
        ],
      ],
    );
  }
}

// ============================================================
// DETALLE DE UN CIERRE
// ============================================================
class DetalleCajaScreen extends StatefulWidget {
  const DetalleCajaScreen({super.key, required this.caja, required this.simbolo});
  final Caja caja;
  final String simbolo;

  @override
  State<DetalleCajaScreen> createState() => _DetalleCajaScreenState();
}

class _DetalleCajaScreenState extends State<DetalleCajaScreen> {
  List<MovimientoCaja> _movs = [];

  Caja get _c => widget.caja;
  String _q(double v) => CurrencyFormatter.format(v, widget.simbolo);

  @override
  void initState() {
    super.initState();
    DatabaseService.instance.obtenerMovimientosCaja(_c.id).then((m) {
      if (mounted) setState(() => _movs = m);
    });
  }

  String _textoResumen() {
    final b = StringBuffer()
      ..writeln('${AppConfig.nombre} - Cierre de caja')
      ..writeln('Apertura: ${_fechaFmt.format(_c.fechaApertura)}')
      ..writeln(
        'Cierre: ${_c.fechaCierre == null ? '-' : _fechaFmt.format(_c.fechaCierre!)}',
      )
      ..writeln('')
      ..writeln('Fondo inicial: ${_q(_c.fondoInicial)}')
      ..writeln('Ventas (${_c.numVentas ?? 0}): ${_q(_c.totalVentas ?? 0)}');
    for (final k in _ordenarMetodos(_c.detalleMetodos.keys)) {
      final d = _c.detalleMetodos[k]!;
      b.writeln(
        '  ${MetodosPagoConfig.label(k)} (${d['n'] ?? 0}): ${_q((d['total'] ?? 0).toDouble())}',
      );
    }
    b
      ..writeln('Ingresos: ${_q(_c.totalIngresos ?? 0)}')
      ..writeln('Gastos: ${_q(_c.totalGastos ?? 0)}')
      ..writeln('')
      ..writeln('Efectivo esperado: ${_q(_c.efectivoEsperado ?? 0)}')
      ..writeln('Efectivo contado: ${_q(_c.efectivoContado ?? 0)}')
      ..writeln('Diferencia: ${_q(_c.diferencia ?? 0)}');
    if (_c.nota != null) b.writeln('Nota: ${_c.nota}');
    return b.toString();
  }

  Future<void> _compartir() async {
    final ok = await WhatsAppShare.enviar(texto: _textoResumen());
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo compartir'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final totales = <String, double>{};
    final conteos = <String, int>{};
    _c.detalleMetodos.forEach((k, d) {
      totales[k] = (d['total'] ?? 0).toDouble();
      conteos[k] = (d['n'] ?? 0).toInt();
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cierre de caja'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, color: AppTheme.primary),
            onPressed: _compartir,
            tooltip: 'Compartir resumen',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: listBottomPadding(context, top: 8),
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Text(
                  'Efectivo contado',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  _q(_c.efectivoContado ?? 0),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _EtiquetaDiferencia(
                    diferencia: _c.diferencia ?? 0,
                    simbolo: widget.simbolo,
                    largo: true,
                  ),
                ),
              ],
            ),
          ),
          _bloque(
            Column(
              children: [
                _FilaMonto('Apertura', _fechaFmt.format(_c.fechaApertura)),
                _FilaMonto(
                  'Cierre',
                  _c.fechaCierre == null ? '-' : _fechaFmt.format(_c.fechaCierre!),
                ),
                const Divider(height: 20),
                _FilaMonto('Fondo inicial', _q(_c.fondoInicial)),
                _FilaMonto('+ Ventas en efectivo', _q(totales['efectivo'] ?? 0)),
                _FilaMonto('+ Ingresos', _q(_c.totalIngresos ?? 0)),
                _FilaMonto(
                  '− Gastos',
                  _q(_c.totalGastos ?? 0),
                  color: AppTheme.error,
                ),
                const Divider(height: 20),
                _FilaMonto(
                  'Efectivo esperado',
                  _q(_c.efectivoEsperado ?? 0),
                  bold: true,
                ),
                _FilaMonto(
                  'Efectivo contado',
                  _q(_c.efectivoContado ?? 0),
                  bold: true,
                ),
              ],
            ),
          ),
          _bloque(
            _MetodosResumen(
              totales: totales,
              conteos: conteos,
              simbolo: widget.simbolo,
            ),
          ),
          if (_movs.isNotEmpty)
            _bloque(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Movimientos de efectivo',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  for (final m in _movs)
                    _FilaMonto(
                      m.concepto.isEmpty
                          ? (m.esGasto ? 'Gasto' : 'Ingreso')
                          : m.concepto,
                      '${m.esGasto ? '−' : '+'} ${_q(m.monto)}',
                      color: m.esGasto ? AppTheme.error : AppTheme.success,
                    ),
                ],
              ),
            ),
          if (_c.nota != null)
            _bloque(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Nota',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(_c.nota!),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _bloque(Widget child) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgWhite,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}
