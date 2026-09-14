import '../data/cargador_tablas.dart';
import 'interpolacion.dart';
import 'interpolacion_2d.dart';

// =============================================================================
// BLOQUE 1: FUNCIONES DE TEMPERATURA Y PRESIÓN
// =============================================================================

/// Resuelve T y P juntas.
Map<String, dynamic> resolverTemperaturaYPresion(
  TablasTermo tablas,
  double T,
  double P,
) {
  // La tabla mezcla solo cubre hasta el punto crítico (~373.95°C). Si T
  // está fuera de ese rango (por arriba, o por debajo del punto triple),
  // no existe una Psat que comparar: a esas temperaturas tan altas, la
  // única región físicamente posible es vapor sobrecalentado, así que se
  // consulta directo esa tabla en vez de fallar aquí.
  Map<String, double>? filaMezcla;
  try {
    filaMezcla = buscarOInterpolar(tablas.mezcla, 'temperatura', T);
  } on FueraDeRangoException {
    filaMezcla = null;
  }

  if (filaMezcla == null) {
    var datos = buscarOInterpolar2D(
      tablas.vaporSobrecalentado,
      P,
      T,
      columnaBusqueda: 'temperatura',
    );
    datos['presion'] = P;
    return {'estado': 'Vapor Sobrecalentado', 'datos': datos};
  }

  final pSat = filaMezcla['presion']!;

  if (P > pSat) {
    // Líquido comprimido: aproximado con líquido saturado a esa T.
    final filaLiq = buscarOInterpolar(tablas.liquidoSaturado, 'temperatura', T);
    var datos = Map<String, double>.from(filaLiq);
    datos['presion'] = P;
    datos['v'] = filaLiq['vf']!;
    datos['u'] = filaLiq['uf']!;
    datos['s'] = filaLiq['sf']!;
    // Aproximación de entalpía: h = hf(T) + vf(T) * (P - Psat(T))
    datos['h'] = filaLiq['hf']! + (filaLiq['vf']! * (P - pSat));
    return {'estado': 'Líquido Comprimido', 'datos': datos};
  }

  if (P < pSat) {
    // Vapor sobrecalentado real (P y T conocidas).
    var datos = buscarOInterpolar2D(
      tablas.vaporSobrecalentado,
      P,
      T,
      columnaBusqueda: 'temperatura',
    );
    datos['presion'] = P;
    return {'estado': 'Vapor Sobrecalentado', 'datos': datos};
  }

  // P == Psat exactamente: mezcla, pero sin calidad no se puede dar un
  // punto único. Se retorna la fila completa de saturación (f...g).
  var datos = Map<String, double>.from(filaMezcla);
  return {'estado': 'Mezcla (sin calidad definida)', 'datos': datos};
}

