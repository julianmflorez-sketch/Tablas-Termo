import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';

/// Carga un CSV desde los assets de la app y lo convierte en una lista de
/// mapas, usando la primera fila como nombres de columna (normalizados a
/// minúsculas). Ignora columnas sin nombre (como las 2 columnas vacías al
/// final de la tabla de vapor sobrecalentado) y filas vacías.
Future<List<Map<String, double>>> cargarTabla(String nombreArchivo) async {
  final contenido = await rootBundle.loadString('assets/datos/$nombreArchivo');

  // La clase Csv (API de la versión 8 del paquete) detecta automáticamente
  // el separador de línea (\r\n o \n), no hace falta normalizarlo a mano.
  final decodificador = Csv();
  final filas = decodificador.decode(contenido);

  if (filas.isEmpty) {
    throw Exception('El archivo $nombreArchivo está vacío o no se pudo leer.');
  }

  final encabezados = filas[0]
      .map((celda) => celda.toString().trim().toLowerCase())
      .toList();

  final List<Map<String, double>> tabla = [];

  for (var i = 1; i < filas.length; i++) {
    final fila = filas[i];

    // Ignorar filas completamente vacías.
    if (fila.isEmpty || fila.every((c) => c.toString().trim().isEmpty)) {
      continue;
    }

    final Map<String, double> mapa = {};
    for (var j = 0; j < encabezados.length; j++) {
      final nombreColumna = encabezados[j];

      // Ignorar columnas sin nombre (las vacías al final de algunas tablas).
      if (nombreColumna.isEmpty) continue;
      if (j >= fila.length) continue;

      final valor = double.tryParse(fila[j].toString().trim());
      if (valor != null) {
        mapa[nombreColumna] = valor;
      }
    }

    if (mapa.isNotEmpty) {
      tabla.add(mapa);
    }
  }

  return tabla;
}

/// Contenedor central de las 7 tablas termodinámicas, ya cargadas en memoria.
/// Se llena una sola vez al iniciar la app con [cargarTodasLasTablas()].
class TablasTermo {
  late List<Map<String, double>> liquidoSaturado;
  late List<Map<String, double>> vaporSaturado;
  late List<Map<String, double>> mezcla;
  late List<Map<String, double>> presionComprimida;
  late List<Map<String, double>> presionVaporSaturado;
  late List<Map<String, double>> presiones;
  late List<Map<String, double>> vaporSobrecalentado;

  Future<void> cargarTodas() async {
    liquidoSaturado = await cargarTabla('liquido_saturado.csv');
    vaporSaturado = await cargarTabla('vapor_saturado.csv');
    mezcla = await cargarTabla('mezcla.csv');
    presionComprimida = await cargarTabla('presion_comprimida.csv');
    presionVaporSaturado = await cargarTabla('presion_vapor_saturado.csv');
    presiones = await cargarTabla('presiones.csv');
    vaporSobrecalentado = await cargarTabla('vapor_sobrecalentado.csv');
  }
}