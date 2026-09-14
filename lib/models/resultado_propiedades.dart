/// Representa el resultado de una consulta de propiedades termodinámicas:
/// los valores calculados/interpolados y en qué región se encontró la
/// sustancia (líquido comprimido, mezcla, o vapor sobrecalentado).
class ResultadoPropiedades {
  final double? temperatura;
  final double? presion;
  final double? v; // volumen específico
  final double? u; // energía interna
  final double? h; // entalpía
  final double? s; // entropía
  final String region; // 'liquido_comprimido' | 'mezcla' | 'vapor_sobrecalentado'

  /// Si region == 'mezcla', aquí queda la fila completa de la tabla mezcla
  /// (con los pares f/g: vf, vg, uf, ug, hf, hg, sf, sg...), por si se
  /// necesita mostrar el rango completo de saturación en la interfaz.
  final Map<String, double>? datosMezclaCompletos;

  ResultadoPropiedades({
    this.temperatura,
    this.presion,
    this.v,
    this.u,
    this.h,
    this.s,
    required this.region,
    this.datosMezclaCompletos,
  });

  @override
  String toString() {
    return 'ResultadoPropiedades(T: $temperatura, P: $presion, v: $v, '
        'u: $u, h: $h, s: $s, region: $region)';
  }
}