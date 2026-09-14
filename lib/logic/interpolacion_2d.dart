import 'interpolacion.dart';

/// Genera una tabla sintética "de un solo corte": para una temperatura fija
/// dada, recorre todos los bloques de presión de la tabla de vapor
/// sobrecalentado y, dentro de cada uno, interpola (o toma exacta) por
/// temperatura. El resultado es una tabla temporal de {presion, v, u, h, s}
/// SOLO para esa temperatura, ordenada por presión.
///
/// Esto permite reutilizar [buscarOInterpolar] usando 'v', 'u', 'h' o 's'
/// como columna clave para hacer búsquedas "inversas" (ej. conocer T y v,
/// y necesitar encontrar la presión correspondiente), sin escribir un
/// algoritmo de interpolación distinto para cada dirección.
///
/// Los bloques de presión que no cubren esa temperatura (porque a esa
/// presión el agua aún no llega a vapor sobrecalentado) se omiten
/// silenciosamente, ya que no hay dato válido que aportar en ese punto.
List<Map<String, double>> generarPerfilATemperaturaFija(
  List<Map<String, double>> tabla,
  double temperaturaFija, {
  String columnaPresion = 'presion',
  String columnaTemperatura = 'temperatura',
}) {
  final Map<double, List<Map<String, double>>> bloques = {};
  for (final fila in tabla) {
    final p = fila[columnaPresion];
    if (p == null) continue;
    bloques.putIfAbsent(p, () => []).add(fila);
  }

  final List<Map<String, double>> perfil = [];
  for (final entrada in bloques.entries) {
    try {
      final filaInterpolada = buscarOInterpolar(
        entrada.value,
        columnaTemperatura,
        temperaturaFija,
      );
      final filaConPresion = Map<String, double>.from(filaInterpolada);
      filaConPresion[columnaPresion] = entrada.key;
      perfil.add(filaConPresion);
    } on FueraDeRangoException {
      // Esta presión no cubre la temperatura pedida (aún no es vapor
      // sobrecalentado a esa presión); se omite este punto.
      continue;
    }
  }

  perfil.sort((a, b) => a[columnaPresion]!.compareTo(b[columnaPresion]!));
  return perfil;
}

/// Interpolación bilineal para la tabla de vapor sobrecalentado, que es la
/// única de las 7 tablas con doble entrada (depende de presión Y de otra
/// propiedad al mismo tiempo, agrupada en bloques por presión).
///
/// [columnaBusqueda] indica qué columna se usa como clave DENTRO de cada
/// bloque de presión: normalmente 'temperatura' (cuando se conocen P y T),
/// pero también puede ser 'v', 'u', 'h' o 's' para resolver el caso
/// contrario: se conoce P y una propiedad (ej. volumen), y se necesita
/// encontrar la temperatura correspondiente (y el resto de propiedades).
/// La función es la misma en ambos sentidos porque busca de forma genérica.
///
/// Lógica (igual a la que se usaba en MATLAB):
/// 1. Si la presión buscada existe exacta como bloque, solo se resuelve
///    [columnaBusqueda] dentro de ese bloque.
/// 2. Si no, se toman el bloque de presión inmediatamente menor y el
///    inmediatamente mayor. En CADA uno se resuelve por [columnaBusqueda].
/// 3. Los dos resultados (uno por bloque) se interpolan entre sí según la
///    presión, columna por columna (incluida la temperatura, que queda
///    interpolada automáticamente si no era la columna de búsqueda).
///
/// No se usan tolerancias: si la presión o el valor buscado está fuera del
/// rango cubierto por las tablas, se lanza [FueraDeRangoException].
Map<String, double> buscarOInterpolar2D(
  List<Map<String, double>> tabla,
  double presionBuscada,
  double valorBuscado, {
  String columnaPresion = 'presion',
  String columnaBusqueda = 'temperatura',
}) {
  // 1. Agrupar las filas de la tabla en bloques según su presión.
  final Map<double, List<Map<String, double>>> bloques = {};
  for (final fila in tabla) {
    final p = fila[columnaPresion];
    if (p == null) continue;
    bloques.putIfAbsent(p, () => []).add(fila);
  }

  // 2. Si la presión buscada coincide exacta con un bloque, resolvemos
  //    solo por columnaBusqueda dentro de ese bloque (reutiliza la
  //    función 1D).
  if (bloques.containsKey(presionBuscada)) {
    return buscarOInterpolar(
      bloques[presionBuscada]!,
      columnaBusqueda,
      valorBuscado,
    );
  }

  // 3. Buscar el bloque de presión inmediatamente menor y el inmediatamente
  //    mayor a la presión buscada.
  double? presionMenor;
  double? presionMayor;

  for (final p in bloques.keys) {
    if (p < presionBuscada) {
      if (presionMenor == null || p > presionMenor) presionMenor = p;
    } else if (p > presionBuscada) {
      if (presionMayor == null || p < presionMayor) presionMayor = p;
    }
  }

  if (presionMenor == null || presionMayor == null) {
    throw FueraDeRangoException(
      'La presión $presionBuscada está fuera del rango cubierto por la '
      'tabla de vapor sobrecalentado. No se realizan extrapolaciones.',
    );
  }

  // 4. Dentro de cada bloque vecino, resolver por columnaBusqueda. Esto
  //    puede lanzar FueraDeRangoException si el valor buscado no está
  //    cubierto en ese bloque de presión (por ejemplo, pedir T=101°C a
  //    P=1200 kPa, que en fase vapor sobrecalentado solo empieza después
  //    de la temperatura de saturación).
  final resultadoMenor = buscarOInterpolar(
    bloques[presionMenor]!,
    columnaBusqueda,
    valorBuscado,
  );
  final resultadoMayor = buscarOInterpolar(
    bloques[presionMayor]!,
    columnaBusqueda,
    valorBuscado,
  );

  // 5. Interpolar los dos resultados (uno por bloque) según la presión.
  final x = presionBuscada;
  final x1 = presionMenor;
  final x3 = presionMayor;

  final Map<String, double> resultado = {};
  for (final columna in resultadoMenor.keys) {
    if (!resultadoMayor.containsKey(columna)) continue;
    final y1 = resultadoMenor[columna]!;
    final y3 = resultadoMayor[columna]!;
    resultado[columna] = interpolarLineal(x, x1, x3, y1, y3);
  }

  // Fijamos las columnas clave exactamente en los valores buscados,
  // evitando pequeños errores de redondeo de la doble interpolación.
  resultado[columnaPresion] = presionBuscada;
  resultado[columnaBusqueda] = valorBuscado;

  return resultado;
}