/// Resuelve Temperatura + otra propiedad (v, u, h o s).
Map<String, dynamic> resolverPorTemperatura(
  TablasTermo tablas,
  double T,
  String prop,
  double valor,
) {
  final filaMezcla = buscarOInterpolar(tablas.mezcla, 'temperatura', T);
  final f = '${prop}f';
  final g = '${prop}g';
  final fg = '${prop}fg';

  if (valor < filaMezcla[f]!) {
    final filaLiq = buscarOInterpolar(tablas.liquidoSaturado, 'temperatura', T);
    var datos = Map<String, double>.from(filaLiq);
    datos[prop] = valor;
    datos['v'] = filaLiq['vf']!;
    datos['u'] = filaLiq['uf']!;
    datos['h'] = filaLiq['hf']!;
    datos['s'] = filaLiq['sf']!;
    return {'estado': 'Líquido Comprimido', 'datos': datos};
  }

  // Estado límite: el valor coincide EXACTAMENTE con f o g de la tabla.
  // Se compara directo contra f/g (no contra la calidad calculada vía fg),
  // porque en algunas filas de la tabla original f + fg no es exactamente
  // igual a g (pequeñas inconsistencias del Excel/Sheets original), lo que
  // haría que la calidad calculada nunca diera exactamente 0 o 1.
  if (valor == filaMezcla[f]!) {
    var datos = <String, double>{
      'temperatura': filaMezcla['temperatura']!,
      'presion': filaMezcla['presion']!,
      'v': filaMezcla['vf']!,
      'u': filaMezcla['uf']!,
      'h': filaMezcla['hf']!,
      's': filaMezcla['sf']!,
    };
    return {'estado': 'Líquido Saturado', 'datos': datos};
  }
  if (valor == filaMezcla[g]!) {
    var datos = <String, double>{
      'temperatura': filaMezcla['temperatura']!,
      'presion': filaMezcla['presion']!,
      'v': filaMezcla['vg']!,
      'u': filaMezcla['ug']!,
      'h': filaMezcla['hg']!,
      's': filaMezcla['sg']!,
    };
    return {'estado': 'Vapor Saturado', 'datos': datos};
  }

  if (valor > filaMezcla[g]!) {
    final perfil = generarPerfilATemperaturaFija(tablas.vaporSobrecalentado, T);
    final resultado = buscarOInterpolar(perfil, prop, valor);
    return {'estado': 'Vapor Sobrecalentado', 'datos': resultado};
  }

  final calidad = (valor - filaMezcla[f]!) / filaMezcla[fg]!;
  var datos = Map<String, double>.from(filaMezcla);
  datos['x'] = calidad;
  datos['v'] = filaMezcla['vf']! + calidad * filaMezcla['vfg']!;
  datos['u'] = filaMezcla['uf']! + calidad * filaMezcla['ufg']!;
  datos['h'] = filaMezcla['hf']! + calidad * filaMezcla['hfg']!;
  datos['s'] = filaMezcla['sf']! + calidad * filaMezcla['sfg']!;
  return {'estado': 'Mezcla', 'datos': datos};
}

/// Resuelve Presión + otra propiedad (v, u, h o s).
Map<String, dynamic> resolverPorPresion(
  TablasTermo tablas,
  double P,
  String prop,
  double valor,
) {
  final filaPresiones = buscarOInterpolar(tablas.presiones, 'presion', P);
  final f = '${prop}f';
  final g = '${prop}g';
  final fg = '${prop}fg';

  if (valor < filaPresiones[f]!) {
    final filaLiq = buscarOInterpolar(tablas.presionComprimida, 'presion', P);
    var datos = Map<String, double>.from(filaLiq);
    datos[prop] = valor;
    datos['v'] = filaLiq['vf']!;
    datos['u'] = filaLiq['uf']!;
    datos['h'] = filaLiq['hf']!;
    datos['s'] = filaLiq['sf']!;
    return {'estado': 'Líquido Comprimido', 'datos': datos};
  }

  // Estado límite: comparación directa contra f/g (ver nota en
  // resolverPorTemperatura sobre por qué no se usa la calidad calculada).
  if (valor == filaPresiones[f]!) {
    var datos = <String, double>{
      'temperatura': filaPresiones['temperatura']!,
      'presion': filaPresiones['presion']!,
      'v': filaPresiones['vf']!,
      'u': filaPresiones['uf']!,
      'h': filaPresiones['hf']!,
      's': filaPresiones['sf']!,
    };
    return {'estado': 'Líquido Saturado', 'datos': datos};
  }
  if (valor == filaPresiones[g]!) {
    var datos = <String, double>{
      'temperatura': filaPresiones['temperatura']!,
      'presion': filaPresiones['presion']!,
      'v': filaPresiones['vg']!,
      'u': filaPresiones['ug']!,
      'h': filaPresiones['hg']!,
      's': filaPresiones['sg']!,
    };
    return {'estado': 'Vapor Saturado', 'datos': datos};
  }

  if (valor > filaPresiones[g]!) {
    var datos = buscarOInterpolar2D(
      tablas.vaporSobrecalentado,
      P,
      valor,
      columnaBusqueda: prop,
    );
    datos['presion'] = P;
    return {'estado': 'Vapor Sobrecalentado', 'datos': datos};
  }

  final calidad = (valor - filaPresiones[f]!) / filaPresiones[fg]!;
  var datos = Map<String, double>.from(filaPresiones);
  datos['x'] = calidad;
  datos['v'] = filaPresiones['vf']! + calidad * filaPresiones['vfg']!;
  datos['u'] = filaPresiones['uf']! + calidad * filaPresiones['ufg']!;
  datos['h'] = filaPresiones['hf']! + calidad * filaPresiones['hfg']!;
  datos['s'] = filaPresiones['sf']! + calidad * filaPresiones['sfg']!;
  return {'estado': 'Mezcla', 'datos': datos};
}

