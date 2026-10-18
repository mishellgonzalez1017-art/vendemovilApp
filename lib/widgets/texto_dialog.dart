import 'package:flutter/material.dart';

/// Pide un texto corto (nombre de categoría, de vendedor...).
/// El mensaje de error solo aparece después de intentar guardar vacío.
Future<String?> pedirTexto(
  BuildContext context, {
  required String titulo,
  required String hint,
  String accion = 'Agregar',
  String errorVacio = 'Escribe un nombre',
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _TextoDialog(
      titulo: titulo,
      hint: hint,
      accion: accion,
      errorVacio: errorVacio,
    ),
  );
}

class _TextoDialog extends StatefulWidget {
  const _TextoDialog({
    required this.titulo,
    required this.hint,
    required this.accion,
    required this.errorVacio,
  });

  final String titulo;
  final String hint;
  final String accion;
  final String errorVacio;

  @override
  State<_TextoDialog> createState() => _TextoDialogState();
}

class _TextoDialogState extends State<_TextoDialog> {
  final _ctrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _aceptar() {
    final texto = _ctrl.text.trim();
    if (texto.isEmpty) {
      setState(() => _error = widget.errorVacio);
      return;
    }
    Navigator.pop(context, texto);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titulo),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        onSubmitted: (_) => _aceptar(),
        decoration: InputDecoration(hintText: widget.hint, errorText: _error),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(onPressed: _aceptar, child: Text(widget.accion)),
      ],
    );
  }
}
