import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'licencia_clave.dart';

enum EstadoLicencia { prueba, activa, vencida }

class ResultadoClave {
  final bool ok;
  final String mensaje;
  const ResultadoClave(this.ok, this.mensaje);
}

/// Licencia de uso: 7 días de prueba y luego una clave de 30 días.
///
/// Con la licencia vencida la app deja ver el historial y exportar, pero no
/// permite hacer ventas nuevas ([puedeVender] es false).
///
/// El secreto con el que se firman las claves NO está en el código: se pasa al
/// compilar con `--dart-define=LICENSE_SECRET=...` (ver LICENCIAS.md).
class LicenseService extends ChangeNotifier {
  LicenseService._();
  static final LicenseService instance = LicenseService._();

  static const diasPrueba = 7;

  /// Desde cuántos días restantes se muestra el aviso de renovación.
  static const diasAviso = 5;

  static const _secreto = String.fromEnvironment('LICENSE_SECRET');
  static const _kInicio = 'lic_inicio_ms';
  static const _kVence = 'lic_vence_ms';
  static const _kVista = 'lic_ultima_vista_ms';
  static const _msDia = 24 * 60 * 60 * 1000;

  SharedPreferences? _prefs;
  int _inicioMs = 0;
  int _venceMs = 0;

  /// Último instante visto. Sirve de reloj "que no retrocede": si alguien
  /// atrasa la fecha del teléfono para alargar la prueba o la clave, la app
  /// sigue contando desde la fecha más alta que ya vio.
  int _vistaMs = 0;
  int _vistaGuardadaMs = 0;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    final real = DateTime.now().millisecondsSinceEpoch;
    _inicioMs = prefs.getInt(_kInicio) ?? 0;
    _venceMs = prefs.getInt(_kVence) ?? 0;
    _vistaMs = prefs.getInt(_kVista) ?? 0;
    _vistaGuardadaMs = _vistaMs;
    if (_inicioMs == 0) {
      _inicioMs = real;
      await prefs.setInt(_kInicio, real);
    }
    _tocar();
    notifyListeners();
  }

  void _tocar() {
    final real = DateTime.now().millisecondsSinceEpoch;
    if (real > _vistaMs) _vistaMs = real;
    if (_vistaMs - _vistaGuardadaMs > 60 * 1000) {
      _vistaGuardadaMs = _vistaMs;
      _prefs?.setInt(_kVista, _vistaMs);
    }
  }

  EstadoLicencia get estado {
    _tocar();
    if (_venceMs > _vistaMs) return EstadoLicencia.activa;
    if (_inicioMs + diasPrueba * _msDia > _vistaMs) {
      return EstadoLicencia.prueba;
    }
    return EstadoLicencia.vencida;
  }

  bool get puedeVender => estado != EstadoLicencia.vencida;

  /// Días que quedan de la prueba o de la clave activa (0 si está vencida).
  int get diasRestantes {
    final e = estado;
    if (e == EstadoLicencia.vencida) return 0;
    final fin = e == EstadoLicencia.activa
        ? _venceMs
        : _inicioMs + diasPrueba * _msDia;
    final ms = fin - _vistaMs;
    return ms <= 0 ? 0 : (ms / _msDia).ceil();
  }

  /// Fecha hasta la que vale la clave activada (null si nunca se activó una).
  DateTime? get venceEl =>
      _venceMs > 0 ? DateTime.fromMillisecondsSinceEpoch(_venceMs) : null;

  /// Si conviene mostrar el aviso en la pantalla de ventas.
  bool get mostrarAviso {
    final e = estado;
    if (e == EstadoLicencia.activa) return diasRestantes <= diasAviso;
    return true;
  }

  String get resumen {
    switch (estado) {
      case EstadoLicencia.prueba:
        return 'Prueba gratis: te quedan $diasRestantes '
            '${diasRestantes == 1 ? 'día' : 'días'}';
      case EstadoLicencia.activa:
        return 'Licencia activa: te quedan $diasRestantes '
            '${diasRestantes == 1 ? 'día' : 'días'}';
      case EstadoLicencia.vencida:
        return 'Licencia vencida: no se pueden hacer ventas nuevas';
    }
  }

  Future<ResultadoClave> activar(String entrada) async {
    if (_secreto.isEmpty) {
      return const ResultadoClave(
        false,
        'Esta versión de la app no tiene configurada la llave de licencias '
        '(LICENSE_SECRET).',
      );
    }
    _tocar();
    final vence = LicenciaClave.vencimientoDe(entrada, _secreto);
    if (vence == null) {
      return const ResultadoClave(false, 'Clave inválida. Revisa que esté completa.');
    }
    final venceMs = vence.millisecondsSinceEpoch;
    if (venceMs <= _vistaMs) {
      return const ResultadoClave(false, 'Esa clave ya venció. Pide una nueva.');
    }
    if (venceMs <= _venceMs) {
      return const ResultadoClave(
        false,
        'Esa clave no alarga tu licencia actual. Usa la clave más reciente.',
      );
    }
    _venceMs = venceMs;
    await _prefs?.setInt(_kVence, venceMs);
    notifyListeners();
    return ResultadoClave(
      true,
      '¡Licencia activada! Te quedan $diasRestantes días.',
    );
  }
}