// =============================================================================
// BLOQUE 2: PARES DE PROPIEDADES SIN T NI P (v+u, v+h, v+s, u+h, u+s, h+s)
// =============================================================================

/// Mapea la propiedad genérica ('v','u','h','s') a los nombres de columna
/// f/fg/g usados en las tablas 'mezcla' y 'presiones'.
Map<String, String> _getNombresFase(String prop) {
  switch (prop.toLowerCase()) {
    case 'v':
      return {'f': 'vf', 'fg': 'vfg', 'g': 'vg'};
    case 'u':
      return {'f': 'uf', 'fg': 'ufg', 'g': 'ug'};
    case 'h':
      return {'f': 'hf', 'fg': 'hfg', 'g': 'hg'};
    case 's':
      return {'f': 'sf', 'fg': 'sfg', 'g': 'sg'};
    default:
      throw Exception('Propiedad no soportada: $prop');
  }
}

/// Construye el mapa de resultado final a partir de una fila de mezcla ya
/// ubicada (exacta o interpolada), calculando la calidad con la
/// propiedad 1 y derivando el resto de propiedades con esa calidad.
Map<String, double> _construirResultadoMezcla(
  Map<String, double> filaMezcla,
  String f1,
  String fg1,
  double val1,
) {
  final calidad = (val1 - filaMezcla[f1]!) / filaMezcla[fg1]!;
  final resultado = Map<String, double>.from(filaMezcla);
  resultado['x'] = calidad;
  resultado['v'] = filaMezcla['vf']! + calidad * filaMezcla['vfg']!;
  resultado['u'] = filaMezcla['uf']! + calidad * filaMezcla['ufg']!;
  resultado['h'] = filaMezcla['hf']! + calidad * filaMezcla['hfg']!;
  resultado['s'] = filaMezcla['sf']! + calidad * filaMezcla['sfg']!;
  return resultado;
}

/// Búsqueda de raíz REAL en la tabla mezcla (sin tolerancias): para cada
/// propiedad se puede calcular una "calidad implícita" en cada fila. Se
/// busca la temperatura exacta donde ambas calidades coinciden,
/// interpolando entre filas vecinas donde la diferencia cambia de signo.
Map<String, double>? _buscarRaizEnMezcla(
  List<Map<String, double>> tablaMezcla,
  String prop1,
  double val1,
  String prop2,
  double val2,
) {
  final n1 = _getNombresFase(prop1);
  final n2 = _getNombresFase(prop2);
  final f1 = n1['f']!;
  final fg1 = n1['fg']!;
  final f2 = n2['f']!;
  final fg2 = n2['fg']!;

  final filas = List<Map<String, double>>.from(tablaMezcla)
    ..sort((a, b) => a['temperatura']!.compareTo(b['temperatura']!));

  double diferenciaCalidad(Map<String, double> fila) {
    final x1 = (val1 - fila[f1]!) / fila[fg1]!;
    final x2 = (val2 - fila[f2]!) / fila[fg2]!;
    return x1 - x2;
  }

  for (var i = 0; i < filas.length - 1; i++) {
    final d1 = diferenciaCalidad(filas[i]);
    final d2 = diferenciaCalidad(filas[i + 1]);

    if (d1 == 0) {
      return _construirResultadoMezcla(filas[i], f1, fg1, val1);
    }
    if ((d1 < 0 && d2 > 0) || (d1 > 0 && d2 < 0)) {
      final t1 = filas[i]['temperatura']!;
      final t2 = filas[i + 1]['temperatura']!;
      final tRaiz = interpolarLineal(0, d1, d2, t1, t2);
      final filaInterpolada = buscarOInterpolar(tablaMezcla, 'temperatura', tRaiz);
      return _construirResultadoMezcla(filaInterpolada, f1, fg1, val1);
    }
  }

  final dUltimo = diferenciaCalidad(filas.last);
  if (dUltimo == 0) {
    return _construirResultadoMezcla(filas.last, f1, fg1, val1);
  }

  return null; // No hay estado de mezcla consistente con estas 2 propiedades.
}

