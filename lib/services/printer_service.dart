import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/venta.dart';
import '../models/caja.dart';
import '../utils/currency_formatter.dart';
import '../utils/peso_formatter.dart';
import '../config/app_config.dart';

class PrinterService {
  static final PrinterService instance = PrinterService._();
  PrinterService._();

  String _monedaSimbolo = 'Q';
  String _nombreNegocio = AppConfig.nombreMayus;
  String _direccion = '';
  String _telefono = '';
  String _ruc = '';
  String _mensajePie = '¡Gracias por su compra!';
  double _anchoPapel = 58.0;
  String? _impresoraMac;
  String? _impresoraNombre;
  String? _vendedor;

  int get _chars => _anchoPapel == 80.0 ? 48 : 32;

  String _stripAccents(String str) {
    return str
        .replaceAll('á', 'a').replaceAll('é', 'e').replaceAll('í', 'i').replaceAll('ó', 'o').replaceAll('ú', 'u')
        .replaceAll('Á', 'A').replaceAll('É', 'E').replaceAll('Í', 'I').replaceAll('Ó', 'O').replaceAll('Ú', 'U')
        .replaceAll('ñ', 'n').replaceAll('Ñ', 'N');
  }

  String _formatMoney(double amount) =>
      CurrencyFormatter.format(amount, _monedaSimbolo);

  void configurar({
    String? nombre,
    String? direccion,
    String? telefono,
    String? ruc,
    String? mensaje,
    double? anchoPapel,
    String? mac,
    String? printerName,
    String? moneda,
    String? vendedor,
  }) {
    if (nombre != null) _nombreNegocio = nombre;
    if (direccion != null) _direccion = direccion;
    if (telefono != null) _telefono = telefono;
    if (ruc != null) _ruc = ruc;
    if (mensaje != null) _mensajePie = mensaje;
    if (anchoPapel != null) _anchoPapel = anchoPapel;
    if (mac != null) _impresoraMac = mac;
    if (printerName != null) _impresoraNombre = printerName;
    if (moneda != null) _monedaSimbolo = moneda;
    if (vendedor != null) _vendedor = vendedor;
  }

