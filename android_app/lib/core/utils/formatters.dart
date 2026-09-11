import 'package:intl/intl.dart';

class Formatters {
  static final NumberFormat _speedFormat = NumberFormat('0.0');
  static final NumberFormat _headingFormat = NumberFormat('0.0');
  static final NumberFormat _driftFormat = NumberFormat('0.00');
  static final NumberFormat _sensorFormat = NumberFormat('+0.00;-0.00');
  static final NumberFormat _coordFormat = NumberFormat('0.000000');

  static String formatSpeed(double speedMs, {bool inKmh = true}) {
    final val = inKmh ? speedMs * 3.6 : speedMs;
    final unit = inKmh ? 'km/h' : 'm/s';
    return '${_speedFormat.format(val)} $unit';
  }

  static String formatHeading(double headingDeg) {
    return '${_headingFormat.format(headingDeg)}°';
  }

  static String formatDrift(double driftMeters) {
    return '${_driftFormat.format(driftMeters)} m';
  }

  static String formatSensorVal(double val) {
    return _sensorFormat.format(val);
  }

  static String formatCoordinate(double coord) {
    return _coordFormat.format(coord);
  }

  static String formatPercentage(double value) {
    return '${(value * 100).toStringAsFixed(1)}%';
  }
}