/// Búsqueda bidimensional real en vapor sobrecalentado: para cada bloque
/// de presión, interpola la propiedad 1 (obteniendo T, presion y la
/// propiedad 2 en ese punto); luego busca entre esos puntos (uno por
/// bloque) el que coincide con la propiedad 2 buscada.
Map<String, double>? _buscarEnVaporSobrecalentado(
  List<Map<String, double>> tabla,
  String prop1,
  double val1,
  String prop2,
  double val2,
) {
  if (tabla.isEmpty) return null;

  final Map<double, List<Map<String, double>>> bloques = {};
  for (final fila in tabla) {
    final p = fila['presion'];
    if (p == null) continue;
    bloques.putIfAbsent(p, () => []).add(fila);
  }

  final List<Map<String, double>> perfilSintetico = [];
  for (final bloque in bloques.values) {
    try {
      final filaInterpolada = buscarOInterpolar(bloque, prop1, val1);
      perfilSintetico.add(filaInterpolada);
    } on FueraDeRangoException {
      continue; // val1 no existe en esta presión; se ignora el bloque.
    }
  }

  if (perfilSintetico.isEmpty) return null;

  try {
    return buscarOInterpolar(perfilSintetico, prop2, val2);
  } on FueraDeRangoException {
    return null;
  }
}

/// Aproxima líquido comprimido usando la propiedad 1 como clave principal
/// sobre la tabla 'presionComprimida' (que tiene una sola fila por
/// presión, a diferencia de vapor sobrecalentado). La propiedad 2 no se
/// fuerza a coincidir exactamente: es una limitación conocida de esta
/// aproximación (el líquido comprimido real depende de T y P, pero aquí
/// solo tenemos su valor a lo largo de la curva de saturación).
Map<String, double>? _aproximarLiquidoComprimido(
  TablasTermo tablas,
  String prop1,
  double val1,
) {
  final n1 = _getNombresFase(prop1);
  try {
    final fila = buscarOInterpolar(tablas.presionComprimida, n1['f']!, val1);
    final resultado = Map<String, double>.from(fila);
    resultado['v'] = fila['vf']!;
    resultado['u'] = fila['uf']!;
    resultado['h'] = fila['hf']!;
    resultado['s'] = fila['sf']!;
    return resultado;
  } on FueraDeRangoException {
    return null;
  }
}

/// Enrutador genérico para las 6 combinaciones sin T ni P.
Map<String, dynamic> _resolverEstadoPorDosPropiedades(
  TablasTermo tablas,
  String prop1,
  double val1,
  String prop2,
  double val2,
) {
  // 1. Intentar en mezcla (búsqueda de raíz real, sin tolerancias).
  final resMezcla = _buscarRaizEnMezcla(tablas.mezcla, prop1, val1, prop2, val2);
  if (resMezcla != null) {
    final calidad = resMezcla['x']!;
    // Estados límite: calidad exactamente 0 o 1 -> no es "mezcla" real.
    if (calidad == 0.0) {
      return {
        'estado': 'Líquido Saturado',
        'datos': {
          'temperatura': resMezcla['temperatura']!,
          'presion': resMezcla['presion']!,
          'v': resMezcla['vf']!,
          'u': resMezcla['uf']!,
          'h': resMezcla['hf']!,
          's': resMezcla['sf']!,
        },
      };
    }
    if (calidad == 1.0) {
      return {
        'estado': 'Vapor Saturado',
        'datos': {
          'temperatura': resMezcla['temperatura']!,
          'presion': resMezcla['presion']!,
          'v': resMezcla['vg']!,
          'u': resMezcla['ug']!,
          'h': resMezcla['hg']!,
          's': resMezcla['sg']!,
        },
      };
    }
    return {'estado': 'Mezcla', 'datos': resMezcla};
  }

  // 2. Intentar en vapor sobrecalentado (datos reales de 2 variables).
  final resSobrecalentado = _buscarEnVaporSobrecalentado(
    tablas.vaporSobrecalentado,
    prop1,
    val1,
    prop2,
    val2,
  );
  if (resSobrecalentado != null) {
    return {'estado': 'Vapor Sobrecalentado', 'datos': resSobrecalentado};
  }

  // 3. Aproximar líquido comprimido usando la propiedad 1 como referencia.
  final resComprimido = _aproximarLiquidoComprimido(tablas, prop1, val1);
  if (resComprimido != null) {
    return {'estado': 'Líquido Comprimido', 'datos': resComprimido};
  }

  throw Exception(
    'La combinación $prop1=$val1 y $prop2=$val2 no corresponde a ningún '
    'estado consistente en las tablas.',
  );
}

