import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/caja.dart';
import '../services/database_service.dart';
import '../services/printer_service.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';
import '../utils/metodos_pago_config.dart';
import '../utils/safe_area_padding.dart';
import '../utils/whatsapp_share.dart';

/// Convierte lo que escribe el usuario ("12.50" o "12,50") en número.
double? parseMonto(String texto) {
  final v = double.tryParse(texto.trim().replaceAll(',', '.'));
  if (v == null || v.isNaN || v.isInfinite) return null;
  return v;
}

const _naranja = Color(0xFFEF6C00);

/// Texto corto del periodo: "Hoy", "12 oct - 18 oct 2026" o "Octubre 2026".
String etiquetaPeriodo(String periodo, DateTime desde, DateTime hasta) {
  if (periodo == PeriodoCaja.semana) {
    final a = DateFormat('d MMM', 'es').format(desde);
    final b = DateFormat('d MMM yyyy', 'es').format(hasta);
    return '$a - $b';
  }
  if (periodo == PeriodoCaja.mes) {
    final t = DateFormat('MMMM yyyy', 'es').format(desde);
    return t[0].toUpperCase() + t.substring(1);
  }
  final hoy = DateTime.now();
  final esHoy =
      desde.year == hoy.year && desde.month == hoy.month && desde.day == hoy.day;
  return esHoy ? 'Hoy' : DateFormat('dd/MM/yyyy', 'es').format(desde);
}

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
// PANTALLA PRINCIPAL: CUADRE DE CAJA
// ============================================================
class CajaScreen extends StatefulWidget {
  const CajaScreen({super.key});

  @override
  State<CajaScreen> createState() => _CajaScreenState();
}

class _CajaScreenState extends State<CajaScreen> {
  final _db = DatabaseService.instance;
  final _fondoCtrl = TextEditingController();
  final _contadoCtrl = TextEditingController();
  final _notaCtrl = TextEditingController();