  Future<void> cargarDesdePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    configurar(
      nombre: prefs.getString('negocio_nombre') ?? _nombreNegocio,
      direccion: prefs.getString('negocio_direccion') ?? '',
      telefono: prefs.getString('negocio_telefono') ?? '',
      ruc: prefs.getString('negocio_ruc') ?? '',
      mensaje: prefs.getString('negocio_mensaje') ?? _mensajePie,
      anchoPapel: prefs.getDouble('impresora_ancho') ?? 58.0,
      mac: prefs.getString('impresora_mac'),
      printerName: prefs.getString('impresora_nombre'),
      moneda: prefs.getString('moneda_simbolo') ?? 'Q',
      vendedor: prefs.getString('vendedor_activo'),
    );
  }

  String? get impresoraNombre => _impresoraNombre;
  String? get impresoraMac => _impresoraMac;

  String _hr() => '-' * _chars;

  String _lr(String left, String right) {
    if (right.length >= _chars) return right.substring(0, _chars);
    final maxLeft = _chars - right.length - 1;
    var l = left;
    if (l.length > maxLeft) l = l.substring(0, maxLeft);
    final spaces = _chars - l.length - right.length;
    return '$l${' ' * spaces}$right';
  }

  String _metodoPagoLabel(String metodo) {
    switch (metodo) {
      case 'efectivo':
        return 'Efectivo';
      case 'yape':
        return 'Transferencia';
      case 'plin':
        return 'Tigo Money';
      case 'tarjeta':
        return 'Tarjeta';
      default:
        return metodo;
    }
  }

  List<String> _lineasCuerpo(Venta venta) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'es');
    final lines = <String>[];
    lines.add(_hr());
    lines.add(_lr(
      'TICKET DE VENTA',
      '#${venta.id.substring(0, 8).toUpperCase()}',
    ));
    lines.add(_lr('Fecha:', dateFormat.format(venta.fecha)));
    if (_vendedor != null && _vendedor!.isNotEmpty) {
      lines.add(_lr('Atendido por:', _vendedor!));
    }
    lines.add(_hr());
    lines.add(_lr('Cant  Producto', 'Total'));
    lines.add(_hr());

    for (final item in venta.items) {
      final cant = item.esPeso
          ? PesoFormatter.formatTicket(item.cantidad)
          : '${item.cantidad}';
      final nombre = item.productoNombre;
      final total = _formatMoney(item.subtotal);
      final left = '$cant  $nombre';
      if (left.length + 1 + total.length <= _chars) {
        lines.add(_lr(left, total));
      } else {
        lines.add(_lr(
          '$cant  ${nombre.length > 18 ? nombre.substring(0, 18) : nombre}',
          total,
        ));
      }
    }

    lines.add(_hr());
    if (venta.descuento > 0) {
      lines.add(_lr('Subtotal:', _formatMoney(venta.subtotal)));
      lines.add(_lr('Descuento:', '-${_formatMoney(venta.descuento)}'));
    }
    lines.add(_lr('TOTAL:', _formatMoney(venta.total)));
    lines.add(_lr('Pago:', _metodoPagoLabel(venta.metodoPago)));
    if (venta.montoPagado != null) {
      lines.add(_lr('Pago con:', _formatMoney(venta.montoPagado!)));
    }
    if (venta.vuelto != null && venta.vuelto! > 0) {
      lines.add(_lr('Vuelto:', _formatMoney(venta.vuelto!)));
    }
    lines.add(_hr());
    return lines;
  }

  /// Texto plano para WhatsApp (no PDF ni archivo).
  Future<String> textoTicket(Venta venta) async {
    await cargarDesdePrefs();
    final buf = StringBuffer();
    buf.writeln('*${_nombreNegocio.toUpperCase()}*');
    if (_ruc.isNotEmpty) buf.writeln('NIT: $_ruc');
    if (_direccion.isNotEmpty) buf.writeln(_direccion);
    if (_telefono.isNotEmpty) buf.writeln('Tel: $_telefono');
    for (final line in _lineasCuerpo(venta)) {
      buf.writeln(line);
    }
    buf.writeln(_mensajePie);
    buf.writeln('${AppConfig.nombreSinAcentos} v${AppConfig.version}');
    return buf.toString().trim();
  }

  /// Centrado real (ESC a 1). No usa espacios: esos empujan el texto a la derecha.
  List<int> _bytesCentrado(
    String texto, {
    bool grande = false,
    bool negrita = false,
  }) {
    final t = _stripAccents(texto);
    final bytes = <int>[
      0x1B, 0x61, 0x01, // ESC a 1 = centrar
    ];
    if (negrita) bytes.addAll([0x1B, 0x45, 0x01]);
    if (grande) bytes.addAll([0x1D, 0x21, 0x11]); // ancho y alto x2
    bytes.addAll(latin1.encode(t));
    bytes.add(0x0A);
    if (grande) bytes.addAll([0x1D, 0x21, 0x00]);
    if (negrita) bytes.addAll([0x1B, 0x45, 0x00]);
    bytes.addAll([0x1B, 0x61, 0x00]); // volver a la izquierda
    return bytes;
  }

  Future<void> imprimirTicket(Venta venta, {String? macOverride}) async {
    await cargarDesdePrefs();
    final mac = macOverride ?? _impresoraMac;
    if (mac == null || mac.isEmpty) {
      throw Exception('No hay impresora configurada');
    }

    final conectado = await PrintBluetoothThermal.connectionStatus;
    if (!conectado) {
      final res = await PrintBluetoothThermal.connect(macPrinterAddress: mac);
      if (!res) throw Exception('No se pudo conectar a la impresora');
    }

    final profile = await CapabilityProfile.load();
    final generator = Generator(
      _anchoPapel == 80.0 ? PaperSize.mm80 : PaperSize.mm58,
      profile,
    );
    List<int> bytes = [];
    bytes += generator.reset();
    bytes += generator.setGlobalFont(PosFontType.fontA);

    bytes += _bytesCentrado(
      _nombreNegocio.toUpperCase(),
      grande: true,
      negrita: true,
    );
    if (_ruc.isNotEmpty) {
      bytes += _bytesCentrado('NIT: $_ruc');
    }
    if (_direccion.isNotEmpty) {
      bytes += _bytesCentrado(_direccion);
    }
    if (_telefono.isNotEmpty) {
      bytes += _bytesCentrado('Tel: $_telefono');
    }

    const izquierda = PosStyles(align: PosAlign.left);
    for (final line in _lineasCuerpo(venta)) {
      bytes += generator.text(_stripAccents(line), styles: izquierda);
    }

    bytes += _bytesCentrado(_mensajePie);
    bytes += _bytesCentrado('${AppConfig.nombreSinAcentos} v${AppConfig.version}');

    bytes += generator.feed(2);
    bytes += generator.cut();

    await PrintBluetoothThermal.writeBytes(bytes);
  }

  // ============ CUADRE DE CAJA ============

  static const _ordenMetodos = ['efectivo', 'yape', 'plin', 'tarjeta'];

  List<String> _lineasCuadre(CierreCaja c) {
    final f = DateFormat('dd/MM/yyyy', 'es');
    final lines = <String>[];
    lines.add(_hr());
    lines.add('CUADRE DE CAJA');
    lines.add(_lr('Periodo:', PeriodoCaja.nombre(c.periodo)));
    lines.add(_lr('Desde:', f.format(c.desde)));
    lines.add(_lr('Hasta:', f.format(c.hasta)));
    lines.add(_hr());
    lines.add(_lr('Ventas:', '${c.numVentas}'));
    lines.add(_lr('Vendido:', _formatMoney(c.totalVendido)));
    lines.add(_lr(
      'Ganancia:',
      c.ganancia == null ? '-' : _formatMoney(c.ganancia!),
    ));
    lines.add(_hr());
    lines.add('INGRESOS POR METODO');
    final claves = c.detalleMetodos.keys.toList()
      ..sort((a, b) {
        int pos(String k) {
          final i = _ordenMetodos.indexOf(k);
          return i < 0 ? 99 : i;
        }

        return pos(a).compareTo(pos(b));
      });
    for (final k in claves) {
      final d = c.detalleMetodos[k]!;
      lines.add(_lr(
        '${_metodoPagoLabel(k)} (${d['n'] ?? 0})',
        _formatMoney((d['total'] ?? 0).toDouble()),
      ));
    }
    lines.add(_hr());
    lines.add('EFECTIVO EN CAJA');
    lines.add(_lr('Fondo inicial:', _formatMoney(c.fondoInicial)));
    lines.add(_lr('+ Efectivo periodo:', _formatMoney(c.efectivoPeriodo)));
    lines.add(_lr('Esperado:', _formatMoney(c.efectivoEsperado)));
    if (c.efectivoContado != null) {
      lines.add(_lr('Contado:', _formatMoney(c.efectivoContado!)));
      final dif = c.diferencia ?? 0;
      if (dif.abs() < 0.005) {
        lines.add(_lr('Resultado:', 'Cuadra'));
      } else if (dif > 0) {
        lines.add(_lr('Sobrante:', _formatMoney(dif)));
      } else {
        lines.add(_lr('Faltante:', _formatMoney(-dif)));
      }
    }
    if (c.nota != null) lines.add('Nota: ${c.nota}');
    lines.add(_hr());
    return lines;
  }

  /// Texto plano del cuadre para compartir por WhatsApp.
  Future<String> textoCuadre(CierreCaja c) async {
    await cargarDesdePrefs();
    final buf = StringBuffer();
    buf.writeln('*${_nombreNegocio.toUpperCase()}*');
    for (final line in _lineasCuadre(c)) {
      buf.writeln(line);
    }
    buf.writeln('${AppConfig.nombreSinAcentos} v${AppConfig.version}');
    return buf.toString().trim();
  }

  Future<void> imprimirCuadre(CierreCaja c, {String? macOverride}) async {
    await cargarDesdePrefs();
    final mac = macOverride ?? _impresoraMac;
    if (mac == null || mac.isEmpty) {
      throw Exception('No hay impresora configurada');
    }

    final conectado = await PrintBluetoothThermal.connectionStatus;
    if (!conectado) {
      final res = await PrintBluetoothThermal.connect(macPrinterAddress: mac);
      if (!res) throw Exception('No se pudo conectar a la impresora');
    }

    final profile = await CapabilityProfile.load();
    final generator = Generator(
      _anchoPapel == 80.0 ? PaperSize.mm80 : PaperSize.mm58,
      profile,
    );
    List<int> bytes = [];
    bytes += generator.reset();
    bytes += generator.setGlobalFont(PosFontType.fontA);
    bytes += _bytesCentrado(
      _nombreNegocio.toUpperCase(),
      grande: true,
      negrita: true,
    );

    const izquierda = PosStyles(align: PosAlign.left);
    for (final line in _lineasCuadre(c)) {
      bytes += generator.text(_stripAccents(line), styles: izquierda);
    }
    bytes += _bytesCentrado('${AppConfig.nombreSinAcentos} v${AppConfig.version}');
    bytes += generator.feed(2);
    bytes += generator.cut();

    await PrintBluetoothThermal.writeBytes(bytes);
  }

  Future<List<BluetoothInfo>> obtenerImpresoras() async {
    return await PrintBluetoothThermal.pairedBluetooths;
  }
}