Map<String, dynamic> resolverVolumenEnergiaInterna(
    TablasTermo tablas, double v, double u) {
  return _resolverEstadoPorDosPropiedades(tablas, 'v', v, 'u', u);
}

Map<String, dynamic> resolverVolumenEntalpia(
    TablasTermo tablas, double v, double h) {
  return _resolverEstadoPorDosPropiedades(tablas, 'v', v, 'h', h);
}

Map<String, dynamic> resolverVolumenEntropia(
    TablasTermo tablas, double v, double s) {
  return _resolverEstadoPorDosPropiedades(tablas, 'v', v, 's', s);
}

Map<String, dynamic> resolverEnergiaInternaEntalpia(
    TablasTermo tablas, double u, double h) {
  return _resolverEstadoPorDosPropiedades(tablas, 'u', u, 'h', h);
}

Map<String, dynamic> resolverEnergiaInternaEntropia(
    TablasTermo tablas, double u, double s) {
  return _resolverEstadoPorDosPropiedades(tablas, 'u', u, 's', s);
}

Map<String, dynamic> resolverEntalpiaEntropia(
    TablasTermo tablas, double h, double s) {
  return _resolverEstadoPorDosPropiedades(tablas, 'h', h, 's', s);
}

// =============================================================================
// BLOQUE 3: ESTADO ESPECÍFICO + PROPIEDAD CONOCIDA
// =============================================================================

/// Resuelve propiedades cuando el estado es LÍQUIDO SATURADO.
Map<String, double> resolverLiquidoSaturado(
    TablasTermo tablas, String propiedad, double valor) {
  final propLower = propiedad.toLowerCase();

  if (propLower == 't' || propLower == 'p') {
    final colClave = propLower == 't' ? 'temperatura' : 'presion';
    return buscarOInterpolar(tablas.liquidoSaturado, colClave, valor);
  }

  String colTabla;
  switch (propLower) {
    case 'v':
      colTabla = 'vf';
      break;
    case 'u':
      colTabla = 'uf';
      break;
    case 'h':
      colTabla = 'hf';
      break;
    case 's':
      colTabla = 'sf';
      break;
    default:
      throw Exception("Propiedad '$propiedad' no válida para Líquido Saturado.");
  }
  return buscarOInterpolar(tablas.liquidoSaturado, colTabla, valor);
}

/// Resuelve propiedades cuando el estado es VAPOR SATURADO.
/// (Corregido: las columnas están en minúsculas, 'vg'/'ug'/'hg'/'sg',
/// no 'Vg'/'Ug' como en la versión anterior — por eso fallaba.)
Map<String, double> resolverVaporSaturado(
    TablasTermo tablas, String propiedad, double valor) {
  final propLower = propiedad.toLowerCase();

  if (propLower == 't' || propLower == 'p') {
    final colClave = propLower == 't' ? 'temperatura' : 'presion';
    return buscarOInterpolar(tablas.vaporSaturado, colClave, valor);
  }

  String colTabla;
  switch (propLower) {
    case 'v':
      colTabla = 'vg';
      break;
    case 'u':
      colTabla = 'ug';
      break;
    case 'h':
      colTabla = 'hg';
      break;
    case 's':
      colTabla = 'sg';
      break;
    default:
      throw Exception("Propiedad '$propiedad' no válida para Vapor Saturado.");
  }
  return buscarOInterpolar(tablas.vaporSaturado, colTabla, valor);
}

