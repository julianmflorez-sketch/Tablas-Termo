/// Funciones genéricas de búsqueda e interpolación lineal en tablas
/// termodinámicas. Estas 3 funciones reemplazan lo que en el MATLAB original
/// eran decenas de bloques de código repetido (uno por cada combinación de
/// propiedades). Aquí se escriben una sola vez y se reutilizan para las 6
/// tablas de una sola entrada (todas menos vapor sobrecalentado).
library;

/// Busca una fila donde tabla[i][columnaClave] == valorBuscado exactamente.
/// Retorna null si no existe ninguna fila con ese valor exacto.
Map<String, double>? buscarExacto(
  List<Map<String, double>> tabla,
  String columnaClave,
  double valorBuscado,
) {
  for (final fila in tabla) {
    if (fila[columnaClave] == valorBuscado) {
      return fila;
    }
  }
  return null;
}

/// Interpolación lineal simple entre dos puntos:
/// y = y1 + (y3 - y1) * (x - x1) / (x3 - x1)
double interpolarLineal(double x, double x1, double x3, double y1, double y3) {
  if (x3 == x1) {
    // Evita división por cero si por error los dos puntos son iguales.
    return y1;
  }
  return y1 + (y3 - y1) * (x - x1) / (x3 - x1);
}

/// Excepción lanzada cuando el valor buscado está fuera del rango de la
/// tabla (menor que el mínimo o mayor que el máximo). Al no usar
/// tolerancias, esto es lo que ocurre si el usuario pide un valor que las
/// tablas no cubren.
class FueraDeRangoException implements Exception {
  final String mensaje;
  FueraDeRangoException(this.mensaje);

  @override
  String toString() => mensaje;
}

/// Busca la fila exacta según [columnaClave]; si no existe, busca la fila
/// inmediatamente menor y la inmediatamente mayor (asumiendo que la tabla
/// está ordenada de forma ascendente por [columnaClave]) e interpola TODAS
/// las columnas numéricas automáticamente.
///
/// Lanza [FueraDeRangoException] si [valorBuscado] está fuera del rango
/// cubierto por la tabla (no se usan tolerancias, según lo definido).
Map<String, double> buscarOInterpolar(
  List<Map<String, double>> tabla,
  String columnaClave,
  double valorBuscado,
) {
  // 1. Intentar fila exacta primero.
  final exacta = buscarExacto(tabla, columnaClave, valorBuscado);
  if (exacta != null) {
    return exacta;
  }

  // 2. Buscar el vecino inmediatamente menor y el inmediatamente mayor.
  Map<String, double>? filaMenor;
  Map<String, double>? filaMayor;

  for (final fila in tabla) {
    final valorFila = fila[columnaClave];
    if (valorFila == null) continue;

    if (valorFila < valorBuscado) {
      if (filaMenor == null || valorFila > filaMenor[columnaClave]!) {
        filaMenor = fila;
      }
    } else if (valorFila > valorBuscado) {
      if (filaMayor == null || valorFila < filaMayor[columnaClave]!) {
        filaMayor = fila;
      }
    }
  }

  if (filaMenor == null || filaMayor == null) {
    throw FueraDeRangoException(
      'El valor $valorBuscado para "$columnaClave" está fuera del rango '
      'cubierto por esta tabla. No se realizan extrapolaciones.',
    );
  }

  // 3. Interpolar cada columna numérica presente en ambas filas vecinas.
  final x = valorBuscado;
  final x1 = filaMenor[columnaClave]!;
  final x3 = filaMayor[columnaClave]!;

  final Map<String, double> resultado = {};
  for (final nombreColumna in filaMenor.keys) {
    if (!filaMayor.containsKey(nombreColumna)) continue;
    final y1 = filaMenor[nombreColumna]!;
    final y3 = filaMayor[nombreColumna]!;
    resultado[nombreColumna] = interpolarLineal(x, x1, x3, y1, y3);
  }

  // Aseguramos que la columna clave quede exactamente con el valor buscado
  // (evita pequeños errores de redondeo de la interpolación sobre sí misma).
  resultado[columnaClave] = valorBuscado;

  return resultado;
}