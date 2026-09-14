import 'package:flutter/material.dart';
import 'data/cargador_tablas.dart';
import 'logic/motor_termo.dart';

void main() {
  runApp(const TermoApp());
}

class TermoApp extends StatelessWidget {
  const TermoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tablas Termo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
        ),
      ),
      home: const PantallaPrincipal(),
    );
  }
}

class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({super.key});

  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  final TablasTermo misTablas = TablasTermo();
  bool isLoading = true;

  // Controla si se ve el desglose completo (f/fg/g) en Mezcla, o solo el
  // resumen (v, u, h, s), igual que en las demás fases.
  bool _mostrarDesgloseCompleto = false;

  // Controla qué pantalla se muestra: '2prop' | 'estado' | 'interpolacion'.
  String _modo = '2prop';

  // Variables para el Modo "2 Propiedades"
  String seleccion1 = 'Temperatura °C';
  String seleccion2 = 'Presión kPa';
  final TextEditingController controlValor1 = TextEditingController();
  final TextEditingController controlValor2 = TextEditingController();

  // Variables para el Modo "Estado Conocido"
  String estadoSeleccionado = 'Mezcla';
  String propEstado = 'Temperatura °C';
  final TextEditingController controlValorEstado = TextEditingController();
  final TextEditingController controlCalidad = TextEditingController();

  final List<String> opcionesPropiedades = [
    'Temperatura °C',
    'Presión kPa',
    'Volumen específico m³/kg',
    'Energía interna kJ/kg',
    'Entalpía kJ/kg',
    'Entropía kJ/kgK'
  ];

  final List<String> opcionesFases = [
    'Líquido Saturado',
    'Vapor Saturado',
    'Mezcla',
    'Líquido Comprimido'
  ];

  // Variables para el Modo "Interpolación"
  String propInterpolacion = 'Temperatura °C';
  final TextEditingController controlValorInterpolacion =
      TextEditingController();
  String convencionFG = 'f'; // 'f' = líquido saturado, 'g' = vapor saturado

  Map<String, dynamic>? _datosResultado;
  String? _faseResultado;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      await misTablas.cargarTodas();
      setState(() => isLoading = false);
    } catch (e) {
      debugPrint("Error cargando las tablas: $e");
    }
  }

  String _obtenerSimbolo(String texto) {
    if (texto.contains('Temperatura')) return 't';
    if (texto.contains('Presión')) return 'p';
    if (texto.contains('Volumen')) return 'v';
    if (texto.contains('Energía')) return 'u';
    if (texto.contains('Entalpía')) return 'h';
    if (texto.contains('Entropía')) return 's';
    if (texto.contains('Calidad')) return 'x';
    return '';
  }

  /// Color de fondo según la fase del último resultado calculado:
  /// azul pastel para líquido (comprimido/saturado), rojo pastel para
  /// vapor (saturado/sobrecalentado), un tono neutro para mezcla o para
  /// cuando todavía no hay resultado.
  Color _colorDeFondo() {
    if (_faseResultado == null) {
      return Colors.grey.shade100;
    }
    if (_faseResultado!.contains('Vapor')) {
      return const Color(0xFFFBE4E4);
    }
    if (_faseResultado!.contains('Líquido')) {
      return const Color(0xFFE3F0FB);
    }
    if (_faseResultado!.contains('Mezcla')) {
      return const Color(0xFFF3E9FB);
    }
    if (_faseResultado!.contains('Interpolación')) {
      return const Color(0xFFE6F7ED); // verde pastel, distinto de mezcla
    }
    return Colors.grey.shade100;
  }

  void _botonCalcularPresionado() {
    FocusScope.of(context).unfocus(); // Oculta el teclado
    _mostrarDesgloseCompleto = false; // Reinicia el desglose en cada cálculo.

    try {
      Map<String, dynamic>? res;

      // ==========================================================
      // LÓGICA MODO: INTERPOLACIÓN (fila completa en la campana mezcla)
      // ==========================================================
      if (_modo == 'interpolacion') {
        double? val = double.tryParse(controlValorInterpolacion.text);
        if (val == null) {
          throw Exception("Ingresa un número válido para la propiedad.");
        }
        String sim = _obtenerSimbolo(propInterpolacion);
        final datos = resolverInterpolacionMezcla(misTablas, sim, val,
            convencion: convencionFG);
        _faseResultado = 'Interpolación (Mezcla)';
        _datosResultado = datos;
      }
      // ==========================================================
      // LÓGICA MODO: ESTADO CONOCIDO
      // ==========================================================
      else if (_modo == 'estado') {
        double? val = double.tryParse(controlValorEstado.text);
        if (val == null) {
          throw Exception("Ingresa un número válido para la propiedad.");
        }
        String sim = _obtenerSimbolo(propEstado);

        if (estadoSeleccionado == 'Mezcla') {
          double? x = double.tryParse(controlCalidad.text);
          if (x == null || x < 0 || x > 1) {
            throw Exception(
                "Para mezcla, la calidad (x) debe ser un número entre 0 y 1.");
          }
          if (sim != 't' && sim != 'p') {
            throw Exception(
                "Para definir una Mezcla necesitas Temperatura o Presión.");
          }
          var calculo = resolverMezclaConCalidad(misTablas, sim, val, x);
          _faseResultado = 'Mezcla';
          _datosResultado = calculo;
        } else if (estadoSeleccionado == 'Líquido Saturado') {
          _datosResultado = resolverLiquidoSaturado(misTablas, sim, val);
          _faseResultado = 'Líquido Saturado';
        } else if (estadoSeleccionado == 'Vapor Saturado') {
          _datosResultado = resolverVaporSaturado(misTablas, sim, val);
          _faseResultado = 'Vapor Saturado';
        } else if (estadoSeleccionado == 'Líquido Comprimido') {
          if (sim != 't') {
            throw Exception(
                "Para Líquido Comprimido aproximado ingresa la Temperatura.");
          }
          _datosResultado =
              resolverLiquidoComprimidoAproximado(misTablas, val);
          _faseResultado = 'Líquido Comprimido';
        }
      }
      // ==========================================================
      // LÓGICA MODO: 2 PROPIEDADES
      // ==========================================================
      else if (_modo == '2prop') {
        if (seleccion1 == seleccion2) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.sentiment_dissatisfied, color: Colors.white),
                  SizedBox(width: 10),
                  Text('Jeje has ingresado la misma propiedad 2 veces',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              backgroundColor: Colors.orange.shade800,
              behavior: SnackBarBehavior.floating,
              margin: EdgeInsets.only(
                  bottom: MediaQuery.of(context).size.height - 180,
                  left: 20,
                  right: 20),
            ),
          );
          return;
        }

        double? val1 = double.tryParse(controlValor1.text);
        double? val2 = double.tryParse(controlValor2.text);
        if (val1 == null || val2 == null) {
          throw Exception("Ingresa números válidos en ambas cajas.");
        }

        String sim1 = _obtenerSimbolo(seleccion1);
        String sim2 = _obtenerSimbolo(seleccion2);
        Map<String, double> inputs = {sim1: val1, sim2: val2};

        if (inputs.containsKey('x')) {
          if (inputs.containsKey('t')) {
            var datos = resolverMezclaConCalidad(
                misTablas, 't', inputs['t']!, inputs['x']!);
            res = {'estado': 'Mezcla', 'datos': datos};
          } else if (inputs.containsKey('p')) {
            var datos = resolverMezclaConCalidad(
                misTablas, 'p', inputs['p']!, inputs['x']!);
            res = {'estado': 'Mezcla', 'datos': datos};
          } else {
            throw Exception(
                "Para usar la Calidad (x), la otra propiedad debe ser T o P.");
          }
        } else if (inputs.containsKey('t') && inputs.containsKey('p')) {
          res = resolverTemperaturaYPresion(
              misTablas, inputs['t']!, inputs['p']!);
        } else if (inputs.containsKey('t')) {
          String otraProp = inputs.keys.firstWhere((k) => k != 't');
          res = resolverPorTemperatura(
              misTablas, inputs['t']!, otraProp, inputs[otraProp]!);
        } else if (inputs.containsKey('p')) {
          String otraProp = inputs.keys.firstWhere((k) => k != 'p');
          res = resolverPorPresion(
              misTablas, inputs['p']!, otraProp, inputs[otraProp]!);
        } else if (inputs.containsKey('v') && inputs.containsKey('u')) {
          res = resolverVolumenEnergiaInterna(
              misTablas, inputs['v']!, inputs['u']!);
        } else if (inputs.containsKey('v') && inputs.containsKey('h')) {
          res = resolverVolumenEntalpia(
              misTablas, inputs['v']!, inputs['h']!);
        } else if (inputs.containsKey('v') && inputs.containsKey('s')) {
          res = resolverVolumenEntropia(
              misTablas, inputs['v']!, inputs['s']!);
        } else if (inputs.containsKey('u') && inputs.containsKey('h')) {
          res = resolverEnergiaInternaEntalpia(
              misTablas, inputs['u']!, inputs['h']!);
        } else if (inputs.containsKey('u') && inputs.containsKey('s')) {
          res = resolverEnergiaInternaEntropia(
              misTablas, inputs['u']!, inputs['s']!);
        } else if (inputs.containsKey('h') && inputs.containsKey('s')) {
          res = resolverEntalpiaEntropia(
              misTablas, inputs['h']!, inputs['s']!);
        } else {
          throw Exception("Combinación no soportada.");
        }

        _faseResultado = res['estado'];
        _datosResultado = res['datos'];
      }

      setState(() {});
    } catch (e) {
      setState(() {
        _faseResultado = null;
        _datosResultado = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll("Exception: ", ""))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      color: _colorDeFondo(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Tablas Termo'),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // --- SELECTOR DE MODO ---
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          FilterChip(
                            label: const Text("2 Propiedades"),
                            selected: _modo == '2prop',
                            onSelected: (v) => setState(() {
                              _modo = '2prop';
                              _datosResultado = null;
                              _faseResultado = null;
                            }),
                          ),
                          FilterChip(
                            label: const Text("Estado Conocido"),
                            selected: _modo == 'estado',
                            onSelected: (v) => setState(() {
                              _modo = 'estado';
                              _datosResultado = null;
                              _faseResultado = null;
                            }),
                          ),
                          FilterChip(
                            label: const Text("Interpolación"),
                            selected: _modo == 'interpolacion',
                            onSelected: (v) => setState(() {
                              _modo = 'interpolacion';
                              _datosResultado = null;
                              _faseResultado = null;
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // --- MODO 2 PROPIEDADES ---
                      if (_modo == '2prop') ...[
                        Row(
                          children: [
                            Expanded(
                                flex: 3,
                                child: _crearDropdown(
                                    seleccion1,
                                    opcionesPropiedades,
                                    (v) => setState(() => seleccion1 = v!))),
                            const SizedBox(width: 10),
                            Expanded(
                                flex: 2,
                                child: _crearCajaTexto(controlValor1, 'Valor')),
                          ],
                        ),
                        const SizedBox(height: 15),
                        Row(
                          children: [
                            Expanded(
                                flex: 3,
                                child: _crearDropdown(
                                    seleccion2,
                                    opcionesPropiedades,
                                    (v) => setState(() => seleccion2 = v!))),
                            const SizedBox(width: 10),
                            Expanded(
                                flex: 2,
                                child: _crearCajaTexto(controlValor2, 'Valor')),
                          ],
                        ),
                      ]
                      // --- MODO ESTADO CONOCIDO ---
                      else if (_modo == 'estado') ...[
                        _crearDropdown(estadoSeleccionado, opcionesFases,
                            (v) => setState(() => estadoSeleccionado = v!)),
                        const SizedBox(height: 15),
                        Row(
                          children: [
                            Expanded(
                                flex: 3,
                                child: _crearDropdown(
                                    propEstado,
                                    opcionesPropiedades,
                                    (v) => setState(() => propEstado = v!))),
                            const SizedBox(width: 10),
                            Expanded(
                                flex: 2,
                                child: _crearCajaTexto(
                                    controlValorEstado, 'Valor')),
                          ],
                        ),
                        if (estadoSeleccionado == 'Mezcla') ...[
                          const SizedBox(height: 15),
                          _crearCajaTexto(controlCalidad,
                              'Calidad (x) -> ingrese un valor entre 0 y 1'),
                        ]
                      ]
                      // --- MODO INTERPOLACIÓN ---
                      else ...[
                        Row(
                          children: [
                            Expanded(
                                flex: 3,
                                child: _crearDropdown(
                                    propInterpolacion,
                                    opcionesPropiedades,
                                    (v) => setState(
                                        () => propInterpolacion = v!))),
                            const SizedBox(width: 10),
                            Expanded(
                                flex: 2,
                                child: _crearCajaTexto(
                                    controlValorInterpolacion, 'Valor')),
                          ],
                        ),
                        // El selector f/g solo aplica si la propiedad NO es
                        // Temperatura ni Presión (esas no tienen variante f/g).
                        if (!propInterpolacion.contains('Temperatura') &&
                            !propInterpolacion.contains('Presión')) ...[
                          const SizedBox(height: 15),
                          Row(
                            children: [
                              const Text('Buscar por: '),
                              const SizedBox(width: 10),
                              ChoiceChip(
                                label: const Text('Líquido saturado (f)'),
                                selected: convencionFG == 'f',
                                onSelected: (v) =>
                                    setState(() => convencionFG = 'f'),
                              ),
                              const SizedBox(width: 10),
                              ChoiceChip(
                                label: const Text('Vapor saturado (g)'),
                                selected: convencionFG == 'g',
                                onSelected: (v) =>
                                    setState(() => convencionFG = 'g'),
                              ),
                            ],
                          ),
                        ],
                      ],
                      const SizedBox(height: 30),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.blue.shade800,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _botonCalcularPresionado,
                        child: const Text('CALCULAR ESTADO',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 30),
                      // --- TARJETA DE RESULTADOS ---
                      if (_datosResultado != null) _construirTarjetaResultados(),

                      // --- FOOTER: crédito + versión ---
                      const SizedBox(height: 40),
                      Center(
                        child: Column(
                          children: [
                            Text(
                              'Julian Mauricio Florez Gomez',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade400,
                              ),
                            ),
                            Text(
                              'florezgomezjulian@gmail.com',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade400,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'v1.0.0',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  // --- AYUDANTES DE INTERFAZ ---

  Widget _crearDropdown(String valorActual, List<String> opciones,
      void Function(String?) onChange) {
    return InputDecorator(
      decoration: const InputDecoration(
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 15),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: valorActual,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down),
          items: opciones
              .map((p) => DropdownMenuItem(
                  value: p, child: Text(p, overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: onChange,
        ),
      ),
    );
  }

  Widget _crearCajaTexto(TextEditingController controlador, String etiqueta) {
    return TextField(
      controller: controlador,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: etiqueta),
    );
  }

  // ==========================================================
  // TARJETA DE RESULTADOS
  // ==========================================================
  Widget _construirTarjetaResultados() {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Fase: $_faseResultado",
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green),
                  ),
                ),
              ],
            ),
            const Divider(height: 30, thickness: 2),
            _filaSimple("Temperatura (°C)", _datosResultado!['temperatura']),
            _filaSimple("Presión (kPa/MPa)", _datosResultado!['presion']),
            const Divider(),

            // Vista RESUMIDA (siempre visible): igual que en las demás fases.
            if (_faseResultado == 'Mezcla' && _datosResultado!.containsKey('x'))
              _filaDestacada("Calidad (x)", _datosResultado!['x']),
            _filaSimple("Volumen (v)", _datosResultado!['v']),
            _filaSimple("Energía Int. (u)", _datosResultado!['u']),
            _filaSimple("Entalpía (h)", _datosResultado!['h']),
            _filaSimple("Entropía (s)", _datosResultado!['s']),

            // Vista EXPANDIDA: siempre visible en Interpolación (ese es el
            // propósito de ese apartado); en Mezcla, solo si el usuario la pide.
            if (_faseResultado == 'Interpolación (Mezcla)' ||
                (_faseResultado == 'Mezcla' && _mostrarDesgloseCompleto)) ...[
              const SizedBox(height: 10),
              const Divider(),
              const Text(
                "Desglose de Mezcla (f, fg, g):",
                style:
                    TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
              ),
              const SizedBox(height: 10),
              _filaMezcla("Volumen (v)", "v"),
              _filaMezcla("Energía Int. (u)", "u"),
              _filaMezcla("Entalpía (h)", "h"),
              _filaMezcla("Entropía (s)", "s"),
            ],

            // El botón +/- solo tiene sentido en Mezcla (en Interpolación
            // el desglose ya está siempre visible, sin necesidad de botón).
            if (_faseResultado == 'Mezcla') ...[
              const SizedBox(height: 15),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _mostrarDesgloseCompleto = !_mostrarDesgloseCompleto;
                  });
                },
                icon: Icon(_mostrarDesgloseCompleto ? Icons.remove : Icons.add),
                label: Text(_mostrarDesgloseCompleto
                    ? 'Menos info sobre los datos'
                    : 'Más info sobre los datos'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _filaSimple(String nombre, double? valor) {
    if (valor == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              nombre,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            valor.toStringAsFixed(6),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _filaDestacada(String nombre, double valor) {
    return Container(
      color: Colors.blue.shade50,
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(nombre,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900)),
          Text(valor.toStringAsFixed(6),
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900)),
        ],
      ),
    );
  }

  // Creador de la fila detallada para la mezcla (vf, vfg, vg y v real)
  Widget _filaMezcla(String titulo, String prop) {
    double? f = _datosResultado!['${prop}f'];
    double? fg = _datosResultado!['${prop}fg'];
    double? g = _datosResultado!['${prop}g'];
    double? real =
        _datosResultado![prop] ?? _datosResultado!['${prop}_calculado'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        if (f != null && fg != null && g != null)
          Text(
              "${prop}f: ${f.toStringAsFixed(6)} | ${prop}fg: ${fg.toStringAsFixed(6)} | ${prop}g: ${g.toStringAsFixed(6)}",
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
        if (real != null)
          Text("$prop real = ${real.toStringAsFixed(6)}",
              style: TextStyle(
                  color: Colors.blue.shade800, fontWeight: FontWeight.bold)),
        const Divider(),
      ],
    );
  }
}