  String _periodo = PeriodoCaja.dia;
  DateTime _ref = DateTime.now();
  String _simbolo = 'Q';
  bool _loading = true;
  int _cargaId = 0;
  ResumenCuadre? _resumen;
  List<CierreCaja> _cierres = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _fondoCtrl.dispose();
    _contadoCtrl.dispose();
    _notaCtrl.dispose();
    super.dispose();
  }

  ({DateTime desde, DateTime hasta}) get _rango =>
      PeriodoCaja.rango(_periodo, _ref);

  double get _fondo => parseMonto(_fondoCtrl.text) ?? 0;
  double? get _contado => parseMonto(_contadoCtrl.text);

  String _q(double v) => CurrencyFormatter.format(v, _simbolo);

  Future<void> _cargar() async {
    final id = ++_cargaId;
    final prefs = await SharedPreferences.getInstance();
    final simbolo = prefs.getString('moneda_simbolo') ?? 'Q';
    final r = _rango;
    final resumen = await _db.resumenCuadre(r.desde, r.hasta);
    final cierres = await _db.obtenerCierres();
    // Si el usuario cambió de periodo mientras cargaba, se descarta este resultado.
    if (!mounted || id != _cargaId) return;
    setState(() {
      _simbolo = simbolo;
      _resumen = resumen;
      _cierres = cierres;
      _loading = false;
    });
  }

  void _limpiarCampos() {
    _fondoCtrl.clear();
    _contadoCtrl.clear();
    _notaCtrl.clear();
  }

  void _cambiarPeriodo(String p) {
    if (p == _periodo) return;
    setState(() {
      _periodo = p;
      _limpiarCampos();
    });
    _cargar();
  }

  void _mover(int pasos) {
    setState(() {
      _ref = PeriodoCaja.mover(_periodo, _ref, pasos);
      _limpiarCampos();
    });
    _cargar();
  }

  Future<void> _elegirFecha() async {
    final ahora = DateTime.now();
    final f = await showDatePicker(
      context: context,
      initialDate: _ref.isAfter(ahora) ? ahora : _ref,
      firstDate: DateTime(2020),
      lastDate: ahora,
      helpText: 'Elige una fecha',
    );
    if (f == null || !mounted) return;
    setState(() {
      _ref = f;
      _limpiarCampos();
    });
    _cargar();
  }

  void _aviso(String texto, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texto),
        backgroundColor: error ? AppTheme.error : AppTheme.success,
      ),
    );
  }

  /// El cuadre tal como se ve ahora en pantalla (para imprimir o compartir).
  CierreCaja? _borrador({String id = ''}) {
    final r = _resumen;
    if (r == null) return null;
    final rango = _rango;
    return CierreCaja.desdeResumen(
      id: id,
      periodo: _periodo,
      desde: rango.desde,
      hasta: rango.hasta,
      resumen: r,
      fondoInicial: _fondo,
      efectivoContado: _contado,
      nota: _notaCtrl.text,
    );
  }

  Future<void> _imprimir() async {
    final c = _borrador();
    if (c == null) return;
    try {
      await PrinterService.instance.imprimirCuadre(c);
      HapticFeedback.heavyImpact();
    } catch (e) {
      if (!mounted) return;
      _aviso('No se pudo imprimir: $e', error: true);
    }
  }

  Future<void> _compartir() async {
    final c = _borrador();
    if (c == null) return;
    final texto = await PrinterService.instance.textoCuadre(c);
    final ok = await WhatsAppShare.enviar(texto: texto);
    if (!ok && mounted) _aviso('No se pudo compartir', error: true);
  }

  Future<void> _guardarCierre() async {
    if (_contado == null) {
      _aviso('Escribe el efectivo contado para guardar el cierre', error: true);
      return;
    }
    final c = _borrador(id: const Uuid().v4());
    if (c == null) return;
    FocusScope.of(context).unfocus();
    await _db.guardarCierre(c);
    if (!mounted) return;
    setState(_limpiarCampos);
    await _cargar();
    if (mounted) _aviso('Cierre guardado');
  }

  Future<void> _abrirDetalle(CierreCaja c) async {
    final cambio = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DetalleCierreScreen(cierre: c, simbolo: _simbolo),
      ),
    );
    if (cambio == true && mounted) _cargar();
  }

  // ---------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cuadre de caja'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_rounded, color: AppTheme.primary),
            onPressed: _resumen == null ? null : _imprimir,
            tooltip: 'Imprimir cuadre',
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded, color: AppTheme.primary),
            onPressed: _resumen == null ? null : _compartir,
            tooltip: 'Compartir por WhatsApp',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: listBottomPadding(context, top: 8, bottomExtra: 24),
              children: [
                _selectorPeriodo(),
                const SizedBox(height: 10),
                _selectorFecha(),
                const SizedBox(height: 12),
                _tarjetaResumen(),
                ..._ingresosPorMetodo(),
                ..._efectivoEnCaja(),
                ..._cierresGuardados(),
              ],
            ),
    );
  }

  Widget _selectorPeriodo() {
    return Row(
      children: [
        for (var i = 0; i < PeriodoCaja.todos.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: _chipPeriodo(PeriodoCaja.todos[i])),
        ],
      ],
    );
  }

  Widget _chipPeriodo(String p) {
    final sel = p == _periodo;
    return GestureDetector(
      onTap: () => _cambiarPeriodo(p),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: sel ? AppTheme.primary : AppTheme.bgWhite,
          borderRadius: BorderRadius.circular(12),
          border: sel ? null : Border.all(color: AppTheme.border),
        ),
        child: Center(
          child: Text(
            PeriodoCaja.nombre(p),
            style: TextStyle(
              color: sel ? Colors.white : AppTheme.textPrimary,
              fontWeight: sel ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _selectorFecha() {
    final r = _rango;
    final esUltimo = r.hasta.isAfter(DateTime.now());
    return Row(
      children: [
        IconButton(
          onPressed: () => _mover(-1),
          icon: const Icon(Icons.chevron_left_rounded),
          tooltip: 'Anterior',
        ),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _elegirFecha,
            icon: const Icon(Icons.calendar_month_rounded, size: 20),
            label: Text(etiquetaPeriodo(_periodo, r.desde, r.hasta)),
            style: OutlinedButton.styleFrom(
              backgroundColor: AppTheme.bgWhite,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        IconButton(
          onPressed: esUltimo ? null : () => _mover(1),
          icon: const Icon(Icons.chevron_right_rounded),
          tooltip: 'Siguiente',
        ),
      ],
    );
  }

  Widget _tarjetaResumen() {
    final r = _resumen!;
    return _ResumenCard(
      ventas: r.numVentas,
      vendido: _q(r.totalVendido),
      ingresos: _q(r.totalVendido),
      ganancia: r.ganancia == null ? '—' : _q(r.ganancia!),
    );
  }

  List<Widget> _ingresosPorMetodo() {
    final r = _resumen!;
    final claves = <String>[
      ...MetodosPagoConfig.todos,
      ..._ordenarMetodos(
        r.ventasPorMetodo.keys.where((k) => !MetodosPagoConfig.todos.contains(k)),
      ),
    ];
    return [
      const _Titulo('Ingresos por método'),
      for (final k in claves)
        _MetodoFila(
          metodo: k,
          total: _q(r.ventasPorMetodo[k] ?? 0),
          conteo: r.conteoPorMetodo[k] ?? 0,
        ),
    ];
  }

  List<Widget> _efectivoEnCaja() {
    final r = _resumen!;
    final fondo = _fondo;
    final esperado = r.esperado(fondo);
    final contado = _contado;
    return [
      const _Titulo('Efectivo en caja'),
      const Padding(
        padding: EdgeInsets.only(bottom: 10),
        child: Text(
          'Solo cuenta el dinero físico. Transferencia, Tigo Money y tarjeta '
          'no entran al cajón.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
      ),
      TextField(
        controller: _fondoCtrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: 'Fondo inicial',
          helperText: 'Lo que había al abrir (vuelto / cambio)',
          prefixText: '$_simbolo ',
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _contadoCtrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: 'Efectivo contado',
          helperText: 'Lo que hay en el cajón al cerrar',
          prefixText: '$_simbolo ',
        ),
      ),
      const SizedBox(height: 12),
      _Bloque(
        child: Column(
          children: [
            _FilaMonto('Fondo inicial', _q(fondo)),
            _FilaMonto('+ Efectivo del período', _q(r.efectivoPeriodo)),
            const Divider(height: 20),
            _FilaMonto('= Efectivo esperado', _q(esperado), bold: true),
          ],
        ),
      ),
      // La diferencia solo aparece después de escribir el efectivo contado.
      if (contado != null) ...[
        const SizedBox(height: 10),
        _BannerDiferencia(
          diferencia: r.diferencia(fondo, contado),
          simbolo: _simbolo,
        ),
      ],
      const SizedBox(height: 12),
      TextField(
        controller: _notaCtrl,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(labelText: 'Nota (opcional)'),
      ),
      const SizedBox(height: 14),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: contado == null ? null : _guardarCierre,
          icon: const Icon(Icons.save_rounded),
          label: const Text('Guardar cierre'),
        ),
      ),
    ];
  }

  List<Widget> _cierresGuardados() {
    return [
      const _Titulo('Cierres guardados'),
      if (_cierres.isEmpty)
        const _Bloque(
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Aún no hay cierres guardados',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          ),
        ),
      for (final c in _cierres)
        Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.bgWhite,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border),
          ),
          child: ListTile(
            onTap: () => _abrirDetalle(c),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: Text(
              '${PeriodoCaja.nombre(c.periodo)} · '
              '${etiquetaPeriodo(c.periodo, c.desde, c.hasta)}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            subtitle: Text(
              'Esperado ${_q(c.efectivoEsperado)} · '
              'Contado ${_q(c.efectivoContado ?? 0)}',
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
}

// ============================================================
// DETALLE DE UN CIERRE GUARDADO
// ============================================================
class DetalleCierreScreen extends StatelessWidget {
  const DetalleCierreScreen({super.key, required this.cierre, required this.simbolo});

  final CierreCaja cierre;
  final String simbolo;

  String _q(double v) => CurrencyFormatter.format(v, simbolo);

  Future<void> _imprimir(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await PrinterService.instance.imprimirCuadre(cierre);
      HapticFeedback.heavyImpact();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('No se pudo imprimir: $e'),
          backgroundColor: AppTheme.warning,
        ),
      );
    }
  }

  Future<void> _compartir(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final texto = await PrinterService.instance.textoCuadre(cierre);
    final ok = await WhatsAppShare.enviar(texto: texto);
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No se pudo compartir'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  Future<void> _eliminar(BuildContext context) async {
    final navigator = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar cierre'),
        content: const Text(
          '¿Eliminar este cierre guardado? Las ventas no se borran.',
        ),
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
    await DatabaseService.instance.eliminarCierre(cierre.id);
    navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final c = cierre;
    final claves = <String>[
      ...MetodosPagoConfig.todos,
      ..._ordenarMetodos(
        c.detalleMetodos.keys.where((k) => !MetodosPagoConfig.todos.contains(k)),
      ),
    ];
    final fechaFmt = DateFormat('dd/MM/yyyy HH:mm', 'es');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cierre de caja'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_rounded, color: AppTheme.primary),
            onPressed: () => _imprimir(context),
            tooltip: 'Imprimir',
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded, color: AppTheme.primary),
            onPressed: () => _compartir(context),
            tooltip: 'Compartir por WhatsApp',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.error),
            onPressed: () => _eliminar(context),
            tooltip: 'Eliminar cierre',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: listBottomPadding(context, top: 8, bottomExtra: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
            child: Text(
              '${PeriodoCaja.nombre(c.periodo)} · '
              '${etiquetaPeriodo(c.periodo, c.desde, c.hasta)}\n'
              'Guardado el ${fechaFmt.format(c.fechaCierre)}',
              style: const TextStyle(color: AppTheme.textSecondary, height: 1.4),
            ),
          ),
          _ResumenCard(
            ventas: c.numVentas,
            vendido: _q(c.totalVendido),
            ingresos: _q(c.totalVendido),
            ganancia: c.ganancia == null ? '—' : _q(c.ganancia!),
          ),
          const _Titulo('Ingresos por método'),
          for (final k in claves)
            _MetodoFila(
              metodo: k,
              total: _q((c.detalleMetodos[k]?['total'] ?? 0).toDouble()),
              conteo: (c.detalleMetodos[k]?['n'] ?? 0).toInt(),
            ),
          const _Titulo('Efectivo en caja'),
          _Bloque(
            child: Column(
              children: [
                _FilaMonto('Fondo inicial', _q(c.fondoInicial)),
                _FilaMonto('+ Efectivo del período', _q(c.efectivoPeriodo)),
                const Divider(height: 20),
                _FilaMonto('= Efectivo esperado', _q(c.efectivoEsperado), bold: true),
                _FilaMonto(
                  'Efectivo contado',
                  _q(c.efectivoContado ?? 0),
                  bold: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _BannerDiferencia(diferencia: c.diferencia ?? 0, simbolo: simbolo),
          if (c.nota != null) ...[
            const _Titulo('Nota'),
            _Bloque(child: Text(c.nota!)),
          ],
        ],
      ),
    );
  }
}