/// Resuelve propiedades cuando el estado es MEZCLA y se conoce la calidad (x).
Map<String, double> resolverMezclaConCalidad(
  TablasTermo tablas,
  String variableCorte,
  double valorCorte,
  double x,
) {
  if (x < 0.0 || x > 1.0) {
    throw Exception('La calidad (x) debe estar entre 0 y 1.');
  }
  final varLower = variableCorte.toLowerCase();
  if (varLower != 't' && varLower != 'p') {
    throw Exception('Para resolver mezcla necesitas ingresar T o P.');
  }

  final colClave = varLower == 't' ? 'temperatura' : 'presion';
  final filaMezcla = buscarOInterpolar(tablas.mezcla, colClave, valorCorte);
  final resultado = Map<String, double>.from(filaMezcla);
  resultado['x'] = x;
  resultado['v'] = filaMezcla['vf']! + (x * filaMezcla['vfg']!);
  resultado['u'] = filaMezcla['uf']! + (x * filaMezcla['ufg']!);
  resultado['h'] = filaMezcla['hf']! + (x * filaMezcla['hfg']!);
  resultado['s'] = filaMezcla['sf']! + (x * filaMezcla['sfg']!);
  return resultado;
}

/// Aproxima líquido comprimido con las tablas de líquido saturado a la T dada.
Map<String, double> resolverLiquidoComprimidoAproximado(
    TablasTermo tablas, double T) {
  final fila = buscarOInterpolar(tablas.liquidoSaturado, 'temperatura', T);
  final resultado = Map<String, double>.from(fila);
  resultado['v'] = fila['vf']!;
  resultado['u'] = fila['uf']!;
  resultado['h'] = fila['hf']!;
  resultado['s'] = fila['sf']!;
  return resultado;
}

// =============================================================================
// BLOQUE 4: APARTADO "INTERPOLACIÓN" — muestra la fila COMPLETA de la tabla
// mezcla (todas las columnas f, fg, g) para cualquier propiedad usada como
// clave de búsqueda.
// =============================================================================

/// Ubica (o interpola) la fila de saturación completa en la tabla mezcla,
/// usando cualquier propiedad como clave de búsqueda.
///
/// [propiedad] es uno de: 't', 'p', 'v', 'u', 'h', 's'.
/// [convencion] solo aplica cuando [propiedad] es v/u/h/s (no t ni p):
/// 'f' busca por la columna de líquido saturado (ej. 'vf'), 'g' busca por
/// la columna de vapor saturado (ej. 'vg'). Para t o p este parámetro se
/// ignora, ya que esas columnas no tienen variante f/g.
///
/// El resultado incluye TODAS las columnas de la fila (temperatura,
/// presion, vf, vfg, vg, uf, ufg, ug, hf, hfg, hg, sf, sfg, sg), sin
/// tolerancias: interpola exacto entre las dos filas vecinas si el valor
/// no existe exacto en la tabla.
Map<String, double> resolverInterpolacionMezcla(
  TablasTermo tablas,
  String propiedad,
  double valor, {
  String convencion = 'f',
}) {
  String columnaClave;
  switch (propiedad) {
    case 't':
      columnaClave = 'temperatura';
      break;
    case 'p':
      columnaClave = 'presion';
      break;
    case 'v':
    case 'u':
    case 'h':
    case 's':
      if (convencion != 'f' && convencion != 'g') {
        throw ArgumentError("convencion debe ser 'f' o 'g', recibido: $convencion");
      }
      columnaClave = '$propiedad$convencion';
      break;
    default:
      throw ArgumentError('Propiedad no soportada: $propiedad');
  }
  return buscarOInterpolar(tablas.mezcla, columnaClave, valor);
}