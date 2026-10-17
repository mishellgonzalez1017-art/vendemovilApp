import 'dart:io';
import 'package:flutter/widgets.dart';

/// Foto de producto cargada en tamaño reducido.
///
/// Las fotos de la cámara pesan varios megas. Si se cargan completas para
/// mostrar una miniatura, la app gasta mucha memoria y se traba al desplazar
/// listas. Con esto Flutter decodifica la imagen directamente al tamaño que
/// se necesita ([ancho] está en píxeles físicos, no en puntos lógicos).
ImageProvider fotoProducto(String ruta, {int ancho = 300}) =>
    ResizeImage(FileImage(File(ruta)), width: ancho);
