import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../config/app_config.dart';
import '../services/license_service.dart';
import '../theme/app_theme.dart';
import '../utils/soporte_config.dart';

/// Pantalla para ver el estado de la licencia e ingresar la clave mensual.
class LicenciaScreen extends StatefulWidget {
  const LicenciaScreen({super.key});

  @override
  State<LicenciaScreen> createState() => _LicenciaScreenState();
}

class _LicenciaScreenState extends State<LicenciaScreen> {
  final _claveCtrl = TextEditingController();
  bool _activando = false;
  String? _mensaje;
  bool _mensajeOk = false;

  @override
  void dispose() {
    _claveCtrl.dispose();
    super.dispose();
  }

  Future<void> _activar() async {
    final texto = _claveCtrl.text.trim();
    if (texto.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _activando = true;
      _mensaje = null;
    });
    final r = await LicenseService.instance.activar(texto);
    if (!mounted) return;
    setState(() {
      _activando = false;
      _mensaje = r.mensaje;
      _mensajeOk = r.ok;
      if (r.ok) _claveCtrl.clear();
    });
  }

  Future<void> _pegar() async {
    final data = await Clipboard.getData('text/plain');
    final texto = data?.text?.trim();
    if (texto != null && texto.isNotEmpty) {
      _claveCtrl.text = texto;
    }
  }

  Future<void> _pedirClave() async {
    final ok = await SoporteConfig.abrirWhatsApp(
      mensaje: 'Hola, quiero renovar mi licencia de ${AppConfig.nombre}',
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir WhatsApp'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Licencia')),
      body: ListenableBuilder(
        listenable: LicenseService.instance,
        builder: (context, _) {
          final lic = LicenseService.instance;
          final estado = lic.estado;
          final color = switch (estado) {
            EstadoLicencia.activa => AppTheme.success,
            EstadoLicencia.prueba => AppTheme.primary,
            EstadoLicencia.vencida => AppTheme.error,
          };
          final icono = switch (estado) {
            EstadoLicencia.activa => Icons.verified_rounded,
            EstadoLicencia.prueba => Icons.hourglass_bottom_rounded,
            EstadoLicencia.vencida => Icons.lock_outline_rounded,
          };
          final vence = lic.venceEl;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    Icon(icono, color: color, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lic.resumen,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                          if (vence != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Última clave válida hasta el '
                              '${DateFormat('dd/MM/yyyy').format(vence)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Ingresar clave',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _claveCtrl,
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                enableSuggestions: false,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\- ]')),
                  LengthLimitingTextInputFormatter(24),
                ],
                decoration: InputDecoration(
                  hintText: 'VM-000000-XXXXXXXX',
                  prefixIcon: const Icon(Icons.key_rounded),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.content_paste_rounded),
                    tooltip: 'Pegar',
                    onPressed: _pegar,
                  ),
                ),
                onSubmitted: (_) => _activar(),
              ),
              if (_mensaje != null) ...[
                const SizedBox(height: 10),
                Text(
                  _mensaje!,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _mensajeOk ? AppTheme.success : AppTheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _activando ? null : _activar,
                  icon: _activando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline_rounded),
                  label: const Text('Activar'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _pedirClave,
                  icon: const Icon(Icons.chat_rounded),
                  label: const Text('Pedir mi clave por WhatsApp'),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Cuando la licencia vence puedes seguir viendo el historial y '
                'exportar tus ventas, pero no hacer ventas nuevas hasta '
                'ingresar la clave del mes.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Franja de aviso para la pantalla de ventas (prueba, por vencer o vencida).
class LicenciaBanner extends StatelessWidget {
  const LicenciaBanner({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LicenseService.instance,
      builder: (context, _) {
        final lic = LicenseService.instance;
        if (!lic.mostrarAviso) return const SizedBox.shrink();
        final vencida = lic.estado == EstadoLicencia.vencida;
        return Material(
          color: vencida ? AppTheme.error : AppTheme.primary,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    vencida ? Icons.lock_outline_rounded : Icons.key_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      lic.resumen,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Aviso cuando alguien intenta vender con la licencia vencida.
Future<void> mostrarLicenciaVencida(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Licencia vencida'),
      content: const Text(
        'Tu licencia venció, por eso no se pueden hacer ventas nuevas.\n\n'
        'Sigues pudiendo ver el historial y exportar tus ventas. Ingresa la '
        'clave del mes para continuar vendiendo.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cerrar'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(ctx);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LicenciaScreen()),
            );
          },
          child: const Text('Ingresar clave'),
        ),
      ],
    ),
  );
}
