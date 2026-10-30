import 'package:flutter/widgets.dart';

/// Tamaño en píxeles reales con el que conviene decodificar una imagen.
///
/// Sin esto Flutter decodifica las fotos a su resolución original (una foto
/// de cámara de 12 MP ocupa ~48 MB en memoria) aunque se dibujen en 88 dp. Se
/// pasa el resultado a `cacheWidth` / `memCacheWidth`; Play Console lo pide
/// como "reducción de muestreo de mapas de bits".
///
/// Solo se fija el ancho: el alto sale de la proporción de la imagen, así no
/// se deforma.
int pixelesPara(BuildContext context, double logicos) =>
    (logicos * MediaQuery.devicePixelRatioOf(context)).round();

/// Ancho de la pantalla en píxeles reales, para imágenes a todo lo ancho.
int anchoPantallaPx(BuildContext context) =>
    pixelesPara(context, MediaQuery.sizeOf(context).width);
