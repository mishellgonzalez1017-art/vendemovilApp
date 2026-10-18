import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Tarjeta blanca con borde redondeado, el contenedor básico de Ajustes.
class BloqueAjuste extends StatelessWidget {
  const BloqueAjuste({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppTheme.bgWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: child,
    );
  }
}

/// Cuadro con ícono de color, como los de la cabecera de cada ajuste.
class IconoAjuste extends StatelessWidget {
  const IconoAjuste({
    super.key,
    required this.icono,
    this.color = AppTheme.primary,
    this.tamano = 44,
  });

  final IconData icono;
  final Color color;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icono, color: color, size: tamano * 0.5),
    );
  }
}

/// Tarjeta de la cuadrícula de Ajustes. Mide lo que necesita su contenido,
/// por eso no se desborda aunque el teléfono tenga la letra grande.
class TarjetaAjuste extends StatelessWidget {
  const TarjetaAjuste({
    super.key,
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    required this.onTap,
    this.color = AppTheme.primary,
  });

  final IconData icono;
  final String titulo;
  final String subtitulo;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.bgWhite,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              IconoAjuste(icono: icono, color: color, tamano: 40),
              const SizedBox(height: 12),
              Text(
                titulo,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 2),
              Text(
                subtitulo,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Acomoda las tarjetas de dos en dos con la misma altura en cada fila.
class FilasDeTarjetas extends StatelessWidget {
  const FilasDeTarjetas({super.key, required this.tarjetas});

  final List<Widget> tarjetas;

  @override
  Widget build(BuildContext context) {
    final filas = <Widget>[];
    for (var i = 0; i < tarjetas.length; i += 2) {
      final segunda = i + 1 < tarjetas.length ? tarjetas[i + 1] : null;
      filas.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: tarjetas[i]),
                const SizedBox(width: 12),
                Expanded(child: segunda ?? const SizedBox.shrink()),
              ],
            ),
          ),
        ),
      );
    }
    return Column(children: filas);
  }
}

/// Encabezado de una pantalla de ajuste: ícono, título y explicación.
class EncabezadoAjuste extends StatelessWidget {
  const EncabezadoAjuste({
    super.key,
    required this.icono,
    required this.titulo,
    required this.descripcion,
    this.color = AppTheme.primary,
  });

  final IconData icono;
  final String titulo;
  final String descripcion;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return BloqueAjuste(
      child: Row(
        children: [
          IconoAjuste(icono: icono, color: color),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
                const SizedBox(height: 2),
                Text(
                  descripcion,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
