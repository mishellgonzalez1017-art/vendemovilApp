import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Métodos de pago del POS (etiquetas, iconos y preferencias).
class MetodosPagoConfig {
  static const todos = ['efectivo', 'yape', 'plin', 'tarjeta'];
  static const prefsKey = 'metodos_pago_habilitados';

  static const labels = {
    'efectivo': 'Efectivo',
    'yape': 'Transferencia',
    'plin': 'Tigo Money',
    'tarjeta': 'Tarjeta',
  };

  static const icons = {
    'efectivo': Icons.money_rounded,
    'yape': Icons.account_balance_rounded,
    'plin': Icons.phone_android_rounded,
    'tarjeta': Icons.credit_card_rounded,
  };

  static const colors = {
    'efectivo': AppTheme.success,
    'yape': Color(0xFF1565C0),
    'plin': Color(0xFF0D47A1),
    'tarjeta': AppTheme.info,
  };

  static bool soportaQr(String metodo) => metodo == 'yape' || metodo == 'plin';

  static String label(String metodo) => labels[metodo] ?? metodo;
}
