# Tablas Termo

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

Aplicación móvil de código abierto para cálculos de termodinámica y tablas
de propiedades, desarrollada en Flutter/Dart.

Proyecto personal de un estudiante de Ingeniería Física de la Universidad
del Cauca (Colombia), orientado a estudiantes y profesionales que necesitan
herramientas termodinámicas accesibles desde el móvil.
Aplicación que contiene datos experimentales extraidos del libro de termodinámica de cengel, con 2 datos cualesquiera puede obtener las demas. Incluye: temperatura, presion, entalpia, volumne especifico, energia interna, entropia y estado.
incluye fnciones de interpolacion lineal y bilineal.
La aplicacion esta cargada con datos de saturación y de vapor sobrecalentado, se exceptuó los de liquido comprimido ya que se puede aproximar a los de liquido saturado

## Características

- [ ] Cálculo de propiedades termodinámicas
- [ ] Tablas de vapor y otras sustancias
- [ ] Resolución de ciclos termodinámicos
- [ ] Funciona sin conexión a internet
- [ ] Interfaz en español

> Reemplaza esta lista con lo que **realmente** hace tu app.

## Instalación

### Para usuarios

Descarga el APK desde la sección [Releases](https://github.com/julianmflorez-sketch/Tablas-Termo/releases).

### Para desarrolladores

```bash
git clone https://github.com/julianmflorez-sketch/Tablas-Termo.git
cd Tablas-Termo
flutter pub get
flutter run