// ============================================================
// WIDGETS DE APOYO
// ============================================================
class _Titulo extends StatelessWidget {
  const _Titulo(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 8),
      child: Text(
        texto,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _Bloque extends StatelessWidget {
  const _Bloque({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: child,
    );
  }
}

class _ResumenCard extends StatelessWidget {
  const _ResumenCard({
    required this.ventas,
    required this.vendido,
    required this.ingresos,
    required this.ganancia,
  });
  final int ventas;
  final String vendido;
  final String ingresos;
  final String ganancia;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _Dato('$ventas', 'Ventas')),
              Expanded(child: _Dato(vendido, 'Vendido')),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _Dato(ingresos, 'Ingresos')),
              Expanded(child: _Dato(ganancia, 'Ganancia')),
            ],
          ),
        ],
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato(this.valor, this.etiqueta);
  final String valor;
  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            valor,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          etiqueta,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
      ],
    );
  }
}

class _MetodoFila extends StatelessWidget {
  const _MetodoFila({
    required this.metodo,
    required this.total,
    required this.conteo,
  });
  final String metodo;
  final String total;
  final int conteo;

  @override
  Widget build(BuildContext context) {
    final color = MetodosPagoConfig.colors[metodo] ?? AppTheme.primary;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.bgWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Icon(
            MetodosPagoConfig.icons[metodo] ?? Icons.payments_rounded,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              conteo > 0
                  ? '${MetodosPagoConfig.label(metodo)} ($conteo)'
                  : MetodosPagoConfig.label(metodo),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
          Text(
            total,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilaMonto extends StatelessWidget {
  const _FilaMonto(this.etiqueta, this.valor, {this.bold = false});
  final String etiqueta;
  final String valor;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final estilo = TextStyle(
      fontWeight: bold ? FontWeight.bold : FontWeight.w500,
      fontSize: bold ? 15 : 14,
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

/// Resultado del cuadre: Faltante (rojo), Sobrante (naranja) o Cuadra (verde).
({String texto, Color color, IconData icono}) _estadoDiferencia(
  double diferencia,
  String simbolo,
) {
  if (diferencia.abs() < 0.005) {
    return (
      texto: 'Cuadra',
      color: AppTheme.success,
      icono: Icons.check_circle_rounded,
    );
  }
  final monto = CurrencyFormatter.format(diferencia.abs(), simbolo);
  if (diferencia > 0) {
    return (
      texto: 'Sobrante $monto',
      color: _naranja,
      icono: Icons.arrow_circle_up_rounded,
    );
  }
  return (
    texto: 'Faltante $monto',
    color: AppTheme.error,
    icono: Icons.arrow_circle_down_rounded,
  );
}

class _BannerDiferencia extends StatelessWidget {
  const _BannerDiferencia({required this.diferencia, required this.simbolo});
  final double diferencia;
  final String simbolo;

  @override
  Widget build(BuildContext context) {
    final e = _estadoDiferencia(diferencia, simbolo);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: e.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: e.color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(e.icono, color: e.color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              e.texto,
              style: TextStyle(
                color: e.color,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EtiquetaDiferencia extends StatelessWidget {
  const _EtiquetaDiferencia({required this.diferencia, required this.simbolo});
  final double diferencia;
  final String simbolo;

  @override
  Widget build(BuildContext context) {
    final e = _estadoDiferencia(diferencia, simbolo);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: e.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        e.texto,
        style: TextStyle(
          color: e.color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}
